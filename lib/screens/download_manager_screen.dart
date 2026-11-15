import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/download_task.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../services/download_manager_service.dart';
import '../services/file_service.dart';
import '../services/media_launcher.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_folder_picker.dart';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  final DownloadManagerService _service = DownloadManagerService.instance;
  DownloadCategory? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service.init();
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  List<DownloadTask> get _filteredTasks {
    var list = _service.tasks;
    if (_selectedCategory != null) {
      list = list.where((t) => t.category == _selectedCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) => t.fileName.toLowerCase().contains(q) || t.url.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _showAddDownloadDialog(BuildContext context, FluentColors colors) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final proxyController = TextEditingController();

    DownloadCategory detectedCategory = DownloadCategory.others;
    String selectedDestinationDir = '';
    bool useSystemProxy = false;
    bool isCustomFolder = false;

    // Eagerly query default folder
    _service.getDefaultCategoryFolder(detectedCategory).then((dir) {
      if (selectedDestinationDir.isEmpty) {
        selectedDestinationDir = dir;
      }
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            if (selectedDestinationDir.isEmpty) {
              _service.getDefaultCategoryFolder(detectedCategory).then((dir) {
                if (dialogCtx.mounted) {
                  setDialogState(() {
                    selectedDestinationDir = dir;
                  });
                }
              });
            }

            void updateUrl(String url) async {
              if (url.trim().isNotEmpty) {
                try {
                  final uri = Uri.parse(url.trim());
                  final base = p.basename(uri.path);
                  if (base.contains('.') && nameController.text.trim().isEmpty) {
                    nameController.text = base;
                    detectedCategory = DownloadCategoryX.detectFromFileName(base);
                    if (!isCustomFolder) {
                      selectedDestinationDir = await _service.getDefaultCategoryFolder(detectedCategory);
                    }
                    setDialogState(() {});
                  }
                } catch (_) {}
              }
            }

            return AlertDialog(
              backgroundColor: colors.cardSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.download_rounded, size: 20, color: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'New Download Task',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // URL Field
                      TextField(
                        controller: urlController,
                        autofocus: true,
                        style: TextStyle(fontSize: 13, color: colors.textPrimary),
                        onChanged: updateUrl,
                        decoration: InputDecoration(
                          labelText: 'Download Address (URL)',
                          labelStyle: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                          hintText: 'https://example.com/file.zip',
                          hintStyle: TextStyle(fontSize: 12.5, color: colors.textMuted),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste_go, size: 18),
                            tooltip: 'Paste from clipboard',
                            onPressed: () async {
                              final clip = await Clipboard.getData(Clipboard.kTextPlain);
                              if (clip != null && clip.text != null) {
                                urlController.text = clip.text!.trim();
                                updateUrl(urlController.text);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filename Field
                      TextField(
                        controller: nameController,
                        style: TextStyle(fontSize: 13, color: colors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Custom Filename (Optional)',
                          labelStyle: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                          hintText: 'Leave empty to auto-detect',
                          hintStyle: TextStyle(fontSize: 12.5, color: colors.textMuted),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DownloadCategory>(
                              value: detectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                labelStyle: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: DownloadCategory.values.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Icon(cat.icon, size: 18, color: cat.color),
                                      const SizedBox(width: 8),
                                      Text(cat.displayName, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (cat) async {
                                if (cat != null) {
                                  detectedCategory = cat;
                                  if (!isCustomFolder) {
                                    selectedDestinationDir = await _service.getDefaultCategoryFolder(cat);
                                  }
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Save To Folder
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Save To:', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                                const SizedBox(height: 2),
                                Text(
                                  selectedDestinationDir.replaceAll('/storage/emulated/0', 'Storage'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Change', style: TextStyle(fontSize: 11.5)),
                            onPressed: () async {
                              final picked = await FluentFolderPicker.show(ctx, initialPath: selectedDestinationDir);
                              if (picked != null && picked.isNotEmpty) {
                                setDialogState(() {
                                  selectedDestinationDir = picked;
                                  isCustomFolder = true;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: colors.borderSubtle),
                      const SizedBox(height: 8),

                      // Proxy Settings Expansion
                      Theme(
                        data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: colors.primary),
                              const SizedBox(width: 6),
                              Text('Proxy & Network Options', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                            ],
                          ),
                          children: [
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('Use System Proxy', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                              subtitle: Text('Routes download through device VPN or system HTTP proxy', style: TextStyle(fontSize: 10.5, color: colors.textMuted)),
                              value: useSystemProxy,
                              onChanged: (val) {
                                setDialogState(() {
                                  useSystemProxy = val ?? false;
                                });
                              },
                            ),
                            if (!useSystemProxy) ...[
                              const SizedBox(height: 6),
                              TextField(
                                controller: proxyController,
                                style: TextStyle(fontSize: 12, color: colors.textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Custom HTTP Proxy (e.g. 127.0.0.1:8080)',
                                  labelStyle: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                                  hintText: 'host:port',
                                  hintStyle: TextStyle(fontSize: 11.5, color: colors.textMuted),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Start Download'),
                  style: FilledButton.styleFrom(backgroundColor: colors.primary),
                  onPressed: () async {
                    final url = urlController.text.trim();
                    if (url.isEmpty) return;

                    final customName = nameController.text.trim();
                    final customProxy = proxyController.text.trim();

                    Navigator.pop(ctx);
                    await _service.addTask(
                      url: url,
                      customFileName: customName.isNotEmpty ? customName : null,
                      customDestinationDir: selectedDestinationDir,
                      category: detectedCategory,
                      useSystemProxy: useSystemProxy,
                      customProxy: customProxy.isNotEmpty ? customProxy : null,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFile(DownloadTask task) {
    try {
      final f = File(task.destinationPath);
      if (f.existsSync()) {
        final item = FileItem.fromFileSystemEntity(f);
        MediaLauncher.openItem(context, item);
      } else {
        FileService.openFile(task.destinationPath, useChooser: true);
      }
    } catch (_) {
      FileService.openFile(task.destinationPath, useChooser: true);
    }
  }

  void _openInFolder(DownloadTask task) {
    final parent = p.dirname(task.destinationPath);
    final explorer = context.read<ExplorerProvider>();
    explorer.navigateTo(parent);
    Navigator.pop(context); // Return to main explorer at target folder
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final tasks = _filteredTasks;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_done_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Download Manager',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ],
            ),
            Text(
              '${_service.activeDownloadsCount} active • ${_service.tasks.length} total downloads',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.playlist_add_rounded, color: colors.primary),
            tooltip: 'Add New Download',
            onPressed: () => _showAddDownloadDialog(context, colors),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors.textPrimary),
            tooltip: 'Options',
            onSelected: (val) {
              if (val == 'resume_all') {
                _service.resumeAll();
              } else if (val == 'pause_all') {
                _service.pauseAll();
              } else if (val == 'clear_completed') {
                _service.clearCompleted();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'resume_all',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Resume All Downloads'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pause_all',
                child: Row(
                  children: [
                    Icon(Icons.pause_rounded, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Pause All Downloads'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Completed Tasks'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.borderSubtle, height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. Windows IDM-Style Quick Ribbon Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              border: Border(bottom: BorderSide(color: colors.borderSubtle)),
            ),
            child: Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add URL', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: () => _showAddDownloadDialog(context, colors),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.green),
                  label: Text('Resume All', style: TextStyle(fontSize: 11.5, color: colors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: _service.tasks.any((t) => t.canResume) ? _service.resumeAll : null,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pause_rounded, size: 16, color: Colors.orange),
                  label: Text('Pause All', style: TextStyle(fontSize: 11.5, color: colors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: _service.tasks.any((t) => t.canPause) ? _service.pauseAll : null,
                ),
              ],
            ),
          ),

          // 2. Category Selector Chips
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: colors.container.withOpacity(0.5),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip(null, 'All (${_service.tasks.length})', Icons.all_inbox_rounded, colors),
                ...DownloadCategory.values.map((cat) {
                  final count = _service.tasks.where((t) => t.category == cat).length;
                  return _buildCategoryChip(cat, '${cat.displayName} ($count)', cat.icon, colors, accentColor: cat.color);
                }),
              ],
            ),
          ),

          // 3. Download Tasks List
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyState(colors)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskCard(task, colors);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
    DownloadCategory? category,
    String label,
    IconData icon,
    FluentColors colors, {
    Color? accentColor,
  }) {
    final isSelected = _selectedCategory == category;
    final color = accentColor ?? colors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : colors.textPrimary,
          ),
        ),
        backgroundColor: colors.cardSurface,
        selectedColor: color,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: isSelected ? color : colors.borderSubtle),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
          });
        },
      ),
    );
  }

  Widget _buildTaskCard(DownloadTask task, FluentColors colors) {
    Color statusColor;
    String statusText;
    switch (task.status) {
      case DownloadStatus.downloading:
        statusColor = const Color(0xFF0078D4);
        statusText = 'Downloading';
        break;
      case DownloadStatus.paused:
        statusColor = Colors.orange;
        statusText = 'Paused';
        break;
      case DownloadStatus.completed:
        statusColor = const Color(0xFF107C41);
        statusText = 'Completed';
        break;
      case DownloadStatus.failed:
        statusColor = Colors.redAccent;
        statusText = 'Failed';
        break;
      case DownloadStatus.cancelled:
        statusColor = colors.textMuted;
        statusText = 'Cancelled';
        break;
      case DownloadStatus.queued:
        statusColor = colors.textSecondary;
        statusText = 'Queued';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: task.status == DownloadStatus.downloading
              ? colors.primary.withOpacity(0.4)
              : colors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Icon + Name + Action buttons
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: task.category.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(task.category.icon, size: 20, color: task.category.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.dirname(task.destinationPath).replaceAll('/storage/emulated/0', 'Storage'),
                      style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (task.canPause)
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline, size: 22, color: Colors.orange),
                  tooltip: 'Pause',
                  onPressed: () => _service.pauseTask(task.id),
                ),
              if (task.canResume)
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 22, color: Colors.green),
                  tooltip: 'Resume',
                  onPressed: () => _service.resumeTask(task.id),
                ),
              if (task.isCompleted) ...[
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 20, color: colors.primary),
                  tooltip: 'Open File',
                  onPressed: () => _openFile(task),
                ),
                IconButton(
                  icon: Icon(Icons.folder_open_outlined, size: 20, color: colors.textSecondary),
                  tooltip: 'Open in Folder',
                  onPressed: () => _openInFolder(task),
                ),
              ],
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: colors.textMuted),
                tooltip: 'Delete Task',
                onPressed: () => _showDeleteTaskDialog(task, colors),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Linear Progress Bar (IDM style)
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: task.totalBytes > 0
                  ? task.progress
                  : (task.status == DownloadStatus.completed ? 1.0 : null),
              backgroundColor: colors.container,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 8),

          // Bottom Info Row: Percentage, Size, Speed, ETA & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${task.percentageString} • ${task.formattedSize}',
                style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w500),
              ),
              if (task.status == DownloadStatus.downloading && task.formattedSpeed.isNotEmpty)
                Text(
                  '${task.formattedSpeed} • ${task.estimatedTimeRemaining}',
                  style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),

          if (task.errorMessage != null && task.status == DownloadStatus.failed) ...[
            const SizedBox(height: 6),
            Text(
              task.errorMessage!,
              style: const TextStyle(fontSize: 10.5, color: Colors.redAccent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteTaskDialog(DownloadTask task, FluentColors colors) {
    bool deletePhysicalFile = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text(
            'Remove Download?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove "${task.fileName}" from the download list?',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Also delete file from storage', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                value: deletePhysicalFile,
                onChanged: (val) {
                  setDialogState(() {
                    deletePhysicalFile = val ?? false;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _service.deleteTask(task.id, deleteFile: deletePhysicalFile);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(FluentColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.download_done_rounded, size: 34, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory != null
                ? 'No ${_selectedCategory!.displayName} downloads'
                : 'No downloads yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Add links or direct URLs to download files at high speed',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add New Download'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showAddDownloadDialog(context, colors),
          ),
        ],
      ),
    );
  }
}
