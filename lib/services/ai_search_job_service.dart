import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_cross_check.dart';
import 'ai_search_job.dart';
import 'blob_store.dart';

/// Service global de jobs de recherche IA (Gemini + Groq + Mistral).
/// Queue à 1 worker — les jobs s'exécutent un par un en arrière-plan.
/// Persiste les jobs dans SharedPreferences et les photos dans IndexedDB
/// (web uniquement).
class AiSearchJobService {
  static const _prefsKey = 'ai_search_jobs_v1';

  static final ValueNotifier<List<AiSearchJob>> jobs =
      ValueNotifier<List<AiSearchJob>>(<AiSearchJob>[]);

  /// Notifié à chaque job qui termine — utilisé pour afficher snackbars
  /// globales depuis l'app.
  static final ValueNotifier<AiSearchJob?> lastFinished =
      ValueNotifier<AiSearchJob?>(null);

  /// Nombre de jobs terminés en succès (pour badge sur Settings).
  static final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);

  static bool _workerRunning = false;
  static int _idCounter = 0;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          final loaded = <AiSearchJob>[];
          for (final item in list) {
            if (item is! Map) continue;
            final job =
                AiSearchJob.fromJson(item.cast<String, dynamic>());
            // Restaurer la photo depuis IndexedDB
            if (job.photoBlobKey != null) {
              final bytes = await BlobStore.get(job.photoBlobKey!);
              if (bytes != null) job.photoBytes = bytes;
            }
            // Si un job était "running" au moment du refresh,
            // on le remet en queued pour qu'il soit relancé.
            if (job.status == AiSearchJobStatus.running) {
              job.status = AiSearchJobStatus.queued;
            }
            loaded.add(job);
          }
          jobs.value = loaded;
        }
      } catch (e) {
        debugPrint('AiSearchJobService.init: failed to load jobs: $e');
      }
    }
    _refreshPendingCount();
    _ensureWorker();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = jobs.value.map((j) => j.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('AiSearchJobService._persist failed: $e');
    }
  }

  static String _newId() {
    _idCounter++;
    return 'job_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  static Future<AiSearchJob> enqueuePhoto({
    required Uint8List photoBytes,
    String? photoFileName,
    String? searchName,
    String? searchDomaine,
    String? searchVintage,
    WineDraftData? draftData,
  }) async {
    final id = _newId();
    final blobKey = 'photo_$id';
    final stored = await BlobStore.put(blobKey, photoBytes);
    final job = AiSearchJob(
      id: id,
      createdAt: DateTime.now(),
      type: AiSearchJobType.photo,
      photoBytes: photoBytes,
      photoBlobKey: stored ? blobKey : null,
      photoFileName: photoFileName,
      searchName: searchName,
      searchDomaine: searchDomaine,
      searchVintage: searchVintage,
      draftData: draftData,
    );
    _addJob(job);
    await _persist();
    return job;
  }

  static Future<AiSearchJob> enqueueText({
    required String name,
    String? domaine,
    String? vintage,
    WineDraftData? draftData,
  }) async {
    final job = AiSearchJob(
      id: _newId(),
      createdAt: DateTime.now(),
      type: AiSearchJobType.text,
      searchName: name,
      searchDomaine: domaine,
      searchVintage: vintage,
      draftData: draftData,
    );
    _addJob(job);
    await _persist();
    return job;
  }

  static void _addJob(AiSearchJob job) {
    final list = List<AiSearchJob>.from(jobs.value);
    list.insert(0, job);
    jobs.value = list;
    _refreshPendingCount();
    _ensureWorker();
  }

  static void _notifyChange() {
    jobs.value = List<AiSearchJob>.from(jobs.value);
    _refreshPendingCount();
    _persist();
  }

  static void retry(String jobId) {
    final job = _findById(jobId);
    if (job == null) return;
    if (job.status == AiSearchJobStatus.running) return;
    job.status = AiSearchJobStatus.queued;
    job.errorMessage = null;
    job.retryCount = 0; // Reset du compteur sur retry manuel
    _notifyChange();
    _ensureWorker();
  }

  static Future<void> remove(String jobId) async {
    final job = _findById(jobId);
    if (job == null) return;
    if (job.photoBlobKey != null) {
      await BlobStore.delete(job.photoBlobKey!);
    }
    final list = List<AiSearchJob>.from(jobs.value);
    list.removeWhere((j) => j.id == jobId);
    jobs.value = list;
    _refreshPendingCount();
    await _persist();
  }

  static void clearAllFinished() {
    final list = jobs.value
        .where((j) =>
            j.status == AiSearchJobStatus.queued ||
            j.status == AiSearchJobStatus.running)
        .toList();
    jobs.value = list;
    _refreshPendingCount();
    _persist();
  }

  static AiSearchJob? _findById(String id) {
    for (final j in jobs.value) {
      if (j.id == id) return j;
    }
    return null;
  }

  static void _refreshPendingCount() {
    var c = 0;
    for (final j in jobs.value) {
      if (j.status == AiSearchJobStatus.success ||
          j.status == AiSearchJobStatus.failed) {
        c++;
      }
    }
    pendingCount.value = c;
  }

  static void _ensureWorker() {
    if (_workerRunning) return;
    _workerRunning = true;
    Future(() async {
      try {
        while (true) {
          AiSearchJob? next;
          for (final j in jobs.value) {
            if (j.status == AiSearchJobStatus.queued) {
              next = j;
              break;
            }
          }
          if (next == null) break;
          await _runJob(next);
        }
      } finally {
        _workerRunning = false;
      }
    });
  }

  /// Nombre maximal de tentatives auto avant de marquer le job en échec.
  static const _maxRetries = 10;

  static Future<void> _runJob(AiSearchJob job) async {
    job.status = AiSearchJobStatus.running;
    _notifyChange();
    try {
      CrossCheckResult result;
      if (job.type == AiSearchJobType.photo) {
        if (job.photoBytes == null) {
          throw Exception('Photo perdue.');
        }
        result = await AiCrossCheck.searchByPhoto(job.photoBytes!);
      } else {
        if (job.searchName == null || job.searchName!.trim().isEmpty) {
          throw Exception('Nom du vin manquant.');
        }
        result = await AiCrossCheck.searchByText(
          name: job.searchName!.trim(),
          domaine: job.searchDomaine,
          vintage: job.searchVintage,
        );
      }
      job.result = result;
      job.status = AiSearchJobStatus.success;
      job.completedAt = DateTime.now();
      _notifyChange();
      lastFinished.value = job;
    } catch (e) {
      job.errorMessage = e.toString().replaceFirst('Exception: ', '');
      job.retryCount++;
      if (job.retryCount < _maxRetries) {
        // Backoff exponentiel borné : 2^n secondes, max 60 sec.
        // 1→2s, 2→4s, 3→8s, 4→16s, 5→32s, 6+→60s
        final delaySec = (1 << job.retryCount).clamp(2, 60);
        job.status = AiSearchJobStatus.queued;
        _notifyChange();
        await Future.delayed(Duration(seconds: delaySec));
      } else {
        // Vraiment terminé en échec après 10 tentatives.
        job.status = AiSearchJobStatus.failed;
        job.completedAt = DateTime.now();
        _notifyChange();
        lastFinished.value = job;
      }
    }
  }
}
