import 'package:flutter/material.dart';
import '../services/cache_cleaner_service.dart';
import '../theme/fluent_theme.dart';

class FluentCacheCleanupSheet extends StatefulWidget {
  const FluentCacheCleanupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FluentCacheCleanupSheet(),
    );
  }

  @override
  State<FluentCacheCleanupSheet> createState() => _FluentCacheCleanupSheetState();
}

class _FluentCacheCleanupSheetState extends State<FluentCacheCleanupSheet> with SingleTickerProviderStateMixin {
  final CacheCleanerService _cleaner = CacheCleanerService.instance;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  bool _isCleaning = false;
  bool _isDone = false;
  CleanupResult? _result;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);

    _cleaner.addListener(_onServiceUpdate);

    // Initial analysis
    _cleaner.analyzeCache();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cleaner.removeListener(_onServiceUpdate);
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startCleaning() async {
    setState(() {
      _isCleaning = true;
      _isDone = false;
    });

    final res = await _cleaner.cleanCache();

    if (mounted) {
      setState(() {
        _isCleaning = false;
        _isDone = true;
        _result = res;
      });
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.76,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.24),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.textMuted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isCleaning
                          ? _buildCleaningProgressView(colors)
                          : (_isDone ? _buildDoneView(colors) : _buildPreCleanView(colors)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Initial State: Analysis Breakdown & "Clean Now"
  Widget _buildPreCleanView(FluentColors colors) {
    final analysis = _cleaner.lastAnalysis;
    final isAnalyzing = _cleaner.isAnalyzing;

    return Column(
      key: const ValueKey('pre_clean'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.cleaning_services_rounded, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temporary & Cache Cleanup',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Free up internal storage space safely',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Re-analyze',
                onPressed: isAnalyzing ? null : () => _cleaner.analyzeCache(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.borderSubtle),

        Expanded(
          child: isAnalyzing
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
                      const SizedBox(height: 14),
                      Text('Scanning temporary files...', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                    ],
                  ),
                )
              : (analysis == null || analysis.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: colors.success),
                          const SizedBox(height: 12),
                          Text('Storage is Clean', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('No temporary or residual files found', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // Total Reclaimable Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Reclaimable Space', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    analysis.formattedTotal,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.cardSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: colors.borderSubtle),
                                ),
                                child: Text(
                                  '${analysis.totalFiles} files',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Categories Breakdown
                        Text('Breakdown by category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        const SizedBox(height: 8),

                        ...analysis.categories.map((cat) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colors.container,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(cat.icon, size: 20, color: colors.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cat.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                                      Text(cat.description, style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      cat.formatBytes(),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: colors.textPrimary),
                                    ),
                                    Text('${cat.fileCount} files', style: TextStyle(fontSize: 10, color: colors.textMuted)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
        ),

        Divider(height: 1, color: colors.borderSubtle),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (analysis == null || analysis.isEmpty || isAnalyzing) ? null : _startCleaning,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text(
                    'Clean Temporary Files',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Animated Progress State during cleaning
  Widget _buildCleaningProgressView(FluentColors colors) {
    final progress = _cleaner.cleanProgress;
    final item = _cleaner.currentCleaningItem;

    return Center(
      key: const ValueKey('cleaning'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 5,
                    backgroundColor: colors.borderSubtle,
                    color: colors.primary,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: colors.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Cleaning Temporary Files...',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              item,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 5,
                backgroundColor: colors.container,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Completed Celebration View
  Widget _buildDoneView(FluentColors colors) {
    final res = _result;

    return ScaleTransition(
      key: const ValueKey('done'),
      scale: _scaleAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 54, color: colors.success),
              ),
              const SizedBox(height: 16),
              Text(
                'Storage Optimized!',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                res != null && res.bytesFreed > 0
                    ? '${res.formattedFreed} of temporary files successfully removed.'
                    : 'All temporary buffers are clean.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
              ),
              if (res != null && res.filesDeleted > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.container,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Text(
                    '${res.filesDeleted} files deleted',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  minimumSize: const Size(140, 40),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
