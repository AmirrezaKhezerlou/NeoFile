import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../theme/fluent_theme.dart';

class WindowsNotepadScreen extends StatefulWidget {
  final String? filePath;
  final FileItem? fileItem;

  const WindowsNotepadScreen({
    super.key,
    this.filePath,
    this.fileItem,
  });

  static Future<void> open(BuildContext context, {String? filePath, FileItem? fileItem}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WindowsNotepadScreen(filePath: filePath, fileItem: fileItem),
      ),
    );
  }

  @override
  State<WindowsNotepadScreen> createState() => _WindowsNotepadScreenState();
}

class _WindowsNotepadScreenState extends State<WindowsNotepadScreen> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  String? _currentPath;
  String _fileName = 'Untitled.txt';
  bool _isDirty = false;
  bool _isLoading = true;
  String _originalContent = '';

  // View Options
  bool _wordWrap = true;
  bool _useMonospace = true;
  double _fontSize = 14.0;
  static const double _defaultFontSize = 14.0;

  // Cursor Tracking
  int _currentLine = 1;
  int _currentCol = 1;
  int _totalLines = 1;
  int _totalChars = 0;
  String _lineEnding = 'Unix (LF)';

  // Find & Replace
  bool _showFindBar = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  List<int> _findMatches = [];
  int _currentMatchIndex = -1;

  // Undo / Redo history
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  bool _isUndoRedoAction = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.filePath ?? widget.fileItem?.path;
    _fileName = _currentPath != null ? p.basename(_currentPath!) : 'Untitled.txt';
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _controller.addListener(_handleTextChange);
    _loadFile();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    if (_currentPath != null && File(_currentPath!).existsSync()) {
      try {
        final bytes = await File(_currentPath!).readAsBytes();
        String text;
        try {
          text = utf8.decode(bytes);
        } catch (_) {
          text = latin1.decode(bytes);
        }

        if (text.contains('\r\n')) {
          _lineEnding = 'Windows (CRLF)';
        } else {
          _lineEnding = 'Unix (LF)';
        }

        _originalContent = text;
        _isUndoRedoAction = true;
        _controller.text = text;
        _isUndoRedoAction = false;
        _undoStack.clear();
        _undoStack.add(text);
        _redoStack.clear();
        _isDirty = false;
      } catch (e) {
        _originalContent = '';
        _controller.text = '// Error reading file: $e';
      }
    } else {
      _originalContent = '';
      _undoStack.add('');
      _isDirty = false;
    }

    _updateCursorAndStats();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _handleTextChange() {
    if (_isUndoRedoAction) return;

    final currentText = _controller.text;
    final isModified = currentText != _originalContent;

    if (_undoStack.isEmpty || _undoStack.last != currentText) {
      _undoStack.add(currentText);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
    }

    _updateCursorAndStats();
    if (_showFindBar && _findController.text.isNotEmpty) {
      _executeFind(_findController.text);
    }

    if (isModified != _isDirty) {
      setState(() {
        _isDirty = isModified;
      });
    }
  }

  void _updateCursorAndStats() {
    final text = _controller.text;
    final selection = _controller.selection;

    int line = 1;
    int col = 1;
    final cursorOffset = selection.baseOffset.clamp(0, text.length);

    for (int i = 0; i < cursorOffset; i++) {
      if (text[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }

    final totalLines = text.split('\n').length;
    final totalChars = text.length;

    if (mounted) {
      setState(() {
        _currentLine = line;
        _currentCol = col;
        _totalLines = totalLines;
        _totalChars = totalChars;
      });
    }
  }

  void _undo() {
    if (_undoStack.length > 1) {
      final current = _undoStack.removeLast();
      _redoStack.add(current);
      final prev = _undoStack.last;
      _isUndoRedoAction = true;
      _controller.text = prev;
      _isUndoRedoAction = false;
      _isDirty = prev != _originalContent;
      _updateCursorAndStats();
      setState(() {});
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      final next = _redoStack.removeLast();
      _undoStack.add(next);
      _isUndoRedoAction = true;
      _controller.text = next;
      _isUndoRedoAction = false;
      _isDirty = next != _originalContent;
      _updateCursorAndStats();
      setState(() {});
    }
  }

  Future<bool> _saveFile() async {
    if (_currentPath == null) {
      return await _saveFileAs();
    }

    try {
      final file = File(_currentPath!);
      await file.writeAsString(_controller.text, encoding: utf8);
      setState(() {
        _originalContent = _controller.text;
        _isDirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $_fileName'), duration: const Duration(seconds: 1)),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      return false;
    }
  }

  Future<bool> _saveFileAs() async {
    final colors = FluentColors.of(context);
    final nameController = TextEditingController(text: _fileName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Save As', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: colors.textPrimary),
          decoration: InputDecoration(
            labelText: 'File Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      String saveDir = '/storage/emulated/0/Download';
      if (_currentPath != null) {
        saveDir = p.dirname(_currentPath!);
      }
      final newPath = p.join(saveDir, newName);
      try {
        final file = File(newPath);
        await file.writeAsString(_controller.text, encoding: utf8);
        setState(() {
          _currentPath = newPath;
          _fileName = newName;
          _originalContent = _controller.text;
          _isDirty = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved to $newPath')),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e')),
          );
        }
      }
    }
    return false;
  }

  void _insertDateTime() {
    final formatted = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);

    final newText = text.replaceRange(start, end, formatted);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + formatted.length),
    );
  }

  void _executeFind(String query) {
    if (query.isEmpty) {
      setState(() {
        _findMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = _controller.text.toLowerCase();
    final q = query.toLowerCase();
    final matches = <int>[];
    int start = 0;
    while (true) {
      final index = text.indexOf(q, start);
      if (index == -1) break;
      matches.add(index);
      start = index + q.length;
    }

    setState(() {
      _findMatches = matches;
      if (matches.isNotEmpty) {
        _currentMatchIndex = 0;
        _highlightMatch(matches.first, query.length);
      } else {
        _currentMatchIndex = -1;
      }
    });
  }

  void _highlightMatch(int start, int length) {
    _controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + length,
    );
  }

  void _nextMatch() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _findMatches.length;
      _highlightMatch(_findMatches[_currentMatchIndex], _findController.text.length);
    });
  }

  void _prevMatch() {
    if (_findMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _findMatches.length) % _findMatches.length;
      _highlightMatch(_findMatches[_currentMatchIndex], _findController.text.length);
    });
  }

  void _replaceCurrent() {
    if (_currentMatchIndex == -1 || _findMatches.isEmpty) return;
    final query = _findController.text;
    final replacement = _replaceController.text;
    final matchPos = _findMatches[_currentMatchIndex];

    final text = _controller.text;
    final newText = text.replaceRange(matchPos, matchPos + query.length, replacement);
    _controller.text = newText;
    _executeFind(query);
  }

  void _replaceAll() {
    final query = _findController.text;
    final replacement = _replaceController.text;
    if (query.isEmpty) return;

    final text = _controller.text;
    final newText = text.replaceAll(query, replacement);
    _controller.text = newText;
    _executeFind(query);
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;

    final colors = FluentColors.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Notepad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
        content: Text(
          'Do you want to save changes to $_fileName?',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'dont_save'),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("Don't Save"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      return await _saveFile();
    } else if (result == 'dont_save') {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: colors.cardSurface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Row(
            children: [
              Icon(Icons.edit_note_outlined, size: 22, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_isDirty ? '*' : ''}$_fileName - Notepad',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.save_outlined, color: _isDirty ? colors.primary : colors.textMuted),
              tooltip: 'Save',
              onPressed: _saveFile,
            ),
            IconButton(
              icon: Icon(Icons.search, color: _showFindBar ? colors.primary : colors.textPrimary),
              tooltip: 'Find & Replace',
              onPressed: () {
                setState(() {
                  _showFindBar = !_showFindBar;
                  if (_showFindBar) {
                    _executeFind(_findController.text);
                  }
                });
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
              color: colors.cardSurface,
              onSelected: (val) {
                switch (val) {
                  case 'save_as':
                    _saveFileAs();
                    break;
                  case 'undo':
                    _undo();
                    break;
                  case 'redo':
                    _redo();
                    break;
                  case 'word_wrap':
                    setState(() => _wordWrap = !_wordWrap);
                    break;
                  case 'monospace':
                    setState(() => _useMonospace = !_useMonospace);
                    break;
                  case 'zoom_in':
                    setState(() => _fontSize = (_fontSize + 2).clamp(10.0, 32.0));
                    break;
                  case 'zoom_out':
                    setState(() => _fontSize = (_fontSize - 2).clamp(10.0, 32.0));
                    break;
                  case 'zoom_reset':
                    setState(() => _fontSize = _defaultFontSize);
                    break;
                  case 'date_time':
                    _insertDateTime();
                    break;
                  case 'clear':
                    _controller.clear();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                _buildMenuItem('save_as', Icons.save_as_outlined, 'Save As...', colors),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('undo', Icons.undo, 'Undo', colors, enabled: _undoStack.length > 1),
                _buildMenuItem('redo', Icons.redo, 'Redo', colors, enabled: _redoStack.isNotEmpty),
                _buildMenuItem('date_time', Icons.access_time, 'Time/Date (F5)', colors),
                const PopupMenuDivider(height: 1),
                CheckedPopupMenuItem<String>(
                  value: 'word_wrap',
                  checked: _wordWrap,
                  child: Text('Word Wrap', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'monospace',
                  checked: _useMonospace,
                  child: Text('Monospace Font', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                ),
                const PopupMenuDivider(height: 1),
                _buildMenuItem('zoom_in', Icons.zoom_in, 'Zoom In', colors),
                _buildMenuItem('zoom_out', Icons.zoom_out, 'Zoom Out', colors),
                _buildMenuItem('zoom_reset', Icons.restart_alt, 'Restore Default Zoom', colors),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: colors.borderSubtle, height: 1),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                children: [
                  // Find & Replace Banner
                  if (_showFindBar) _buildFindBar(colors),

                  // Text Editor Content
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: _wordWrap ? Axis.vertical : Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width,
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: _useMonospace ? 'monospace' : null,
                            fontSize: _fontSize,
                            height: 1.45,
                            color: colors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Status Bar (Classic Windows Notepad)
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colors.cardSurface,
                      border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Ln $_currentLine, Col $_currentCol',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '$_totalLines lines • $_totalChars chars',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        const Spacer(),
                        Text(
                          '${((_fontSize / _defaultFontSize) * 100).toInt()}%',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          _lineEnding,
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'UTF-8',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String title,
    FluentColors colors, {
    bool enabled = true,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 18, color: enabled ? colors.textPrimary : colors.textMuted.withOpacity(0.5)),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: enabled ? colors.textPrimary : colors.textMuted.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindBar(FluentColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.container,
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _findController,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Find in document...',
                      hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixText: _findMatches.isNotEmpty
                          ? '${_currentMatchIndex + 1}/${_findMatches.length}'
                          : (_findController.text.isNotEmpty ? '0/0' : ''),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onChanged: _executeFind,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: _prevMatch,
                tooltip: 'Previous match',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 18),
                onPressed: _nextMatch,
                tooltip: 'Next match',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showFindBar = false),
                tooltip: 'Close search',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _replaceController,
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Replace with...',
                      hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                      prefixIcon: const Icon(Icons.find_replace, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _replaceCurrent,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(60, 34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Replace', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 4),
              OutlinedButton(
                onPressed: _replaceAll,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(70, 34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Replace All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
