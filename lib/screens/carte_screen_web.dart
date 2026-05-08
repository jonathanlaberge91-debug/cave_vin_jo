import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import '../services/maps_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/cascade_filter.dart';
import 'wine_detail_screen.dart';

class _WineFormatEntry {
  final Wine wine;
  final String formatLabel;
  final int count;

  _WineFormatEntry({
    required this.wine,
    required this.formatLabel,
    required this.count,
  });
}

class _DomainPin {
  final GeoCoord coord;
  final String address;
  final String domaine;
  final List<_WineFormatEntry> entries;
  final int totalBottles;

  _DomainPin({
    required this.coord,
    required this.address,
    required this.domaine,
    required this.entries,
    required this.totalBottles,
  });
}

enum _MissingReason {
  noAddress, // Le vin n'a pas de domainAddress.
  geocodeFailed, // L'adresse n'a pas pu être géolocalisée.
}

class _MissingWineEntry {
  final Wine wine;
  final List<_WineFormatEntry> formatEntries;
  final int totalBottles;
  final _MissingReason reason;

  _MissingWineEntry({
    required this.wine,
    required this.formatEntries,
    required this.totalBottles,
    required this.reason,
  });
}

class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});
  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  static const _viewType = 'cave-google-map';
  static int _viewCounter = 0;
  static bool _viewRegistered = false;

  bool _loading = true;
  bool _apiKeyMissing = false;
  String? _error;
  String _loadingStatus = 'Chargement des vins…';
  List<_DomainPin> _pins = [];
  List<_DomainPin> _allPins = [];
  List<_MissingWineEntry> _missing = [];
  CascadeFilterState _cascadeFilter = const CascadeFilterState();
  List<CascadeFilterData> _filterData = [];
  Map<String, Wine> _winesById = {};
  late final String _mapDivId;

  @override
  void initState() {
    super.initState();
    _mapDivId = 'cave-map-${_viewCounter++}';
    _registerView();
    _init();
  }

  void _registerView() {
    if (_viewRegistered) return;
    final divId = _mapDivId;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = divId;
        div.style.setProperty('width', '100%');
        div.style.setProperty('height', '100%');
        div.style.setProperty('min-height', '400px');
        div.style.setProperty('background-color', '#1a1510');
        return div;
      },
    );
    _viewRegistered = true;
  }

  void _registerWineCallback() {
    globalContext['_caveOpenWine'] = ((JSAny? wineId, [JSAny? format]) {
      if (wineId == null) return;
      final id = (wineId as JSString).toDart;
      final fmt = format != null ? (format as JSString).toDart : null;
      _openWineDetail(id, fmt);
    }).toJS;
  }

  void _disableMapInteraction() {
    _evalJs('''
(function(){
  if(window._caveMap){
    window._caveMap.setOptions({scrollwheel:false,gestureHandling:'none'});
  }
})();
''');
  }

  void _enableMapInteraction() {
    _evalJs('''
(function(){
  if(window._caveMap){
    window._caveMap.setOptions({scrollwheel:true,gestureHandling:'auto'});
  }
})();
''');
  }

  void _openWineDetail(String wineId, [String? formatLabel]) async {
    final wine = _winesById[wineId];
    if (wine == null || !mounted) return;
    var bottles = await CaveService.bottlesByWine(wineId).first;
    if (formatLabel != null) {
      bottles = bottles.where((b) => b.format.label == formatLabel).toList();
    }
    if (bottles.isEmpty || !mounted) return;
    _disableMapInteraction();
    await showWineDetail(context, wine: wine, bottles: bottles);
    if (mounted) _enableMapInteraction();
  }

  Future<void> _init() async {
    try {
      final apiKey = MapsService.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        setState(() { _apiKeyMissing = true; _loading = false; });
        return;
      }

      // Start loading Maps API immediately — runs in parallel with data fetching
      final mapsApiReady = _ensureMapsApiLoaded(apiKey);

      setState(() => _loadingStatus = 'Chargement des vins…');
      final wines = await CaveService.wines().first;
      final bottles = await CaveService.bottlesInCave().first;

      _winesById = {for (final w in wines) w.id: w};

      // Construit les format entries pour un vin (utilisé pour map + missing).
      List<_WineFormatEntry> buildFormatEntries(Wine w) {
        final wBottles = bottles.where((b) => b.wineId == w.id).toList();
        if (wBottles.isEmpty) return const [];
        final byFormat = <String, int>{};
        for (final b in wBottles) {
          byFormat[b.format.label] = (byFormat[b.format.label] ?? 0) + 1;
        }
        return byFormat.entries
            .map((fe) =>
                _WineFormatEntry(wine: w, formatLabel: fe.key, count: fe.value))
            .toList();
      }

      // Vins sans adresse → "missing" avec raison noAddress.
      final missing = <_MissingWineEntry>[];
      final addressGroups = <String, List<Wine>>{};
      for (final w in wines) {
        if (w.domainAddress.trim().isEmpty) {
          final fEntries = buildFormatEntries(w);
          if (fEntries.isNotEmpty) {
            missing.add(_MissingWineEntry(
              wine: w,
              formatEntries: fEntries,
              totalBottles: fEntries.fold<int>(0, (s, e) => s + e.count),
              reason: _MissingReason.noAddress,
            ));
          }
          continue;
        }
        addressGroups.putIfAbsent(w.domainAddress, () => []).add(w);
      }

      if (addressGroups.isEmpty) {
        _missing = missing;
        setState(() {
          _loading = false;
          _error = missing.isEmpty
              ? 'Aucun vin avec une adresse de domaine dans ta cave.'
              : 'Aucun de tes vins n\'a d\'adresse de domaine. Édite leurs fiches pour les voir sur la carte.';
        });
        return;
      }

      // Geocode all addresses in parallel
      final total = addressGroups.length;
      var completed = 0;
      if (mounted) setState(() => _loadingStatus = 'Géolocalisation $total domaine${total > 1 ? "s" : ""}…');

      final pinFutures = addressGroups.entries.map((entry) async {
        final coord = await MapsService.geocode(entry.key);
        completed++;
        if (mounted) setState(() => _loadingStatus = 'Géolocalisation $completed/$total…');

        final formatEntries = <_WineFormatEntry>[];
        int tot = 0;
        for (final w in entry.value) {
          final wEntries = buildFormatEntries(w);
          formatEntries.addAll(wEntries);
          for (final fe in wEntries) {
            tot += fe.count;
          }
        }
        if (formatEntries.isEmpty) return null;

        if (coord == null) {
          // Géocodage échoué : ces vins iront dans la liste "missing".
          for (final w in entry.value) {
            final wEntries = buildFormatEntries(w);
            if (wEntries.isEmpty) continue;
            missing.add(_MissingWineEntry(
              wine: w,
              formatEntries: wEntries,
              totalBottles: wEntries.fold<int>(0, (s, e) => s + e.count),
              reason: _MissingReason.geocodeFailed,
            ));
          }
          return null;
        }

        final firstWine = formatEntries.first.wine;
        return _DomainPin(
          coord: coord,
          address: entry.key,
          domaine: firstWine.domaine.isNotEmpty ? firstWine.domaine : firstWine.name,
          entries: formatEntries,
          totalBottles: tot,
        );
      }).toList();

      final results = await Future.wait(pinFutures);
      final pins = results.whereType<_DomainPin>().toList();

      _missing = missing;

      if (pins.isEmpty) {
        setState(() {
          _loading = false;
          _error = missing.isEmpty
              ? 'Aucune adresse n\'a pu être géolocalisée.\nVérifie ta clé API Google Maps et les adresses des domaines.'
              : 'Aucun pin à afficher. ${missing.length} vin${missing.length > 1 ? 's' : ''} sans adresse géolocalisable. Clique sur le bouton ci-dessous pour les voir.';
        });
        return;
      }

      _allPins = pins;
      _pins = pins;
      _filterData = _buildFilterData(pins);

      if (mounted) setState(() => _loadingStatus = 'Chargement de Google Maps…');
      await mapsApiReady;

      _registerWineCallback();

      if (!mounted) return;
      setState(() => _loading = false);

      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _initializeMap();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur : $e'; });
    }
  }

  Future<void> _ensureMapsApiLoaded(String apiKey) async {
    if (_hasMapsApi()) return;

    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey';
    web.document.head!.append(script);

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      if (_hasMapsApi()) return;
    }

    throw Exception(
        'Google Maps n\'a pas pu charger (15s). Vérifie ta clé API.');
  }

  bool _hasMapsApi() {
    try {
      if (!globalContext.has('google')) return false;
      final google = globalContext['google'];
      if (google == null) return false;
      return (google as JSObject).has('maps');
    } catch (_) {
      return false;
    }
  }

  static const _typeColors = {
    'rouge': '#B23A48',
    'blanc': '#E6D27A',
    'rose': '#E89DA6',
    'orange': '#E08A3C',
    'petillant': '#B8C9D9',
  };

  static const _typeLabels = {
    'rouge': 'ROUGE',
    'blanc': 'BLANC',
    'rose': 'ROSÉ',
    'orange': 'ORANGE',
    'petillant': 'PÉTILLANT',
  };

  List<CascadeFilterData> _buildFilterData(List<_DomainPin> pins) {
    final seen = <String>{};
    final result = <CascadeFilterData>[];
    for (final pin in pins) {
      for (final entry in pin.entries) {
        final w = entry.wine;
        if (w.country.isEmpty && w.region.isEmpty) continue;
        final key = '${w.country}|${w.region}|${w.appellation}|${w.climat}';
        if (seen.add(key)) {
          result.add(CascadeFilterData(
            country: w.country,
            region: w.region,
            appellation: w.appellation,
            climat: w.climat,
          ));
        }
      }
    }
    return result;
  }

  List<_DomainPin> get _filteredPins {
    if (_cascadeFilter.isEmpty) return _allPins;
    return _allPins.where((pin) {
      return pin.entries.any((e) {
        final w = e.wine;
        return _cascadeFilter.matchesWine(
          country: w.country,
          region: w.region,
          appellation: w.appellation,
          climat: w.climat,
        );
      });
    }).toList();
  }

  void _onFilterChanged(CascadeFilterState f) {
    setState(() {
      _cascadeFilter = f;
      _pins = _filteredPins;
    });
    _initializeMap();
  }

  void _initializeMap() {
    final markersJson = _pins.map((p) {
      final wineItems = p.entries.map((e) {
        final w = e.wine;
        final vintage = w.vintage != null ? ' ${w.vintage}' : '';
        final tc = _typeColors[w.type.name] ?? '#C9A84C';
        final tl = _typeLabels[w.type.name] ?? '';
        return {
          'id': w.id,
          'name': _esc(w.name),
          'vintage': vintage,
          'typeColor': tc,
          'typeLabel': tl,
          'format': _esc(e.formatLabel),
          'count': e.count,
        };
      }).toList();

      return {
        'lat': p.coord.lat,
        'lng': p.coord.lng,
        'domaine': _esc(p.domaine),
        'address': _esc(p.address),
        'totalBottles': p.totalBottles,
        'wines': wineItems,
      };
    }).toList();

    final json = jsonEncode(markersJson).replaceAll('</', '<\\/');

    final mapStyle = jsonEncode([
      {"elementType": "geometry", "stylers": [{"color": "#1a1510"}]},
      {"elementType": "labels.text.fill", "stylers": [{"color": "#8a7a5a"}]},
      {"elementType": "labels.text.stroke", "stylers": [{"color": "#0E0C0A"}]},
      {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#3a3020"}]},
      {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
      {"featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#1a1510"}]},
      {"featureType": "poi", "stylers": [{"visibility": "off"}]},
      {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2a2418"}]},
      {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1a1408"}]},
      {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#6a5a3a"}]},
      {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#352e1e"}]},
      {"featureType": "transit", "stylers": [{"visibility": "off"}]},
      {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0d0a06"}]},
      {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3a3020"}]},
    ]);

    _evalJs('''
(function initCaveMap(attempt) {
  var el = document.getElementById('$_mapDivId');
  if (!el) {
    var all = document.querySelectorAll('div[id^="cave-map"]');
    if (all.length > 0) el = all[all.length - 1];
  }
  if (!el) {
    var pvs = document.querySelectorAll('flt-platform-view div[id^="cave-map"]');
    if (pvs.length > 0) el = pvs[pvs.length - 1];
  }
  if (!el) {
    if (attempt < 25) { setTimeout(function(){ initCaveMap(attempt+1); }, 300); }
    return;
  }
  if (typeof google === 'undefined' || !google.maps) return;

  if (el.offsetHeight < 100) el.style.minHeight = '500px';

  var data = $json;
  var center = data.length === 1
    ? {lat: data[0].lat, lng: data[0].lng}
    : {lat: 46.6, lng: 2.3};

  var map = new google.maps.Map(el, {
    zoom: data.length === 1 ? 12 : 4,
    center: center,
    styles: $mapStyle,
    disableDefaultUI: false,
    zoomControl: true,
    mapTypeControl: false,
    streetViewControl: false,
    fullscreenControl: true,
    backgroundColor: '#1a1510',
  });
  window._caveMap = map;

  // Gold pin SVG
  var pinSvg = 'data:image/svg+xml,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="44" viewBox="0 0 32 44">' +
    '<defs><filter id="s" x="-20%" y="-10%" width="140%" height="130%">' +
    '<feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity="0.4"/>' +
    '</filter></defs>' +
    '<path d="M16 0C7.2 0 0 7.2 0 16c0 11.2 16 28 16 28s16-16.8 16-28C32 7.2 24.8 0 16 0z" fill="#C9A84C" stroke="#E8C97A" stroke-width="1" filter="url(%23s)"/>' +
    '<circle cx="16" cy="16" r="7" fill="#1a1510"/>' +
    '<text x="16" y="20" text-anchor="middle" font-family="sans-serif" font-size="10" font-weight="700" fill="#E8C97A">' +
    '&#127863;</text>' +
    '</svg>'
  );

  var pinIcon = {
    url: pinSvg,
    scaledSize: new google.maps.Size(32, 44),
    anchor: new google.maps.Point(16, 44),
  };

  var bounds = new google.maps.LatLngBounds();
  var openIW = null;
  var closeTimer = null;
  var pinnedIW = null;

  function buildBubble(m) {
    var html = '<div style="font-family:-apple-system,BlinkMacSystemFont,\\'Segoe UI\\',sans-serif;' +
      'background:#1a1510;color:#E8E0D0;border-radius:12px;padding:16px 18px;min-width:220px;max-width:300px;' +
      'box-shadow:0 8px 32px rgba(0,0,0,0.6);border:1px solid #3a3020">' +

      '<div style="font-size:16px;font-weight:700;color:#C9A84C;margin-bottom:2px">' + m.domaine + '</div>' +
      '<div style="font-size:10px;color:#8a7a5a;margin-bottom:10px;letter-spacing:0.3px">' + m.address + '</div>' +

      '<div style="border-top:1px solid #2a2418;padding-top:8px">';

    m.wines.forEach(function(w) {
      html += '<div onclick="window._caveOpenWine(\\'' + w.id + '\\',\\'' + w.format + '\\')" ' +
        'style="display:flex;align-items:center;gap:8px;padding:6px 8px;margin:2px -8px;border-radius:8px;cursor:pointer;transition:background 0.15s" ' +
        'onmouseover="this.style.background=\\'#2a2418\\'" onmouseout="this.style.background=\\'transparent\\'">' +

        '<span style="display:inline-block;padding:2px 6px;border-radius:3px;font-size:8px;font-weight:700;letter-spacing:0.5px;' +
        'color:' + w.typeColor + ';background:' + w.typeColor + '22;border:1px solid ' + w.typeColor + '44">' + w.typeLabel + '</span>' +

        '<span style="flex:1;font-size:13px;font-weight:500;color:#E8E0D0">' + w.name + w.vintage + '</span>' +

        '<span style="font-size:10px;color:#8a7a5a;white-space:nowrap">' + w.count + '× ' + w.format + '</span>' +

        '</div>';
    });

    html += '</div>' +

      '<div style="border-top:1px solid #2a2418;margin-top:8px;padding-top:8px;display:flex;align-items:center;gap:6px">' +
      '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#C9A84C" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>' +
      '<span style="font-size:11px;color:#C9A84C;font-weight:600">' + m.totalBottles + ' bouteille' + (m.totalBottles > 1 ? 's' : '') + ' en cave</span>' +
      '</div>' +

      '</div>';

    return html;
  }

  // Style the InfoWindow to remove default chrome
  var iwStyle = document.createElement('style');
  iwStyle.textContent = '.gm-style-iw-c{padding:0!important;background:transparent!important;border-radius:12px!important;box-shadow:none!important;overflow:visible!important}' +
    '.gm-style-iw-d{overflow:visible!important;max-height:none!important}' +
    '.gm-style-iw-tc{display:none!important}' +
    '.gm-ui-hover-effect{top:4px!important;right:4px!important;width:24px!important;height:24px!important;background:#2a2418!important;border-radius:50%!important;border:1px solid #3a3020!important}' +
    '.gm-ui-hover-effect>span{background-color:#C9A84C!important;width:12px!important;height:12px!important;margin:5px!important}' +
    '.gm-style-iw-chr{position:absolute;top:8px;right:8px;z-index:1}';
  document.head.appendChild(iwStyle);

  data.forEach(function(m) {
    var pos = new google.maps.LatLng(m.lat, m.lng);
    var mk = new google.maps.Marker({
      position: pos,
      map: map,
      title: m.domaine,
      icon: pinIcon,
      optimized: false,
    });

    var iw = new google.maps.InfoWindow({
      content: buildBubble(m),
      disableAutoPan: false,
      maxWidth: 320,
    });

    mk.addListener('mouseover', function() {
      if (pinnedIW && pinnedIW !== iw) return;
      if (openIW && openIW !== iw) openIW.close();
      iw.open(map, mk);
      openIW = iw;
    });

    mk.addListener('mouseout', function() {
      // Fermeture instantanée au mouseout, sauf si épinglée par un clic.
      if (pinnedIW === iw) return;
      iw.close();
      if (openIW === iw) openIW = null;
    });

    mk.addListener('click', function() {
      if (closeTimer) { clearTimeout(closeTimer); closeTimer = null; }
      if (pinnedIW === iw) {
        pinnedIW = null;
        iw.close();
        openIW = null;
        return;
      }
      if (pinnedIW) { pinnedIW.close(); }
      if (openIW && openIW !== iw) openIW.close();
      iw.open(map, mk);
      openIW = iw;
      pinnedIW = iw;
    });

    google.maps.event.addListener(iw, 'closeclick', function() {
      if (pinnedIW === iw) pinnedIW = null;
      openIW = null;
    });

    bounds.extend(pos);
  });

  if (data.length > 1) {
    map.fitBounds(bounds, 60);
  }
})(1);
''');
  }

  String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  void _evalJs(String code) {
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = code;
    web.document.body!.append(script);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              _loadingStatus,
              style: AppText.sans(color: AppColors.text2, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_apiKeyMissing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_outlined,
                size: 48, color: AppColors.text3),
            const SizedBox(height: 14),
            Text(
              'Clé API Google Maps requise',
              style: AppText.serif(color: AppColors.text2, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure ta clé dans Paramètres → Clés API',
              style: AppText.sans(color: AppColors.text3, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'APIs requises : Maps JavaScript API + Geocoding API',
              style: AppText.sans(color: AppColors.text3, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined,
                  size: 48, color: AppColors.text3),
              const SizedBox(height: 14),
              Text(
                'Carte des domaines',
                style: AppText.serif(color: AppColors.text2, fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppText.sans(color: AppColors.text3, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (_missing.isNotEmpty) ...[
                const SizedBox(height: 18),
                _missingButton(),
              ],
            ],
          ),
        ),
      );
    }

    final filtered = _filteredPins;
    final totalWines = filtered.fold<int>(0, (s, p) => s + p.entries.length);
    final totalBottles = filtered.fold<int>(0, (s, p) => s + p.totalBottles);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_filterData.any((e) => e.country.isNotEmpty))
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bg2,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: CascadeFilterBar(
              filter: _cascadeFilter,
              allItems: _filterData,
              onChanged: _onFilterChanged,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg2.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  '${filtered.length} domaine${filtered.length > 1 ? 's' : ''}',
                  style: AppText.sans(
                    color: AppColors.gold2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _sep(),
                Text(
                  '$totalWines vin${totalWines > 1 ? 's' : ''}',
                  style:
                      AppText.sans(color: AppColors.text2, fontSize: 12),
                ),
                _sep(),
                Text(
                  '$totalBottles bouteille${totalBottles > 1 ? 's' : ''}',
                  style:
                      AppText.sans(color: AppColors.text3, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (_missing.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: _missingButton(),
          ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _missingButton() {
    final count = _missing.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMissingDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF3A2A18).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE07060)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined,
                  size: 16, color: Color(0xFFE07060)),
              const SizedBox(width: 8),
              Text(
                '$count vin${count > 1 ? 's' : ''} absent${count > 1 ? 's' : ''}',
                style: AppText.sans(
                  color: const Color(0xFFE8C97A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMissingDialog() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => _MissingWinesDialog(
        missing: _missing,
        onTapWine: (id) {
          Navigator.of(context).pop();
          _openWineDetail(id);
        },
      ),
    );
  }

  Widget _sep() => Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.border,
      );
}

class _MissingWinesDialog extends StatelessWidget {
  final List<_MissingWineEntry> missing;
  final ValueChanged<String> onTapWine;

  const _MissingWinesDialog({
    required this.missing,
    required this.onTapWine,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 720 ? 660.0 : size.width - 32;
    final maxHeight = size.height * 0.88;

    final byReason = <_MissingReason, List<_MissingWineEntry>>{};
    for (final m in missing) {
      byReason.putIfAbsent(m.reason, () => []).add(m);
    }
    final noAddress = byReason[_MissingReason.noAddress] ?? const [];
    final geocodeFailed = byReason[_MissingReason.geocodeFailed] ?? const [];
    final totalBottles =
        missing.fold<int>(0, (s, m) => s + m.totalBottles);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: Color(0xFFE07060), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vins absents de la carte',
                            style: AppText.serif(
                              color: AppColors.gold2,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${missing.length} vin${missing.length > 1 ? 's' : ''} · '
                            '$totalBottles bouteille${totalBottles > 1 ? 's' : ''}',
                            style: AppText.sans(
                                color: AppColors.text3, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppColors.text3),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (noAddress.isNotEmpty) ...[
                      _sectionTitle('Sans adresse de domaine',
                          'Édite la fiche du vin pour ajouter une adresse.'),
                      for (final m in noAddress) _row(m),
                    ],
                    if (geocodeFailed.isNotEmpty) ...[
                      _sectionTitle('Adresse non géolocalisée',
                          'Google Maps n\'a pas trouvé l\'adresse. Vérifie l\'orthographe.'),
                      for (final m in geocodeFailed) _row(m),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppText.sans(color: AppColors.text3, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _row(_MissingWineEntry m) {
    final w = m.wine;
    final qty = m.totalBottles;
    final formats = m.formatEntries
        .map((e) => '${e.count}× ${e.formatLabel}')
        .join(' · ');
    final originParts = <String>[
      if (w.appellation.isNotEmpty) w.appellation,
      if (w.region.isNotEmpty) w.region,
      if (w.country.isNotEmpty) w.country,
    ];
    final origin = originParts.join(' · ');
    final addressLine = m.reason == _MissingReason.geocodeFailed
        ? 'Adresse : ${w.domainAddress}'
        : null;

    return InkWell(
      onTap: () => onTapWine(w.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wine_bar_outlined,
                size: 18, color: AppColors.gold2),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.vintage != null ? '${w.name} ${w.vintage}' : w.name,
                    style: AppText.serif(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (origin.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        origin,
                        style: AppText.sans(
                            color: AppColors.text3, fontSize: 11),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      formats,
                      style: AppText.sans(
                          color: AppColors.text2, fontSize: 11),
                    ),
                  ),
                  if (addressLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        addressLine,
                        style: AppText.sans(
                          color: const Color(0xFFE07060),
                          fontSize: 10,
                        ).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$qty bout.',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.text3),
          ],
        ),
      ),
    );
  }
}
