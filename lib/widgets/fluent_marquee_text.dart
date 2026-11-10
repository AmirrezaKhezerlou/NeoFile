import 'dart:async';
import 'package:flutter/material.dart';

class FluentMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration pauseDuration;
  final double velocity; // pixels per second

  const FluentMarqueeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.pauseDuration = const Duration(seconds: 2),
    this.velocity = 28.0,
  });

  @override
  State<FluentMarqueeText> createState() => _FluentMarqueeTextState();
}

class _FluentMarqueeTextState extends State<FluentMarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isDisposed = false;
  bool _scrollingForward = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  @override
  void didUpdateWidget(covariant FluentMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopAnimation();
      _scrollingForward = true;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
    }
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
  }

  void _startAnimation() {
    if (_isDisposed || !mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // Text fits inside parent constraints

    _timer?.cancel();
    _timer = Timer(widget.pauseDuration, () async {
      if (_isDisposed || !mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      final target = _scrollingForward ? max : 0.0;
      final distance = (target - _scrollController.offset).abs();
      final durationMs = (distance / widget.velocity * 1000).round();

      try {
        await _scrollController.animateTo(
          target,
          duration: Duration(milliseconds: durationMs.clamp(500, 15000)),
          curve: Curves.linear,
        );
      } catch (_) {}

      if (_isDisposed || !mounted) return;
      _scrollingForward = !_scrollingForward;
      _startAnimation();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopAnimation();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);

        // If the text naturally fits inside bounds, avoid horizontal scrollview and animation tickers
        if (tp.width <= constraints.maxWidth) {
          _stopAnimation();
          return Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              widget.text,
              style: widget.style,
              textAlign: widget.textAlign,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}
