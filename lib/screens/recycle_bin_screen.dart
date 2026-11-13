import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../models/recycle_bin_item.dart';
import '../providers/settings_provider.dart';
import '../services/recycle_bin_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_file_icons.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final RecycleBinService _bin = RecycleBinService.instance;
  List<RecycleBinItem> _items = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final settings = context.read<SettingsProvider>();
    await _bin.cleanupExpiredItems(settings.recycleBinRetentionDays);
    final loaded = await _bin.getItems();
    if (mounted) {
      setState(() {
        _items = loaded;
        _selectedIds.clear();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmEmptyBin() async {
    if (_items.isEmpty) return;
    final colors = FluentColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Empty Recycle Bin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to permanently delete all ${_items.length} item(s) in the Recycle Bin?',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Empty Recycle Bin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _bin.emptyBin();
      if (mounted) {
        await _loadItems();
      }
    }
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final colors = FluentColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Delete Permanently', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedIds.length} selected item(s)? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _bin.deletePermanently(_selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permanently deleted ${_selectedIds.length} item(s)')),
        );
        await _loadItems();
      }
    }
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isLoading = true);
    await _bin.restoreItems(_selectedIds.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored ${_selectedIds.length} item(s) to original location')),
      );
      await _loadItems();
    }
  }

  Future<void> _restoreAll() async {
    if (_items.isEmpty) return;
    setState(() => _isLoading = true);
    await _bin.restoreAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored all ${_items.length} item(s)')),
      );
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.cardSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_outlined, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              'Recycle Bin',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty) ...[
            TextButton.icon(
              icon: const Icon(Icons.restore_page_outlined, size: 18),
              label: const Text('Restore All'),
              onPressed: _restoreAll,
              style: TextButton.styleFrom(foregroundColor: colors.primary),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
              tooltip: 'Empty Recycle Bin',
              onPressed: _confirmEmptyBin,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.borderSubtle, height: 1),
        ),
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
                      onPressed: _restoreSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Delete'),
                      onPressed: _confirmDeleteSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _items.isEmpty
              ? _buildEmptyState(colors, settings)
              : Column(
                  children: [
                    // Retention notice banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: colors.container,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              settings.recycleBinRetentionDays > 0
                                  ? 'Items are kept for ${settings.recycleBinRetentionDays} days before automatic permanent deletion.'
                                  : 'Items are retained indefinitely until you empty the bin.',
                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.borderSubtle),

                    // Items list
                    Expanded(
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final isSelected = _selectedIds.contains(item.id);
                          final ext = item.originalName.contains('.')
                              ? item.originalName.split('.').last.toLowerCase()
                              : '';

                          final fileItem = FileItem(
                            path: item.recycledPath,
                            name: item.originalName,
                            isDirectory: item.isDirectory,
                            size: item.size,
                            modified: item.deletedAt,
                            isHidden: false,
                            extension: ext,
                          );

                          return Container(
                            color: isSelected ? colors.primary.withOpacity(0.08) : Colors.transparent,
                            child: ListTile(
                              leading: item.isDirectory
                                  ? const Icon(Icons.folder, color: Colors.amber, size: 28)
                                  : FluentFileIcon(item: fileItem, size: 28),
                              title: Text(
                                item.originalName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: item.isDirectory ? FontWeight.w600 : FontWeight.normal,
                                  color: colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Original: ${item.originalPath}',
                                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Deleted: ${item.formatDeletedDate()} • ${item.formatSize()}',
                                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                                  ),
                                ],
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(item.id);
                                    } else {
                                      _selectedIds.remove(item.id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(item.id);
                                  } else {
                                    _selectedIds.add(item.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(FluentColors colors, SettingsProvider settings) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 64, color: colors.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'Recycle Bin is empty',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Deleted files are stored safely here before being purged',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
