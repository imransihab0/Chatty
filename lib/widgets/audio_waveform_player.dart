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
/// - Seekable waveform bars (tap/drag to seek)
/// - Play speed toggle: 1×, 1.5×, 2×
/// - Smooth progress animation synced to actual position
/// - Animated play/pause icon
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
      if (mounted) setState(() => _position = pos);
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
        setState(() => _position = Duration.zero);
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
      await _player.play();
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
    _player.seek(target);
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
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final activeBarColor =
        widget.isMe ? Colors.white : context.textPrimaryColor;
    final inactiveBarColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : context.borderColor;
    final textColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.8)
        : context.textMutedColor;

    // Show remaining time during playback, total duration when stopped
    final Duration displayDuration = _player.playing
        ? (_duration - _position)
        : _duration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      width: 240,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Play / Pause / Loading Button ──
          GestureDetector(
            onTap: _isLoading ? null : _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
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
          const SizedBox(width: 8),

          // ── Waveform + Duration ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seekable waveform
                GestureDetector(
                  onTapDown: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    // Calculate fraction relative to the waveform area
                    // (offset by play button width + spacing)
                    final barAreaWidth = box.size.width - 48 - 8;
                    final localX = details.localPosition.dx - 48 - 8;
                    final fraction = (localX / barAreaWidth).clamp(0.0, 1.0);
                    _seekToFraction(fraction);
                  },
                  onHorizontalDragUpdate: (details) {
                    final RenderBox box =
                        context.findRenderObject() as RenderBox;
                    final barAreaWidth = box.size.width - 48 - 8;
                    final localX = details.localPosition.dx - 48 - 8;
                    final fraction = (localX / barAreaWidth).clamp(0.0, 1.0);
                    _seekToFraction(fraction);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 28,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const barWidth = 2.8;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_barCount, (index) {
                            final barFraction = index / _barCount;
                            final isPast = progress > barFraction;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 80),
                              curve: Curves.easeOut,
                              width: barWidth,
                              height: _barHeights[index],
                              decoration: BoxDecoration(
                                color:
                                    isPast ? activeBarColor : inactiveBarColor,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
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

                    // Speed toggle (only visible when playing or loaded)
                    if (_player.duration != null)
                      GestureDetector(
                        onTap: _cycleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.2)
                                : context.surfaceMutedColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_speeds[_speedIndex]}×',
                            style: TextStyle(
                              fontFamily: 'Lexend',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.isMe
                                  ? Colors.white
                                  : context.textSecondaryColor,
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 13,
                        color: textColor,
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
