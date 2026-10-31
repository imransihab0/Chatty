import 'dart:async';
import 'dart:math';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Telegram-style seekable waveform audio player with real playback.
///
/// Features:
/// - Real audio playback via just_audio
/// - Smooth interactive touch/drag scrubbing across waveform bars
/// - Play speed toggle: 1×, 1.5×, 2× (accessible before and during playback)
/// - Accurate drag tracking & haptic feedback ticks
/// - Animated play/pause icon with error handling
class AudioWaveformPlayer extends StatefulWidget {
  final bool isMe;
  final String audioUrl;
  final int durationMs;

  const AudioWaveformPlayer({
    super.key,
    required this.isMe,
    required this.audioUrl,
    this.durationMs = 0,
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer>
    with TickerProviderStateMixin {
  late final AudioPlayer _player;
  late final List<double> _barHeights;
  late final AnimationController _playPauseController;

  static const int _barCount = 28;
  static const List<double> _speeds = [1.0, 1.5, 2.0];
  int _speedIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _scrubFraction;
  int? _lastScrubIndex;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    // Generate deterministic waveform from URL hash
    final random = Random(widget.audioUrl.hashCode);
    _barHeights = List.generate(
      _barCount,
      (i) => 4.0 + random.nextDouble() * 20.0,
    );

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // Listen to position updates
    _player.positionStream.listen((pos) {
      if (mounted && _scrubFraction == null) {
        setState(() => _position = pos);
      }
    });

    // Listen to duration updates
    _player.durationStream.listen((dur) {
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }
    });

    // Listen to player state for auto-reset
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        _playPauseController.reverse();
        setState(() {
          _position = Duration.zero;
          _scrubFraction = null;
        });
      }
    });

    // Set initial duration from message metadata
    if (widget.durationMs > 0) {
      _duration = Duration(milliseconds: widget.durationMs);
    }
  }

  Future<void> _loadAndPlay() async {
    if (_hasError) return;
    setState(() => _isLoading = true);
    try {
      await _player.setUrl(widget.audioUrl);
      await _player.setSpeed(_speeds[_speedIndex]);
      if (_position > Duration.zero) {
        await _player.seek(_position);
      }
      await _player.play();
      if (!mounted) return;
      _playPauseController.forward();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _togglePlay() {
    AppHaptics.light();
    if (_hasError) return;

    if (_player.playing) {
      _player.pause();
      _playPauseController.reverse();
    } else {
      if (_player.duration == null) {
        // First play — need to load
        _loadAndPlay();
      } else {
        _player.play();
        _playPauseController.forward();
      }
    }
  }

  void _cycleSpeed() {
    AppHaptics.selection();
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
    });
    _player.setSpeed(_speeds[_speedIndex]);
  }

  void _seekToFraction(double fraction) {
    if (_duration.inMilliseconds == 0) return;
    final target = Duration(
      milliseconds: (fraction * _duration.inMilliseconds).round(),
    );
    if (_player.duration != null) {
      _player.seek(target);
    }
    setState(() {
      _position = target;
      _scrubFraction = null;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double actualProgress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final double progress = _scrubFraction ?? actualProgress;

    final activeBarColor =
        widget.isMe ? Colors.white : context.textPrimaryColor;
    final inactiveBarColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : context.borderColor;
    final textColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.8)
        : context.textSecondaryColor;

    // Show remaining time during playback, total duration when stopped
    final Duration displayDuration = _player.playing
        ? (_duration - _position)
        : _duration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      constraints: BoxConstraints(
        minWidth: 170,
        maxWidth: (MediaQuery.sizeOf(context).width * 0.65).clamp(180.0, 240.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Play / Pause / Loading Button with Telegram Mic Badge ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _isLoading ? null : _togglePlay,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.22)
                        : context.primarySoftColor,
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isMe
                                  ? Colors.white
                                  : context.textPrimaryColor,
                            ),
                          ),
                        )
                      : _hasError
                          ? const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.danger,
                              size: 22,
                            )
                          : AnimatedIcon(
                              icon: AnimatedIcons.play_pause,
                              progress: _playPauseController,
                              color: widget.isMe
                                  ? Colors.white
                                  : context.textPrimaryColor,
                              size: 24,
                            ),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? (context.isDark ? const Color(0xFF242426) : Colors.black)
                        : context.surfaceColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isMe
                          ? (context.isDark ? const Color(0xFF38383C) : Colors.black)
                          : context.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 9,
                    color: widget.isMe ? Colors.white : context.textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // ── Waveform + Duration + Speed Toggle ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seekable waveform with direct local coordinate mapping
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    const barWidth = 2.8;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () {
                        // Absorb long press so parent MessageCard options sheet does not fire during scrub
                      },
                      onTapDown: (details) {
                        AppHaptics.selection();
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        _seekToFraction(fraction);
                      },
                      onHorizontalDragStart: (details) {
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        _lastScrubIndex = (fraction * _barCount).floor();
                        setState(() => _scrubFraction = fraction);
                      },
                      onHorizontalDragUpdate: (details) {
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        final currentIdx = (fraction * _barCount).floor();
                        if (currentIdx != _lastScrubIndex) {
                          _lastScrubIndex = currentIdx;
                          AppHaptics.selection();
                        }
                        setState(() => _scrubFraction = fraction);
                      },
                      onHorizontalDragEnd: (_) {
                        _lastScrubIndex = null;
                        if (_scrubFraction != null) {
                          _seekToFraction(_scrubFraction!);
                        }
                      },
                      onHorizontalDragCancel: () {
                        _lastScrubIndex = null;
                        setState(() => _scrubFraction = null);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          height: 28,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(_barCount, (index) {
                              final barFraction = index / _barCount;
                              final isPast = progress > barFraction;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 70),
                                curve: Curves.easeOut,
                                width: barWidth,
                                height: _barHeights[index],
                                decoration: BoxDecoration(
                                  color: isPast
                                      ? activeBarColor
                                      : inactiveBarColor,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 3),

                // Duration + Speed toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(displayDuration),
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    // Speed toggle pill (1× / 1.5× / 2×)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _cycleSpeed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _speeds[_speedIndex] > 1.0
                                ? (widget.isMe
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : (context.isDark
                                        ? Colors.white
                                        : Colors.black))
                                : (widget.isMe
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : context.surfaceMutedColor),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.isMe
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : context.borderColor,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _speeds[_speedIndex] == 1.0
                                ? '1×'
                                : (_speeds[_speedIndex] == 2.0
                                    ? '2×'
                                    : '1.5×'),
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: _speeds[_speedIndex] > 1.0
                                  ? (widget.isMe
                                      ? Colors.white
                                      : (context.isDark
                                          ? Colors.black
                                          : Colors.white))
                                  : (widget.isMe
                                      ? Colors.white
                                      : context.textSecondaryColor),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
