import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../../models/file_item.dart';
import '../../services/file_service.dart';
import '../../theme/fluent_theme.dart';
import '../file_properties_sheet.dart';
import 'windows_media_header.dart';

class WindowsPdfViewer extends StatefulWidget {
  final FileItem item;

  const WindowsPdfViewer({super.key, required this.item});

  static void show(BuildContext context, FileItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.65),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WindowsPdfViewer(item: item);
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
  State<WindowsPdfViewer> createState() => _WindowsPdfViewerState();
}

class _WindowsPdfViewerState extends State<WindowsPdfViewer> {
  PDFViewController? _pdfViewController;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullscreen = false;
  bool _swipeHorizontal = false;

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
    super.dispose();
  }

  Future<void> _jumpToPageDialog() async {
    final colors = FluentColors.of(context);
    final controller = TextEditingController(text: '${_currentPage + 1}');

    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Go to Page', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter page number (1 to $_totalPages):', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
              final page = int.tryParse(controller.text.trim());
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(ctx, page - 1);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (target != null && _pdfViewController != null) {
      _pdfViewController!.setPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final usableWidth = size.width - (_isFullscreen ? 0 : padding.horizontal);
    final usableHeight = size.height - (_isFullscreen ? 0 : padding.vertical);

    final containerWidth = _isFullscreen ? size.width : (usableWidth > 920 ? 880.0 : usableWidth * 0.95);
    final containerHeight = _isFullscreen ? size.height : (usableHeight > 800 ? 720.0 : usableHeight * 0.92);

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
                // 1. Windows Reader Header
                WindowsMediaHeader(
                  title: _totalPages > 0
                      ? '${widget.item.name} (${_currentPage + 1}/$_totalPages)'
                      : widget.item.name,
                  icon: Icons.picture_as_pdf,
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
                    FileService.openFile(widget.item.path, useChooser: true);
                  },
                  extraActions: [
                    IconButton(
                      icon: Icon(
                        _swipeHorizontal ? Icons.view_column_outlined : Icons.view_stream_outlined,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      tooltip: _swipeHorizontal ? 'Vertical scroll' : 'Horizontal scroll',
                      onPressed: () {
                        setState(() => _swipeHorizontal = !_swipeHorizontal);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      tooltip: 'Document Properties',
                      onPressed: () => FilePropertiesSheet.show(context, widget.item),
                      color: colors.textSecondary,
                    ),
                  ],
                ),

                // 2. Main PDF Canvas
                Expanded(
                  child: Stack(
                    children: [
                      if (_hasError)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: colors.error),
                              const SizedBox(height: 10),
                              const Text('Failed to open PDF document', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(_errorMessage, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                              const SizedBox(height: 14),
                              FilledButton.tonal(
                                onPressed: () {
                                  Navigator.pop(context);
                                  FileService.openFile(widget.item.path, useChooser: true);
                                },
                                child: const Text('Open with external viewer'),
                              ),
                            ],
                          ),
                        )
                      else
                        PDFView(
                          filePath: widget.item.path,
                          enableSwipe: true,
                          swipeHorizontal: _swipeHorizontal,
                          autoSpacing: true,
                          pageFling: true,
                          pageSnap: true,
                          defaultPage: _currentPage,
                          fitPolicy: FitPolicy.BOTH,
                          preventLinkNavigation: false,
                          backgroundColor: Colors.grey.shade900,
                          onRender: (pages) {
                            setState(() {
                              _totalPages = pages ?? 0;
                              _isReady = true;
                            });
                          },
                          onError: (error) {
                            setState(() {
                              _hasError = true;
                              _errorMessage = error.toString();
                            });
                          },
                          onPageError: (page, error) {
                            setState(() {
                              _hasError = true;
                              _errorMessage = '$page: ${error.toString()}';
                            });
                          },
                          onViewCreated: (PDFViewController controller) {
                            _pdfViewController = controller;
                          },
                          onPageChanged: (int? page, int? total) {
                            if (page != null) {
                              setState(() {
                                _currentPage = page;
                                if (total != null) _totalPages = total;
                              });
                            }
                          },
                        ),

                      if (!_isReady && !_hasError)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),

                // 3. Windows Reader Bottom Navigation Bar
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.container.withOpacity(0.95),
                    border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
                  ),
                  child: Row(
                    children: [
                      // Previous Page
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Previous Page',
                        onPressed: _currentPage > 0 && _pdfViewController != null
                            ? () => _pdfViewController!.setPage(_currentPage - 1)
                            : null,
                      ),

                      // Page Indicator Clickable (Jump to Page)
                      InkWell(
                        onTap: _totalPages > 1 ? _jumpToPageDialog : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            _totalPages > 0 ? 'Page ${_currentPage + 1} of $_totalPages' : 'Loading...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),

                      // Next Page
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Next Page',
                        onPressed: _currentPage < _totalPages - 1 && _pdfViewController != null
                            ? () => _pdfViewController!.setPage(_currentPage + 1)
                            : null,
                      ),

                      const Spacer(),

                      // Share Document
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 17),
                        tooltip: 'Share',
                        onPressed: () => FileService.shareFiles([widget.item.path]),
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
}
