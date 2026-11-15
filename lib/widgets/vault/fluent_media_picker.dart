import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/file_item.dart';
import '../../services/file_service.dart';
import '../../theme/fluent_theme.dart';
import '../fluent_file_icons.dart';

enum VaultMediaType {
  images,
  videos,
  documents,
}

class FluentMediaPicker extends StatefulWidget {
  final VaultMediaType mediaType;
  final ValueChanged<List<String>> onImportSelected;
  final String? customScanPath;
  final List<FileItem>? initialFiles;

  const FluentMediaPicker({
    super.key,
    required this.mediaType,
    required this.onImportSelected,
    this.customScanPath,
    this.initialFiles,
  });

  @override
  State<FluentMediaPicker> createState() => _FluentMediaPickerState();
}

class _FluentMediaPickerState extends State<FluentMediaPicker> {
  final Set<String> _selectedPaths = {};
  List<FileItem> _mediaFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'svg'};
  static const _videoExts = {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv', 'wmv', 'm4v'};
  static const _docExts = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'epub', 'csv', 'zip', 'rar', '7z', 'json'
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialFiles != null) {
      _mediaFiles = List.from(widget.initialFiles!);
      _isLoading = false;
    } else {
      _scanMedia();
    }
  }

  Set<String> get _targetExtensions {
    switch (widget.mediaType) {
      case VaultMediaType.images:
        return _imageExts;
      case VaultMediaType.videos:
        return _videoExts;
      case VaultMediaType.documents:
        return _docExts;
    }
  }

  String get _title {
    switch (widget.mediaType) {
      case VaultMediaType.images:
        return 'Select Photos & Images';
      case VaultMediaType.videos:
        return 'Select Videos';
      case VaultMediaType.documents:
        return 'Select Documents & Files';
    }
  }

  IconData get _typeIcon {
    switch (widget.mediaType) {
      case VaultMediaType.images:
        return Icons.photo_library_outlined;
      case VaultMediaType.videos:
        return Icons.video_library_outlined;
      case VaultMediaType.documents:
        return Icons.description_outlined;
    }
  }

  Color _getTypeColor(FluentColors colors) {
    switch (widget.mediaType) {
      case VaultMediaType.images:
        return const Color(0xFF0078D4);
      case VaultMediaType.videos:
        return const Color(0xFF881798);
      case VaultMediaType.documents:
        return const Color(0xFF107C41);
    }
  }

  Future<void> _scanMedia() async {
    setState(() => _isLoading = true);

    final List<FileItem> results = [];
    final extensions = _targetExtensions;

    // Standard Android storage scan paths
    final List<String> directoriesToScan = [];
    if (widget.customScanPath != null && widget.customScanPath!.isNotEmpty) {
      directoriesToScan.add(widget.customScanPath!);
    } else {
      const root = '/storage/emulated/0';
      if (await Directory(root).exists()) {
        switch (widget.mediaType) {
          case VaultMediaType.images:
            directoriesToScan.addAll([
              '$root/DCIM/Camera',
              '$root/DCIM',
              '$root/Pictures',
              '$root/Download',
              '$root/Telegram',
              '$root/WhatsApp/Media/WhatsApp Images',
            ]);
            break;
          case VaultMediaType.videos:
            directoriesToScan.addAll([
              '$root/DCIM/Camera',
              '$root/Movies',
              '$root/Download',
              '$root/DCIM',
              '$root/Telegram',
              '$root/WhatsApp/Media/WhatsApp Video',
            ]);
            break;
          case VaultMediaType.documents:
            directoriesToScan.addAll([
              '$root/Download',
              '$root/Documents',
              '$root/Documents/Telegram',
              '$root/WhatsApp/Media/WhatsApp Documents',
            ]);
            break;
        }
      } else {
        // Fallback to system temp / desktop directory in test / desktop environment
        directoriesToScan.add(Directory.systemTemp.path);
      }
    }

    final visited = <String>{};

    for (final dirPath in directoriesToScan) {
      final dir = Directory(dirPath);
      if (!await dir.exists() || visited.contains(dir.path)) continue;
      visited.add(dir.path);

      try {
        final entities = dir.listSync(recursive: false, followLinks: false);
        for (final entity in entities) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name.startsWith('.') || name == '.nomedia') continue;

          final ext = p.extension(name).toLowerCase().replaceAll('.', '');
          if (extensions.contains(ext)) {
            try {
              results.add(FileItem.fromFileSystemEntity(entity));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // Sort newest first (like Telegram / Instagram)
    results.sort((a, b) => b.modified.compareTo(a.modified));

    if (mounted) {
      setState(() {
        _mediaFiles = results;
        _isLoading = false;
      });
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedPaths.length == _filteredFiles.length) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.clear();
        _selectedPaths.addAll(_filteredFiles.map((e) => e.path));
      }
    });
  }

  List<FileItem> get _filteredFiles {
    if (_searchQuery.trim().isEmpty) return _mediaFiles;
    final q = _searchQuery.toLowerCase().trim();
    return _mediaFiles.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _getTypeColor(colors);
    final files = _filteredFiles;
    final screenWidth = MediaQuery.of(context).size.width;
    final columnCount = screenWidth > 720 ? 4 : (screenWidth > 480 ? 3 : 3);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Material(
        color: colors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: colors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: colors.textPrimary),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(left: 4, right: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_typeIcon, size: 18, color: accentColor),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        _isLoading
                            ? 'Scanning storage...'
                            : '${files.length} item${files.length == 1 ? '' : 's'} found',
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!_isLoading && files.isNotEmpty)
                  TextButton.icon(
                    onPressed: _toggleSelectAll,
                    icon: Icon(
                      _selectedPaths.length == files.length
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    label: Text(
                      _selectedPaths.length == files.length ? 'Clear' : 'Select All',
                      style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: colors.borderSubtle),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : files.isEmpty
                    ? _buildEmptyState(colors)
                    : widget.mediaType == VaultMediaType.documents
                        ? _buildDocumentsList(files, colors, accentColor)
                        : _buildMediaGrid(files, colors, accentColor, columnCount),
          ),

          // Sticky Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.container,
              border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedPaths.isEmpty
                              ? 'Tap items to select'
                              : '${_selectedPaths.length} item${_selectedPaths.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Will be encrypted & hidden in File Vault',
                          style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _selectedPaths.isEmpty
                        ? null
                        : () => widget.onImportSelected(_selectedPaths.toList()),
                    icon: const Icon(Icons.lock_rounded, size: 16),
                    label: Text('Import (${_selectedPaths.length})'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      disabledBackgroundColor: colors.container,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
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
          Icon(Icons.perm_media_outlined, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No files found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'No compatible ${widget.mediaType.name} found in device media folders',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(List<FileItem> files, FluentColors colors, Color accentColor, int columnCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final item = files[index];
        final isSelected = _selectedPaths.contains(item.path);

        return InkWell(
          key: ValueKey('media_tile_${item.path}'),
          onTap: () => _toggleSelect(item.path),
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media preview
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.mediaType == VaultMediaType.images
                    ? Image.file(
                        File(item.path),
                        cacheWidth: 260,
                        cacheHeight: 260,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.container,
                          child: Icon(Icons.broken_image_outlined, size: 28, color: colors.textMuted),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: colors.container,
                          gradient: LinearGradient(
                            colors: [
                              colors.primary.withOpacity(0.12),
                              colors.primary.withOpacity(0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 38,
                            color: accentColor.withOpacity(0.85),
                          ),
                        ),
                      ),
              ),

              // Video label / details overlay
              if (widget.mediaType == VaultMediaType.videos)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Selection border
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor, width: 2.5),
                      color: accentColor.withOpacity(0.18),
                    ),
                  ),
                ),

              // Checkmark badge (like Telegram / Instagram)
              Positioned(
                top: 6,
                right: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accentColor : Colors.black.withOpacity(0.35),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentsList(List<FileItem> files, FluentColors colors, Color accentColor) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: files.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: colors.borderSubtle),
      itemBuilder: (context, index) {
        final item = files[index];
        final isSelected = _selectedPaths.contains(item.path);

        return Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: FluentFileIcon(item: item, size: 30),
            title: Text(
              item.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${item.formatSize()} • ${p.dirname(item.path).replaceAll('/storage/emulated/0', 'Storage')}',
              style: TextStyle(fontSize: 11, color: colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Checkbox(
              value: isSelected,
              activeColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (_) => _toggleSelect(item.path),
            ),
            onTap: () => _toggleSelect(item.path),
          ),
        );
      },
    );
  }
}
