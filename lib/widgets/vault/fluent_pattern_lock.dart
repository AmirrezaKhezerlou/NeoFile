import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FluentPatternLock extends StatefulWidget {
  final ValueChanged<List<int>> onPatternComplete;
  final ValueChanged<List<int>>? onPatternChanged;
  final double dimension;
  final Color? activeColor;
  final Color? nodeColor;
  final Color? lineColor;
  final bool isError;

  const FluentPatternLock({
    super.key,
    required this.onPatternComplete,
    this.onPatternChanged,
    this.dimension = 280,
    this.activeColor,
    this.nodeColor,
    this.lineColor,
    this.isError = false,
  });

  @override
  State<FluentPatternLock> createState() => _FluentPatternLockState();
}

class _FluentPatternLockState extends State<FluentPatternLock> {
  final List<int> _selectedNodes = [];
  Offset? _currentTouchPoint;

  Offset _getNodeCenter(int index, double size) {
    final row = index ~/ 3;
    final col = index % 3;
    final step = size / 3;
    return Offset(
      col * step + step / 2,
      row * step + step / 2,
    );
  }

  int? _findHitNode(Offset point, double size) {
    const hitRadius = 36.0;
    for (int i = 0; i < 9; i++) {
      final center = _getNodeCenter(i, size);
      if ((point - center).distance <= hitRadius) {
        return i;
      }
    }
    return null;
  }

  void _handleTouch(Offset localPosition, double size) {
    final hit = _findHitNode(localPosition, size);
    if (hit != null && !_selectedNodes.contains(hit)) {
      setState(() {
        _selectedNodes.add(hit);
        _currentTouchPoint = localPosition;
      });
      HapticFeedback.lightImpact();
      widget.onPatternChanged?.call(List.unmodifiable(_selectedNodes));
    } else {
      setState(() {
        _currentTouchPoint = localPosition;
      });
    }
  }

  void _handleTouchEnd() {
    if (_selectedNodes.isNotEmpty) {
      widget.onPatternComplete(List.unmodifiable(_selectedNodes));
    }
    setState(() {
      _currentTouchPoint = null;
    });
  }

  void clear() {
    setState(() {
      _selectedNodes.clear();
      _currentTouchPoint = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.isError
        ? Colors.redAccent
        : (widget.activeColor ?? theme.colorScheme.primary);
    final nodeColor = widget.nodeColor ?? theme.colorScheme.onSurface.withOpacity(0.35);
    final lineColor = widget.lineColor ?? activeColor.withOpacity(0.6);

    return SizedBox(
      width: widget.dimension,
      height: widget.dimension,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          clear();
          _handleTouch(details.localPosition, widget.dimension);
        },
        onPanUpdate: (details) {
          _handleTouch(details.localPosition, widget.dimension);
        },
        onPanEnd: (_) => _handleTouchEnd(),
        onPanCancel: () => _handleTouchEnd(),
        child: CustomPaint(
          size: Size(widget.dimension, widget.dimension),
          painter: _PatternPainter(
            selectedNodes: _selectedNodes,
            currentTouchPoint: _currentTouchPoint,
            activeColor: activeColor,
            nodeColor: nodeColor,
            lineColor: lineColor,
            dimension: widget.dimension,
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> selectedNodes;
  final Offset? currentTouchPoint;
  final Color activeColor;
  final Color nodeColor;
  final Color lineColor;
  final double dimension;

  _PatternPainter({
    required this.selectedNodes,
    required this.currentTouchPoint,
    required this.activeColor,
    required this.nodeColor,
    required this.lineColor,
    required this.dimension,
  });

  Offset _getNodeCenter(int index) {
    final row = index ~/ 3;
    final col = index % 3;
    final step = dimension / 3;
    return Offset(
      col * step + step / 2,
      row * step + step / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw connecting lines between visited nodes
    if (selectedNodes.length > 1) {
      final path = Path();
      path.moveTo(_getNodeCenter(selectedNodes.first).dx, _getNodeCenter(selectedNodes.first).dy);
      for (int i = 1; i < selectedNodes.length; i++) {
        final pt = _getNodeCenter(selectedNodes[i]);
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Draw trailing line to current finger position
    if (selectedNodes.isNotEmpty && currentTouchPoint != null) {
      final lastCenter = _getNodeCenter(selectedNodes.last);
      canvas.drawLine(lastCenter, currentTouchPoint!, linePaint);
    }

    // Draw all 9 nodes
    for (int i = 0; i < 9; i++) {
      final center = _getNodeCenter(i);
      final isSelected = selectedNodes.contains(i);

      if (isSelected) {
        // Outer halo
        final haloPaint = Paint()
          ..color = activeColor.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 22, haloPaint);

        // Ring
        final ringPaint = Paint()
          ..color = activeColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, 14, ringPaint);

        // Inner solid dot
        final dotPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 6, dotPaint);
      } else {
        // Normal node dot
        final normalDotPaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 6, normalDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedNodes != selectedNodes ||
        oldDelegate.currentTouchPoint != currentTouchPoint ||
        oldDelegate.activeColor != activeColor;
  }
}
