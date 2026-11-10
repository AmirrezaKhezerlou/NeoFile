import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../services/file_service.dart';
import '../services/media_launcher.dart';
import '../services/storage_analyzer_service.dart';
import '../theme/fluent_theme.dart';

enum AnalyzerSortOption {
  sizeDesc('Largest first', Icons.arrow_downward),
  sizeAsc('Smallest first', Icons.arrow_upward),
  dateDesc('Newest first', Icons.schedule),
  dateAsc('Oldest first', Icons.history),
  nameAsc('Name (A-Z)', Icons.sort_by_alpha);

  final String label;
  final IconData icon;
  const AnalyzerSortOption(this.label, this.icon);
}

class StorageAnalyzerScreen extends StatefulWidget {
  const StorageAnalyzerScreen({super.key});

  @override
  State<StorageAnalyzerScreen> createState() => _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends State<StorageAnalyzerScreen> {
  final StorageAnalyzerService _analyzer = StorageAnalyzerService.instance;

  StorageCategory? _activeCategory;
  bool _isViewingLargeFiles = false;
  AnalyzerSortOption _currentSort = AnalyzerSortOption.sizeDesc;
  String _searchQuery = '';
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _analyzer.addListener(_onServiceUpdate);
    if (_analyzer.lastSnapshot == null) {
      _analyzer.startAnalysis();
    }
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _analyzer.removeListener(_onServiceUpdate);
    super.dispose();
  }

  List<StorageAnalyzedFile> _getProcessedFiles() {
    final snapshot = _analyzer.lastSnapshot;
    if (snapshot == null) return [];

    List<StorageAnalyzedFile> list = [];
    if (_isViewingLargeFiles) {
      list = List.from(snapshot.largeFiles);
    } else if (_activeCategory != null) {
      final catData = snapshot.categories[_activeCategory!];
      if (catData != null) {
        list = List.from(catData.files);
      }
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q) || f.path.toLowerCase().contains(q)).toList();
    }

    switch (_currentSort) {
      case AnalyzerSortOption.sizeDesc:
        list.sort((a, b) => b.size.compareTo(a.size));
        break;
      case AnalyzerSortOption.sizeAsc:
        list.sort((a, b) => a.size.compareTo(b.size));
        break;
      case AnalyzerSortOption.dateDesc:
        list.sort((a, b) => b.modified.compareTo(a.modified));
        break;
      case AnalyzerSortOption.dateAsc:
        list.sort((a, b) => a.modified.compareTo(b.modified));
        break;
      case AnalyzerSortOption.nameAsc:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return list;
  }

  int _calculateSelectedBytes(List<StorageAnalyzedFile> files) {
    int total = 0;
    for (final f in files) {
      if (_selectedPaths.contains(f.path)) {
        total += f.size;
      }
    }
    return total;
  }

  Future<void> _deleteSelectedFiles(List<StorageAnalyzedFile> files) async {
    final toDelete = _selectedPaths.toList();
    if (toDelete.isEmpty) return;

    final colors = FluentColors.of(context);
    final selectedBytes = _calculateSelectedBytes(files);
    final formattedBytes = StorageAnalyzerService.formatSize(selectedBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: colors.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'Delete ${toDelete.length} File${toDelete.length > 1 ? 's' : ''}?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete the selected files ($formattedBytes) from device storage. This action cannot be undone.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _analyzer.deleteFiles(toDelete);
      if (mounted) {
        setState(() {
          _selectedPaths.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Deleted ${toDelete.length} files. Freed $formattedBytes.'
                  : 'Failed to delete some files.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openFile(StorageAnalyzedFile file) {
    try {
      final f = File(file.path);
      if (f.existsSync()) {
        final item = FileItem.fromFileSystemEntity(f);
        MediaLauncher.openItem(context, item);
      }
    } catch (_) {
      FileService.openFile(file.path, useChooser: true);
    }
  }

  void _navigateToFileLocation(String filePath) {
    final parent = p.dirname(filePath);
    final explorer = context.read<ExplorerProvider>();
    explorer.navigateTo(parent);
    Navigator.pop(context); // Return to main explorer
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final isDrillDown = _activeCategory != null || _isViewingLargeFiles;
    final title = _isViewingLargeFiles
        ? 'Large Files (> 50 MB)'
        : (_activeCategory != null ? _activeCategory!.displayName : 'Storage Analyzer');

    return PopScope(
      canPop: !isDrillDown,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isDrillDown) {
          setState(() {
            _activeCategory = null;
            _isViewingLargeFiles = false;
            _selectedPaths.clear();
            _searchQuery = '';
          });
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
        backgroundColor: colors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () {
            if (isDrillDown) {
              setState(() {
                _activeCategory = null;
                _isViewingLargeFiles = false;
                _selectedPaths.clear();
                _searchQuery = '';
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          if (!isDrillDown) ...[
            if (_analyzer.isScanning)
              TextButton.icon(
                onPressed: () => _analyzer.cancelScan(),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Cancel', style: TextStyle(fontSize: 12)),
              )
            else
              IconButton(
                icon: Icon(Icons.refresh, color: colors.textPrimary),
                tooltip: 'Re-analyze Storage',
                onPressed: () => _analyzer.startAnalysis(forceRefresh: true),
              ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.border, height: 1),
        ),
      ),
      body: _analyzer.isScanning
          ? _buildScanningView(colors)
          : isDrillDown
              ? _buildDrillDownView(colors)
              : _buildOverviewView(colors),
      ),
    );
  }

  // 1. Scanning State View
  Widget _buildScanningView(FluentColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storage_outlined, size: 32, color: colors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing Device Storage...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _analyzer.currentScanningPath,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _analyzer.scanProgress > 0 ? _analyzer.scanProgress : null,
                minHeight: 6,
                backgroundColor: colors.container,
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_analyzer.scannedFilesCount} files examined',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Main Overview View
  Widget _buildOverviewView(FluentColors colors) {
    final snapshot = _analyzer.lastSnapshot;
    if (snapshot == null) {
      return Center(
        child: Text('No storage analysis data available.', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Windows 11 Storage Sense Overview Card
        _buildStorageCapacityCard(snapshot, colors),
        const SizedBox(height: 16),

        // Quick Clean Large Files Card
        if (snapshot.largeFiles.isNotEmpty) ...[
          _buildLargeFilesHighlightCard(snapshot, colors),
          const SizedBox(height: 16),
        ],

        // Section Title: Category Breakdown
        Row(
          children: [
            Icon(Icons.pie_chart_outline, size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              'Storage Breakdown by File Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.45,
              ),
              itemCount: StorageCategory.values.length,
              itemBuilder: (context, index) {
                final cat = StorageCategory.values[index];
                final catData = snapshot.categories[cat];
                return _buildCategoryCard(cat, catData, snapshot, colors);
              },
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStorageCapacityCard(StorageAnalysisSnapshot snapshot, FluentColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Internal Storage',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${(snapshot.usedPercentage * 100).toStringAsFixed(1)}% Used',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                snapshot.formattedUsedStorage,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              const SizedBox(width: 6),
              Text(
                'used of ${snapshot.formattedTotalStorage} (${snapshot.formattedFreeStorage} free)',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-segmented colored progress bar
          _buildSegmentedProgressBar(snapshot, colors),
          const SizedBox(height: 14),

          // Legend chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: StorageCategory.values.map((cat) {
              final catData = snapshot.categories[cat];
              final bytes = catData?.totalBytes ?? 0;
              if (bytes == 0) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${cat.displayName}: ${catData?.formattedTotal}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedProgressBar(StorageAnalysisSnapshot snapshot, FluentColors colors) {
    final total = snapshot.totalStorageBytes > 0 ? snapshot.totalStorageBytes : 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 10,
        color: colors.container,
        child: Row(
          children: StorageCategory.values.map((cat) {
            final catData = snapshot.categories[cat];
            final bytes = catData?.totalBytes ?? 0;
            if (bytes <= 0) return const SizedBox.shrink();

            final flex = ((bytes / total) * 1000).toInt().clamp(1, 1000);
            return Expanded(
              flex: flex,
              child: Container(color: cat.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLargeFilesHighlightCard(StorageAnalysisSnapshot snapshot, FluentColors colors) {
    int totalLargeBytes = 0;
    for (final f in snapshot.largeFiles) {
      totalLargeBytes += f.size;
    }
    final formattedLarge = StorageAnalyzerService.formatSize(totalLargeBytes);

    return InkWell(
      onTap: () {
        setState(() {
          _isViewingLargeFiles = true;
          _activeCategory = null;
          _selectedPaths.clear();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.amber.shade700.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Large Files (> 50 MB)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${snapshot.largeFiles.length}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Occupy $formattedLarge total • Quick storage cleanup',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    StorageCategory cat,
    StorageCategoryData? catData,
    StorageAnalysisSnapshot snapshot,
    FluentColors colors,
  ) {
    final count = catData?.fileCount ?? 0;
    final formattedSize = catData?.formattedTotal ?? '0 B';

    return InkWell(
      onTap: () {
        setState(() {
          _activeCategory = cat;
          _isViewingLargeFiles = false;
          _selectedPaths.clear();
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(cat.icon, size: 18, color: cat.color),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedSize,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cat.color),
                    ),
                    Text(
                      '$count file${count != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 10, color: colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. Drill-Down Category / Large Files View
  Widget _buildDrillDownView(FluentColors colors) {
    final files = _getProcessedFiles();
    final hasSelection = _selectedPaths.isNotEmpty;
    final selectedBytes = _calculateSelectedBytes(files);

    return Column(
      children: [
        // Filter & Sort Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: colors.cardSurface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Filter by file name...',
                        hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: colors.borderSubtle),
                        ),
                      ),
                      style: TextStyle(fontSize: 12, color: colors.textPrimary),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sort Menu
                  PopupMenuButton<AnalyzerSortOption>(
                    icon: Icon(_currentSort.icon, size: 18, color: colors.textSecondary),
                    tooltip: 'Sort files',
                    onSelected: (opt) => setState(() => _currentSort = opt),
                    itemBuilder: (ctx) => AnalyzerSortOption.values.map((opt) {
                      return PopupMenuItem(
                        value: opt,
                        child: Row(
                          children: [
                            Icon(opt.icon, size: 16, color: _currentSort == opt ? colors.primary : colors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _currentSort == opt ? FontWeight.w600 : FontWeight.normal,
                                color: _currentSort == opt ? colors.primary : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${files.length} item${files.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                  const Spacer(),
                  if (files.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPaths.length == files.length) {
                            _selectedPaths.clear();
                          } else {
                            _selectedPaths.clear();
                            _selectedPaths.addAll(files.map((f) => f.path));
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedPaths.length == files.length ? 'Deselect All' : 'Select All',
                        style: TextStyle(fontSize: 11, color: colors.primary),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Files List
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 44, color: colors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty ? 'No files match your search' : 'No files in this category',
                        style: TextStyle(fontSize: 13, color: colors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: files.length,
                  separatorBuilder: (context, index) => Divider(height: 1, indent: 56, color: colors.borderSubtle),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isSelected = _selectedPaths.contains(file.path);

                    return InkWell(
                      onTap: () {
                        if (hasSelection) {
                          setState(() {
                            if (isSelected) {
                              _selectedPaths.remove(file.path);
                            } else {
                              _selectedPaths.add(file.path);
                            }
                          });
                        } else {
                          _openFile(file);
                        }
                      },
                      onLongPress: () {
                        setState(() {
                          if (isSelected) {
                            _selectedPaths.remove(file.path);
                          } else {
                            _selectedPaths.add(file.path);
                          }
                        });
                      },
                      child: Container(
                        color: isSelected ? colors.primary.withOpacity(0.08) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: colors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedPaths.add(file.path);
                                  } else {
                                    _selectedPaths.remove(file.path);
                                  }
                                });
                              },
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: file.category.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(file.category.icon, size: 18, color: file.category.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p.dirname(file.path),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  file.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: file.size >= StorageAnalyzerService.largeFileThreshold
                                        ? Colors.amber.shade800
                                        : colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${file.modified.year}/${file.modified.month.toString().padLeft(2, '0')}/${file.modified.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 10, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Floating Bottom Actions Bar on Selection
        if (hasSelection)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedPaths.length} selected',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        Text(
                          StorageAnalyzerService.formatSize(selectedBytes),
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPaths.length == 1)
                    IconButton(
                      icon: Icon(Icons.folder_open, size: 18, color: colors.primary),
                      tooltip: 'Show in folder',
                      onPressed: () => _navigateToFileLocation(_selectedPaths.first),
                    ),
                  IconButton(
                    icon: Icon(Icons.share_outlined, size: 18, color: colors.textSecondary),
                    tooltip: 'Share',
                    onPressed: () => FileService.shareFiles(_selectedPaths.toList()),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    onPressed: () => _deleteSelectedFiles(files),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
