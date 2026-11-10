import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../models/file_item.dart';
import '../../services/file_service.dart';
import '../../theme/fluent_theme.dart';
import '../file_properties_sheet.dart';
import 'windows_media_header.dart';

class WindowsImageViewer extends StatefulWidget {
  final FileItem item;
  final List<FileItem>? siblingItems;

  const WindowsImageViewer({
    super.key,
    required this.item,
    this.siblingItems,
  });

  static void show(BuildContext context, FileItem item, [List<FileItem>? siblings]) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.65),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WindowsImageViewer(item: item, siblingItems: siblings);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<WindowsImageViewer> createState() => _WindowsImageViewerState();
}

class _WindowsImageViewerState extends State<WindowsImageViewer> {
  late FileItem _currentItem;
  late List<FileItem> _imageSiblings;
  int _currentIndex = 0;
  final TransformationController _transformController = TransformationController();
  int _rotationQuarterTurns = 0;
  bool _isFullscreen = false;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _initSiblings();
  }

  void _initSiblings() {
    if (widget.siblingItems != null && widget.siblingItems!.isNotEmpty) {
      _imageSiblings = widget.siblingItems!.where((f) => f.isImage).toList();
    } else {
      try {
        final parentDir = Directory(p.dirname(_currentItem.path));
        if (parentDir.existsSync()) {
          _imageSiblings = parentDir
              .listSync(followLinks: false)
              .whereType<File>()
              .map((f) => FileItem.fromFileSystemEntity(f))
              .where((f) => f.isImage)
              .toList();
        } else {
          _imageSiblings = [_currentItem];
        }
      } catch (_) {
        _imageSiblings = [_currentItem];
      }
    }
    _currentIndex = _imageSiblings.indexWhere((f) => f.path == _currentItem.path);
    if (_currentIndex < 0) _currentIndex = 0;
  }

  void _goToPrevious() {
    if (_imageSiblings.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _imageSiblings.length) % _imageSiblings.length;
      _currentItem = _imageSiblings[_currentIndex];
      _transformController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
      _zoomLevel = 1.0;
    });
  }

  void _goToNext() {
    if (_imageSiblings.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _imageSiblings.length;
      _currentItem = _imageSiblings[_currentIndex];
      _transformController.value = Matrix4.identity();
      _rotationQuarterTurns = 0;
      _zoomLevel = 1.0;
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _zoomLevel = 1.0;
    });
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.3).clamp(0.5, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
      _zoomLevel = newScale;
    });
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.3).clamp(0.5, 5.0);
    setState(() {
      _transformController.value = Matrix4.identity()..scale(newScale);
      _zoomLevel = newScale;
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        );
      }
    });
  }

  Future<void> _deleteCurrentPhoto() async {
    final colors = FluentColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: colors.error, size: 22),
            const SizedBox(width: 10),
            Text(
              'Delete Photo?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${_currentItem.name}" from your storage?',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = File(_currentItem.path);
        if (file.existsSync()) {
          file.deleteSync();
        }
        _imageSiblings.removeWhere((f) => f.path == _currentItem.path);
        if (_imageSiblings.isEmpty) {
          Navigator.of(context).pop();
        } else {
          if (_currentIndex >= _imageSiblings.length) {
            _currentIndex = _imageSiblings.length - 1;
          }
          setState(() {
            _currentItem = _imageSiblings[_currentIndex];
            _transformController.value = Matrix4.identity();
            _rotationQuarterTurns = 0;
            _zoomLevel = 1.0;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete image: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final usableWidth = size.width - (_isFullscreen ? 0 : padding.horizontal);
    final usableHeight = size.height - (_isFullscreen ? 0 : padding.vertical);

    final containerWidth = _isFullscreen ? size.width : (usableWidth > 900 ? 860.0 : usableWidth * 0.94);
    final containerHeight = _isFullscreen ? size.height : (usableHeight > 800 ? 700.0 : usableHeight * 0.90);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: !_isFullscreen,
        bottom: !_isFullscreen,
        left: !_isFullscreen,
        right: !_isFullscreen,
        child: Center(
          child: Container(
            width: containerWidth,
            height: containerHeight,
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 8),
              border: Border.all(color: colors.borderSubtle, width: _isFullscreen ? 0 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // 1. Windows Photos Title Bar
                WindowsMediaHeader(
                  title: '${_currentItem.name} (${(_zoomLevel * 100).toInt()}%)',
                  icon: Icons.image_outlined,
                  isFullscreen: _isFullscreen,
                  onClose: () {
                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.manual,
                      overlays: SystemUiOverlay.values,
                    );
                    Navigator.of(context).pop();
                  },
                  onMinimize: () {
                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.manual,
                      overlays: SystemUiOverlay.values,
                    );
                    Navigator.of(context).pop();
                  },
                  onToggleFullscreen: _toggleFullscreen,
                  onOpenWith: () {
                    FileService.openFile(_currentItem.path, useChooser: true);
                  },
                  extraActions: [
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
                      tooltip: 'Delete Photo',
                      onPressed: _deleteCurrentPhoto,
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      tooltip: 'File Properties',
                      onPressed: () => FilePropertiesSheet.show(context, _currentItem),
                      color: colors.textSecondary,
                    ),
                  ],
                ),

                // 2. Main Image Canvas with Zoom & Pan
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: colors.canvas,
                        alignment: Alignment.center,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.4,
                          maxScale: 6.0,
                          onInteractionUpdate: (details) {
                            final scale = _transformController.value.getMaxScaleOnAxis();
                            if (scale != _zoomLevel) {
                              setState(() => _zoomLevel = scale);
                            }
                          },
                          child: RotatedBox(
                            quarterTurns: _rotationQuarterTurns,
                            child: Image(
                              image: ResizeImage(
                                FileImage(File(_currentItem.path)),
                                width: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt().clamp(720, 2560),
                                height: (MediaQuery.of(context).size.height * MediaQuery.of(context).devicePixelRatio).toInt().clamp(1280, 2560),
                                policy: ResizeImagePolicy.fit,
                              ),
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined, size: 48, color: colors.error),
                                  const SizedBox(height: 8),
                                  Text('Failed to load image', style: TextStyle(color: colors.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Previous Navigation Arrow
                      if (_imageSiblings.length > 1)
                        Positioned(
                          left: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: InkWell(
                              onTap: _goToPrevious,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.cardSurface.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.borderSubtle),
                                ),
                                child: Icon(Icons.chevron_left, color: colors.textPrimary),
                              ),
                            ),
                          ),
                        ),

                      // Next Navigation Arrow
                      if (_imageSiblings.length > 1)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: InkWell(
                              onTap: _goToNext,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.cardSurface.withOpacity(0.85),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.borderSubtle),
                                ),
                                child: Icon(Icons.chevron_right, color: colors.textPrimary),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. Windows Photos Bottom Toolbar
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.container.withOpacity(0.95),
                    border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Zoom Out
                      _buildToolbarBtn(
                        icon: Icons.zoom_out,
                        tooltip: 'Zoom Out',
                        onTap: _zoomOut,
                        colors: colors,
                      ),
                      // Zoom text & reset
                      InkWell(
                        onTap: _resetZoom,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            '${(_zoomLevel * 100).toInt()}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ),
                      ),
                      // Zoom In
                      _buildToolbarBtn(
                        icon: Icons.zoom_in,
                        tooltip: 'Zoom In',
                        onTap: _zoomIn,
                        colors: colors,
                      ),
                      const SizedBox(width: 8),
                      Container(height: 18, width: 1, color: colors.borderSubtle),
                      const SizedBox(width: 8),
                      // Rotate
                      _buildToolbarBtn(
                        icon: Icons.rotate_right,
                        tooltip: 'Rotate 90°',
                        onTap: _rotateClockwise,
                        colors: colors,
                      ),
                      // Reset to Actual Size
                      _buildToolbarBtn(
                        icon: Icons.fit_screen,
                        tooltip: 'Fit to Window',
                        onTap: _resetZoom,
                        colors: colors,
                      ),
                      // Share
                      _buildToolbarBtn(
                        icon: Icons.share_outlined,
                        tooltip: 'Share',
                        onTap: () => FileService.shareFiles([_currentItem.path]),
                        colors: colors,
                      ),
                      // Delete
                      _buildToolbarBtn(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete Photo',
                        onTap: _deleteCurrentPhoto,
                        colors: colors,
                        iconColor: colors.error,
                      ),
                      const Spacer(),
                      // Counter
                      Text(
                        '${_currentIndex + 1} of ${_imageSiblings.length}',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required FluentColors colors,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 17, color: iconColor ?? colors.textPrimary),
        ),
      ),
    );
  }
}
