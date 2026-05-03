import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import 'wine_detail_screen.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _mealController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  PairingResult? _result;
  String? _error;
  String _lastMeal = '';

  @override
  void dispose() {
    _mealController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _search(List<Wine> wines) async {
    final meal = _mealController.text.trim();
    if (meal.isEmpty || wines.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _lastMeal = meal;
    });

    try {
      final result = await GeminiService.suggestPairings(
        meal: meal,
        wines: wines,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _newSearch() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Wine>>(
      stream: CaveService.wines(),
      builder: (context, wineSnap) {
        final allWines = wineSnap.data ?? [];

        return StreamBuilder<List<Bottle>>(
          stream: CaveService.bottlesInCave(),
          builder: (context, bottleSnap) {
            final bottles = bottleSnap.data ?? [];
            final wineIdsInCave = bottles.map((b) => b.wineId).toSet();
            final wines =
                allWines.where((w) => wineIdsInCave.contains(w.id)).toList();
            final winesById = {for (final w in wines) w.id: w};

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _loading
                  ? _buildLoading()
                  : _result != null
                      ? _buildResults(winesById, bottles)
                      : _buildInput(wines),
            );
          },
        );
      },
    );
  }

  Widget _buildInput(List<Wine> wines) {
    final hasWines = wines.isNotEmpty;
    final geminiReady = GeminiService.isConfigured;

    return Center(
      key: const ValueKey('input'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const Icon(Icons.restaurant_outlined, size: 48, color: AppColors.text3),
              const SizedBox(height: 16),
              Text(
                'Accords Mets & Vins',
                style: AppText.serif(
                  color: AppColors.gold2,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Décrivez votre repas et notre sommelier IA\ntrouvera les bouteilles parfaites dans votre cave.',
                textAlign: TextAlign.center,
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border2),
                ),
                child: TextField(
                  controller: _mealController,
                  maxLines: 4,
                  minLines: 3,
                  enabled: hasWines && geminiReady,
                  style: AppText.sans(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Décrivez votre repas, les plats, les accompagnements…',
                    hintStyle:
                        AppText.sans(color: AppColors.text3, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      hasWines && geminiReady ? () => _search(wines) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1408),
                    disabledBackgroundColor: AppColors.bg3,
                    disabledForegroundColor: AppColors.text3,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Trouver les accords',
                    style: AppText.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (!geminiReady) ...[
                const SizedBox(height: 16),
                Text(
                  'Configure ta clé API Gemini dans les paramètres.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(color: AppColors.text3, fontSize: 12),
                ),
              ] else if (!hasWines) ...[
                const SizedBox(height: 16),
                Text(
                  'Ajoute des vins à ta cave pour commencer.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(color: AppColors.text3, fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x20B23A48),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x40B23A48)),
                  ),
                  child: Text(
                    _error!,
                    style: AppText.sans(
                        color: const Color(0xFFB23A48), fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Notre sommelier analyse\nvotre repas…',
            textAlign: TextAlign.center,
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 20,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recherche des meilleurs accords dans votre cave',
            style: AppText.sans(color: AppColors.text3, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
      Map<String, Wine> winesById, List<Bottle> bottles) {
    final result = _result!;
    final validSuggestions = result.suggestions
        .where((s) => winesById.containsKey(s.wineId))
        .toList();

    return SingleChildScrollView(
      key: const ValueKey('results'),
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMealAnalysisCard(result),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    '${validSuggestions.length} accord${validSuggestions.length > 1 ? 's' : ''} trouvé${validSuggestions.length > 1 ? 's' : ''}',
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _newSearch,
                    icon: const Icon(Icons.refresh,
                        size: 16, color: AppColors.text2),
                    label: Text(
                      'Nouvelle recherche',
                      style:
                          AppText.sans(color: AppColors.text2, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...validSuggestions.asMap().entries.map((entry) {
                final index = entry.key;
                final suggestion = entry.value;
                final wine = winesById[suggestion.wineId]!;
                final wineBottles =
                    bottles.where((b) => b.wineId == wine.id).toList();

                return TweenAnimationBuilder<double>(
                  key: ValueKey(suggestion.wineId),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + index * 100),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SuggestionCard(
                      rank: index + 1,
                      suggestion: suggestion,
                      wine: wine,
                      bottleCount: wineBottles.length,
                      onTap: () => showWineDetail(
                        context,
                        wine: wine,
                        bottles: wineBottles,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealAnalysisCard(PairingResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_outlined, size: 18, color: AppColors.text3),
              const SizedBox(width: 10),
              Text(
                'VOTRE REPAS',
                style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lastMeal,
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.mealAnalysis.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANALYSE DU SOMMELIER',
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.mealAnalysis,
                    style: AppText.sans(
                      color: AppColors.text,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final int rank;
  final PairingSuggestion suggestion;
  final Wine wine;
  final int bottleCount;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.rank,
    required this.suggestion,
    required this.wine,
    required this.bottleCount,
    required this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hover = false;

  String get _accordLevel {
    final score = widget.suggestion.score;
    if (score >= 90) return 'ACCORD PARFAIT';
    if (score >= 75) return 'EXCELLENT ACCORD';
    return 'BON ACCORD';
  }

  Color get _scoreColor {
    final score = widget.suggestion.score;
    if (score >= 90) return AppColors.gold;
    if (score >= 75) return AppColors.gold2;
    return AppColors.text2;
  }

  @override
  Widget build(BuildContext context) {
    final wine = widget.wine;
    final suggestion = widget.suggestion;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _hover ? AppColors.bg3 : AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? AppColors.border2 : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _scoreColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: _scoreColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${suggestion.score}',
                        style: AppText.sans(
                          color: _scoreColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wine.name,
                          style: AppText.serif(
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: wineTypeColor(wine.type),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  wineTypeLabel(wine.type),
                                  if (wine.vintage != null) '${wine.vintage}',
                                  if (wine.appellation.isNotEmpty)
                                    wine.appellation,
                                ].join(' · '),
                                style: AppText.sans(
                                  color: AppColors.text2,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.bottleCount} bouteille${widget.bottleCount > 1 ? 's' : ''} en cave',
                          style: AppText.sans(
                            color: AppColors.text3,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (wine.photoUrl != null) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        wine.photoUrl!,
                        width: 52,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _accordLevel,
                  style: AppText.sans(
                    color: _scoreColor,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                suggestion.explanation,
                style: AppText.sans(
                  color: AppColors.text,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              if (suggestion.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: suggestion.highlights.map((h) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bg4,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        h,
                        style: AppText.sans(
                          color: AppColors.text2,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
