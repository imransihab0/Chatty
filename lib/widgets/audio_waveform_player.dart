import 'dart:async';
import 'dart:math';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Telegram-Grade Seekable Audio Waveform Player with Integrated Timestamp & Receipts
class AudioWaveformPlayer extends StatefulWidget {
  final bool isMe;
  final String audioUrl;
  final int durationMs;
  final String? sentTime;
  final bool isRead;

  const AudioWaveformPlayer({
    super.key,
    required this.isMe,
    required this.audioUrl,
    this.durationMs = 0,
    this.sentTime,
    this.isRead = false,
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer>
    with TickerProviderStateMixin {
  static _AudioWaveformPlayerState? _activePlayingPlayer;

  late final AudioPlayer _player;
  late final List<double> _barHeights;
  late final AnimationController _playPauseController;

  static const int _barCount = 26;
  static const List<double> _speeds = [1.0, 1.5, 2.0];
  int _speedIndex = 0;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double? _scrubFraction;
  int? _lastScrubIndex;
  bool _wasPlayingBeforeScrub = false;
  double _playButtonScale = 1.0;
  double _speedPillScale = 1.0;

  void _pauseSelf() {
    if (_player.playing) {
      _player.pause();
      _playPauseController.reverse();
      if (mounted) setState(() {});
    }
  }

  void _claimPlayback() {
    if (_activePlayingPlayer != null && _activePlayingPlayer != this) {
      _activePlayingPlayer!._pauseSelf();
    }
    _activePlayingPlayer = this;
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    // Natural speech envelope waveform (contoured arc with speech variance)
    final random = Random(widget.audioUrl.hashCode);
    _barHeights = List.generate(_barCount, (i) {
      final double progress = i / (_barCount - 1);
      final double envelope = sin(progress * pi);
      final double noise = 0.35 + random.nextDouble() * 0.65;
      return (4.0 + envelope * noise * 18.0).clamp(4.0, 22.0);
    });

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player.positionStream.listen((pos) {
      if (mounted && _scrubFraction == null) {
        setState(() => _position = pos);
      }
    });

    _player.durationStream.listen((dur) {
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }
    });

    _player.playerStateStream.listen((state) {
      if (!mounted) return;

      if (state.playing) {
        _playPauseController.forward();
      } else {
        _playPauseController.reverse();
      }

      final bool isBuffering =
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.completed) {
        if (_isLoading) {
          setState(() => _isLoading = false);
        }
      } else if (isBuffering && !_isLoading) {
        setState(() => _isLoading = true);
      }

      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
        _playPauseController.reverse();
        setState(() {
          _position = Duration.zero;
          _scrubFraction = null;
          _isLoading = false;
        });
      }
    });

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
      if (!mounted) return;
      setState(() => _isLoading = false);
      _claimPlayback();
      _playPauseController.forward();
      unawaited(_player.play());
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
    if (_hasError) {
      setState(() => _hasError = false);
      _loadAndPlay();
      return;
    }

    if (_player.playing) {
      _player.pause();
      _playPauseController.reverse();
    } else {
      if (_player.duration == null) {
        _loadAndPlay();
      } else {
        _claimPlayback();
        _playPauseController.forward();
        unawaited(_player.play());
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
    if (_activePlayingPlayer == this) {
      _activePlayingPlayer = null;
    }
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

    final activeBarColor = widget.isMe
        ? Colors.white
        : (context.isDark ? Colors.white : Colors.black);
    final inactiveBarColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : (context.isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8));
    final textColor = widget.isMe
        ? Colors.white
        : (context.isDark ? const Color(0xFFE4E4E7) : const Color(0xFF27272A));

    final Duration displayDuration =
        (_player.playing || _scrubFraction != null) ? _position : _duration;

    return SizedBox(
      width: 236,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Circular Play / Pause Button with tactile press scale ──
            GestureDetector(
              onTapDown: (_) => setState(() => _playButtonScale = 0.91),
              onTapUp: (_) => setState(() => _playButtonScale = 1.0),
              onTapCancel: () => setState(() => _playButtonScale = 1.0),
              onTap: _isLoading ? null : _togglePlay,
              child: AnimatedScale(
                scale: _playButtonScale,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 38,
                  height: 38,
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withValues(alpha: 0.20)
                      : (context.isDark
                          ? const Color(0xFF2C2C30)
                          : const Color(0xFFE4E4E8)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.28)
                        : (context.isDark
                            ? const Color(0xFF3A3A40)
                            : const Color(0xFFD4D4D8)),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
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
                              size: 20,
                            )
                          : AnimatedIcon(
                              icon: AnimatedIcons.play_pause,
                              progress: _playPauseController,
                              color: widget.isMe
                                  ? Colors.white
                                  : context.textPrimaryColor,
                              size: 22,
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

            // ── Waveform + Bottom Metadata (Duration, Speed, SentTime, Checkmarks) ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seekable contoured waveform
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      const barWidth = 2.4;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () {},
                        onTapDown: (details) {
                          AppHaptics.selection();
                          final fraction =
                              (details.localPosition.dx / width).clamp(0.0, 1.0);
                          _seekToFraction(fraction);
                        },
                        onHorizontalDragStart: (details) {
                          _wasPlayingBeforeScrub = _player.playing;
                          if (_wasPlayingBeforeScrub) {
                            _player.pause();
                          }
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
                            if (_wasPlayingBeforeScrub) {
                              _claimPlayback();
                              unawaited(_player.play());
                            }
                          }
                        },
                        onHorizontalDragCancel: () {
                          _lastScrubIndex = null;
                          setState(() => _scrubFraction = null);
                          if (_wasPlayingBeforeScrub) {
                            _claimPlayback();
                            unawaited(_player.play());
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            height: 24,
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
                  const SizedBox(height: 2),

                  // Bottom Metadata Row
                  Row(
                    children: [
                      // Duration text
                      Text(
                        _formatDuration(displayDuration),
                        style: TextStyle(
                          fontFamily: 'Lexend',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Speed toggle pill (1× / 1.5× / 2×) with spring scale
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => setState(() => _speedPillScale = 0.92),
                        onTapUp: (_) => setState(() => _speedPillScale = 1.0),
                        onTapCancel: () => setState(() => _speedPillScale = 1.0),
                        onTap: _cycleSpeed,
                        child: AnimatedScale(
                          scale: _speedPillScale,
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _speeds[_speedIndex] > 1.0
                                  ? (widget.isMe
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : (context.isDark
                                          ? Colors.white
                                          : Colors.black))
                                  : (widget.isMe
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : context.surfaceMutedColor),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.isMe
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : context.borderColor,
                                width: 0.6,
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
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : context.textSecondaryColor),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Sent Time & Checkmarks
                      if (widget.sentTime != null) ...[
                        Text(
                          widget.sentTime!,
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: widget.isMe
                                ? Colors.white.withValues(alpha: 0.85)
                                : (context.isDark
                                    ? const Color(0xFFA1A1AA)
                                    : const Color(0xFF71717A)),
                          ),
                        ),
                        if (widget.isMe) ...[
                          const SizedBox(width: 3),
                          Icon(
                            widget.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 13,
                            color: widget.isRead
                                ? AppTheme.success
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
