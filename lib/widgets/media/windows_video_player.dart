import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import '../../models/file_item.dart';
import '../../services/file_service.dart';
import '../../theme/fluent_theme.dart';
import '../fluent_subtitle_picker.dart';
import 'windows_media_header.dart';

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleCue({required this.start, required this.end, required this.text});
}

class WindowsVideoPlayer extends StatefulWidget {
  final FileItem item;

  const WindowsVideoPlayer({super.key, required this.item});

  static void show(BuildContext context, FileItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.70),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WindowsVideoPlayer(item: item);
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
  State<WindowsVideoPlayer> createState() => _WindowsVideoPlayerState();
}

class _WindowsVideoPlayerState extends State<WindowsVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isMuted = false;

  List<SubtitleCue> _subtitles = [];
  String _activeSubtitleText = '';
  String? _subtitleFileName;
  bool _subtitlesEnabled = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.item.path));
      await _controller.initialize();
      _controller.addListener(_onPlayerTick);
      _controller.setVolume(_volume);
      _controller.play();

      _checkForAutoSubtitles();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onPlayerTick() {
    if (!mounted || !_isInitialized) return;

    if (_subtitlesEnabled && _subtitles.isNotEmpty) {
      final pos = _controller.value.position;
      String currentText = '';
      for (final cue in _subtitles) {
        if (pos >= cue.start && pos <= cue.end) {
          currentText = cue.text;
          break;
        }
      }
      if (currentText != _activeSubtitleText) {
        setState(() {
          _activeSubtitleText = currentText;
        });
      }
    } else if (_activeSubtitleText.isNotEmpty) {
      setState(() {
        _activeSubtitleText = '';
      });
    }

    // Only rebuild controls when they are actively displayed
    if (_showControls) {
      setState(() {});
    }
  }

  void _checkForAutoSubtitles() {
    try {
      final base = p.withoutExtension(widget.item.path);
      final srtFile = File('$base.srt');
      final vttFile = File('$base.vtt');

      if (srtFile.existsSync()) {
        _loadSubtitleFile(srtFile);
      } else if (vttFile.existsSync()) {
        _loadSubtitleFile(vttFile);
      }
    } catch (_) {}
  }

  Future<void> _loadSubtitleFile(File file) async {
    try {
      String content;
      try {
        content = await file.readAsString();
      } catch (_) {
        final bytes = await file.readAsBytes();
        content = String.fromCharCodes(bytes);
      }
      final cues = _parseSrt(content);
      if (mounted) {
        setState(() {
          _subtitles = cues;
          _subtitleFileName = p.basename(file.path);
          _subtitlesEnabled = true;
        });
      }
    } catch (_) {}
  }

  List<SubtitleCue> _parseSrt(String text) {
    final cues = <SubtitleCue>[];
    final blocks = text.replaceAll('\r\n', '\n').split('\n\n');

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      String timeLine = lines[0].contains('-->') ? lines[0] : (lines.length > 1 && lines[1].contains('-->') ? lines[1] : '');
      if (timeLine.isEmpty) continue;

      final arrowSplit = timeLine.split('-->');
      if (arrowSplit.length != 2) continue;

      final startDuration = _parseTimecode(arrowSplit[0].trim());
      final endDuration = _parseTimecode(arrowSplit[1].trim());

      final textLines = lines.skip(lines.indexOf(timeLine) + 1).join('\n');

      if (startDuration != null && endDuration != null) {
        cues.add(SubtitleCue(start: startDuration, end: endDuration, text: textLines));
      }
    }
    return cues;
  }

  Duration? _parseTimecode(String timeStr) {
    try {
      // 00:01:20,000 or 00:01:20.000
      final clean = timeStr.replaceAll(',', '.');
      final parts = clean.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secParts = parts[2].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1 ? int.parse(secParts[1].padRight(3, '0').substring(0, 3)) : 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
      }
    } catch (_) {}
    return null;
  }

  void _showSubtitlePicker() {
    final parentDir = Directory(p.dirname(widget.item.path));
    final subFiles = <File>[];
    try {
      subFiles.addAll(
        parentDir
            .listSync(followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.srt') || f.path.endsWith('.vtt')),
      );
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subtle drag handle
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colors.textMuted.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text('Subtitles / Captions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enable subtitles', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                          value: _subtitlesEnabled,
                          activeColor: colors.primary,
                          onChanged: (val) {
                            Navigator.pop(ctx);
                            setState(() => _subtitlesEnabled = val);
                          },
                        ),
                        const SizedBox(height: 6),
                        // Manual Subtitle File Selector Button (Built-in Fluent Picker)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final chosenFile = await FluentSubtitlePicker.show(
                                context,
                                initialPath: p.dirname(widget.item.path),
                              );
                              if (chosenFile != null && mounted) {
                                _loadSubtitleFile(chosenFile);
                                setState(() => _subtitlesEnabled = true);
                              }
                            },
                            icon: const Icon(Icons.file_open_outlined, size: 16),
                            label: const Text('Browse Subtitle File...', style: TextStyle(fontSize: 12.5)),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        if (_subtitleFileName != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 14, color: colors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Active: $_subtitleFileName',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                        ],
                        if (subFiles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('No other .srt or .vtt subtitles found in this folder.', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                          )
                        else
                          ...subFiles.map((file) {
                            final name = p.basename(file.path);
                            final isSelected = _subtitleFileName == name;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.subtitles_outlined, color: isSelected ? colors.primary : colors.textSecondary),
                              title: Text(name, style: TextStyle(fontSize: 12.5, color: isSelected ? colors.primary : colors.textPrimary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                              onTap: () {
                                Navigator.pop(ctx);
                                _loadSubtitleFile(file);
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors.textMuted.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Playback Speed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      final isSelected = _playbackSpeed == speed;
                      return ChoiceChip(
                        label: Text('${speed}x'),
                        selected: isSelected,
                        selectedColor: colors.primary.withOpacity(0.2),
                        onSelected: (val) {
                          Navigator.pop(ctx);
                          setState(() {
                            _playbackSpeed = speed;
                            _controller.setPlaybackSpeed(speed);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
      } else {
        _controller.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(Duration delta) {
    final newPos = _controller.value.position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _controller.value.duration ? _controller.value.duration : newPos);
    _controller.seekTo(clamped);
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
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

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_onPlayerTick);
      _controller.dispose();
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    final usableWidth = size.width - (_isFullscreen ? 0 : padding.horizontal);
    final usableHeight = size.height - (_isFullscreen ? 0 : padding.vertical);

    final containerWidth = _isFullscreen ? size.width : (usableWidth > 960 ? 920.0 : usableWidth * 0.94);
    final containerHeight = _isFullscreen ? size.height : (usableHeight > 800 ? 680.0 : usableHeight * 0.88);

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
              color: Colors.black,
              borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 8),
              border: Border.all(color: colors.borderSubtle, width: _isFullscreen ? 0 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _hasError
                ? _buildErrorView(colors)
                : !_isInitialized
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _showControls = !_showControls);
                          if (_showControls && _controller.value.isPlaying) {
                            _startHideTimer();
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 0. Solid Black Backdrop to capture all clicks around letterboxed video
                            Container(color: Colors.black),

                            // 1. Video Canvas
                            Center(
                              child: AspectRatio(
                                aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
                                child: VideoPlayer(_controller),
                              ),
                            ),

                            // 2. Subtitle Overlay
                            if (_subtitlesEnabled && _activeSubtitleText.isNotEmpty)
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: _showControls ? 85 : 35,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _activeSubtitleText,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 3. Top Windows Media Player Header (fades out when controls hide)
                            if (_showControls)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: SafeArea(
                                  bottom: false,
                                  child: WindowsMediaHeader(
                                    title: widget.item.name,
                                    icon: Icons.video_file_outlined,
                                    isFullscreen: _isFullscreen,
                                    onClose: () {
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
                                      Navigator.of(context).pop();
                                    },
                                    onMinimize: () {
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
                                      Navigator.of(context).pop();
                                    },
                                    onToggleFullscreen: _toggleFullscreen,
                                    onOpenWith: () {
                                      FileService.openFile(widget.item.path, useChooser: true);
                                    },
                                    extraActions: [
                                      IconButton(
                                        icon: Icon(
                                          _subtitlesEnabled && _subtitles.isNotEmpty ? Icons.subtitles : Icons.subtitles_outlined,
                                          size: 16,
                                          color: _subtitlesEnabled && _subtitles.isNotEmpty ? colors.primary : colors.textSecondary,
                                        ),
                                        tooltip: 'Subtitles',
                                        onPressed: _showSubtitlePicker,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.speed, size: 16),
                                        tooltip: 'Playback Speed (${_playbackSpeed}x)',
                                        onPressed: _showSpeedPicker,
                                        color: colors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // 4. Center Double-Tap Seek Gestures & Big Play/Pause indicator
                            if (_showControls)
                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      iconSize: 36,
                                      icon: const Icon(Icons.replay_10, color: Colors.white70),
                                      onPressed: () => _seekRelative(const Duration(seconds: -10)),
                                    ),
                                    const SizedBox(width: 24),
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        iconSize: 52,
                                        icon: Icon(
                                          _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                          color: Colors.white,
                                        ),
                                        onPressed: _togglePlayPause,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    IconButton(
                                      iconSize: 36,
                                      icon: const Icon(Icons.forward_10, color: Colors.white70),
                                      onPressed: () => _seekRelative(const Duration(seconds: 10)),
                                    ),
                                  ],
                                ),
                              ),

                            // 5. Windows Media Player Bottom Ribbon Controls
                            if (_showControls)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: SafeArea(
                                  top: false,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.85),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Progress Scrub Slider
                                        SliderTheme(
                                          data: SliderThemeData(
                                            trackHeight: 3.5,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                            activeTrackColor: colors.primary,
                                            inactiveTrackColor: Colors.white24,
                                            thumbColor: colors.primary,
                                          ),
                                          child: Slider(
                                            value: _controller.value.position.inMilliseconds
                                                .clamp(0, _controller.value.duration.inMilliseconds)
                                                .toDouble(),
                                            min: 0.0,
                                            max: _controller.value.duration.inMilliseconds.toDouble(),
                                            onChanged: (val) {
                                              _controller.seekTo(Duration(milliseconds: val.toInt()));
                                            },
                                          ),
                                        ),

                                        // Controls & Timers Row
                                        Row(
                                          children: [
                                            // Play / Pause
                                            InkWell(
                                              onTap: _togglePlayPause,
                                              child: Icon(
                                                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                                size: 22,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Timestamp
                                            Text(
                                              '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontFamily: 'monospace'),
                                            ),
                                            const Spacer(),
                                            // Volume Mute Button
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _isMuted = !_isMuted;
                                                  _controller.setVolume(_isMuted ? 0.0 : _volume);
                                                });
                                              },
                                              child: Icon(
                                                _isMuted ? Icons.volume_off : (_volume > 0.5 ? Icons.volume_up : Icons.volume_down),
                                                size: 19,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            // Volume Slider
                                            SizedBox(
                                              width: 80,
                                              child: SliderTheme(
                                                data: SliderThemeData(
                                                  trackHeight: 2.5,
                                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                                  overlayShape: SliderComponentShape.noOverlay,
                                                  activeTrackColor: Colors.white,
                                                  inactiveTrackColor: Colors.white24,
                                                  thumbColor: Colors.white,
                                                ),
                                                child: Slider(
                                                  value: _isMuted ? 0.0 : _volume,
                                                  min: 0.0,
                                                  max: 1.0,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _volume = val;
                                                      _isMuted = val == 0.0;
                                                      _controller.setVolume(_volume);
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Fullscreen Button
                                            InkWell(
                                              onTap: _toggleFullscreen,
                                              child: Icon(
                                                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                                                size: 22,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildErrorView(FluentColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: colors.error),
        const SizedBox(height: 12),
        const Text('Cannot play this video file', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(_errorMessage, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () {
            Navigator.pop(context);
            FileService.openFile(widget.item.path, useChooser: true);
          },
          child: const Text('Open with external player'),
        ),
      ],
    );
  }
}
