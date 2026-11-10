import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../models/file_item.dart';
import '../../services/file_service.dart';
import '../../theme/fluent_theme.dart';
import 'windows_media_header.dart';

class WindowsAudioPlayer extends StatefulWidget {
  final FileItem item;
  final List<FileItem>? siblingItems;

  const WindowsAudioPlayer({
    super.key,
    required this.item,
    this.siblingItems,
  });

  static void show(BuildContext context, FileItem item, [List<FileItem>? siblings]) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.60),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WindowsAudioPlayer(item: item, siblingItems: siblings);
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
  State<WindowsAudioPlayer> createState() => _WindowsAudioPlayerState();
}

class _WindowsAudioPlayerState extends State<WindowsAudioPlayer> with SingleTickerProviderStateMixin {
  late AudioPlayer _player;
  late FileItem _currentItem;
  late List<FileItem> _playlist;
  int _currentIndex = 0;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final double _volume = 1.0;
  bool _isShuffle = false;
  bool _isRepeat = false;

  late AnimationController _discAnim;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _discAnim = AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _initPlaylist();
    _initAudioPlayer();
  }

  void _initPlaylist() {
    if (widget.siblingItems != null && widget.siblingItems!.isNotEmpty) {
      _playlist = widget.siblingItems!.where((f) => f.isAudio).toList();
    } else {
      try {
        final parentDir = Directory(p.dirname(_currentItem.path));
        if (parentDir.existsSync()) {
          _playlist = parentDir
              .listSync(followLinks: false)
              .whereType<File>()
              .map((f) => FileItem.fromFileSystemEntity(f))
              .where((f) => f.isAudio)
              .toList();
        } else {
          _playlist = [_currentItem];
        }
      } catch (_) {
        _playlist = [_currentItem];
      }
    }
    _currentIndex = _playlist.indexWhere((f) => f.path == _currentItem.path);
    if (_currentIndex < 0) _currentIndex = 0;
  }

  Future<void> _initAudioPlayer() async {
    _player = AudioPlayer();

    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
        if (state == PlayerState.playing) {
          _discAnim.repeat();
        } else {
          _discAnim.stop();
        }
      }
    });

    _compSub = _player.onPlayerComplete.listen((_) {
      if (_isRepeat) {
        _playCurrentTrack();
      } else {
        if (_currentIndex < _playlist.length - 1) {
          _playNext();
        } else {
          // Playlist finished with repeat OFF: Stop playback and reset to start
          if (mounted) {
            setState(() {
              _position = Duration.zero;
              _playerState = PlayerState.completed;
              _discAnim.stop();
            });
          }
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });

    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    try {
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(DeviceFileSource(_currentItem.path));
    } catch (_) {}
  }

  void _playPrevious() {
    if (_playlist.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
      _currentItem = _playlist[_currentIndex];
    });
    _playCurrentTrack();
  }

  void _playNext() {
    if (_playlist.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
      _currentItem = _playlist[_currentIndex];
    });
    _playCurrentTrack();
  }

  void _togglePlayPause() {
    if (_playerState == PlayerState.playing) {
      _player.pause();
    } else {
      _player.resume();
    }
  }

  void _seekRelative(Duration delta) {
    final newPos = _position + delta;
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _duration ? _duration : newPos);
    _player.seek(clamped);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _player.dispose();
    _discAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;
    final isPlaying = _playerState == PlayerState.playing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          width: size.width > 600 ? 520 : size.width * 0.92,
          height: 480,
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.borderSubtle, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Windows Media Player Title Bar
              WindowsMediaHeader(
                title: _currentItem.name,
                icon: Icons.music_note_outlined,
                onClose: () => Navigator.of(context).pop(),
                onMinimize: () => Navigator.of(context).pop(),
                onOpenWith: () {
                  FileService.openFile(_currentItem.path, useChooser: true);
                },
              ),

              // 2. Windows 11 Fluent Center Disc & Artwork
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: colors.canvas,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Spinning Vinyl Vinyl Disc with Glow
                      RotationTransition(
                        turns: _discAnim,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                colors.cardSurface,
                                Colors.black87,
                                colors.primary.withOpacity(0.8),
                                Colors.black,
                              ],
                              stops: const [0.2, 0.4, 0.7, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(isPlaying ? 0.35 : 0.1),
                                blurRadius: isPlaying ? 24 : 10,
                                spreadRadius: isPlaying ? 3 : 0,
                              ),
                            ],
                            border: Border.all(color: colors.borderSubtle, width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary,
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white, size: 26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Track Title & Album / Folder Name
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          p.basenameWithoutExtension(_currentItem.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.basename(p.dirname(_currentItem.path))} • ${_currentItem.formatSize()}',
                        style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Playback Scrub Bar & Time
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                color: colors.cardSurface,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: colors.primary,
                        inactiveTrackColor: colors.borderSubtle,
                        thumbColor: colors.primary,
                      ),
                      child: Slider(
                        value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                        min: 0.0,
                        max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                        onChanged: (val) {
                          _player.seek(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                          Text(
                            '${_currentIndex + 1}/${_playlist.length}',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: colors.textMuted),
                          ),
                          Text(_formatDuration(_duration), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Windows Media Controls Bar
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.container,
                  border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(Icons.shuffle, size: 18, color: _isShuffle ? colors.primary : colors.textMuted),
                      tooltip: 'Shuffle',
                      onPressed: () => setState(() => _isShuffle = !_isShuffle),
                    ),
                    // Previous Track
                    IconButton(
                      icon: Icon(Icons.skip_previous, size: 22, color: colors.textPrimary),
                      tooltip: 'Previous',
                      onPressed: _playPrevious,
                    ),
                    // Replay 10s
                    IconButton(
                      icon: Icon(Icons.replay_10, size: 20, color: colors.textSecondary),
                      tooltip: 'Replay 10s',
                      onPressed: () => _seekRelative(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 4),
                    // Play / Pause Circle Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: colors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 24),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Skip 10s
                    IconButton(
                      icon: Icon(Icons.forward_10, size: 20, color: colors.textSecondary),
                      tooltip: 'Skip 10s',
                      onPressed: () => _seekRelative(const Duration(seconds: 10)),
                    ),
                    // Next Track
                    IconButton(
                      icon: Icon(Icons.skip_next, size: 22, color: colors.textPrimary),
                      tooltip: 'Next',
                      onPressed: _playNext,
                    ),
                    // Repeat
                    IconButton(
                      icon: Icon(Icons.repeat, size: 18, color: _isRepeat ? colors.primary : colors.textMuted),
                      tooltip: 'Repeat',
                      onPressed: () => setState(() => _isRepeat = !_isRepeat),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
