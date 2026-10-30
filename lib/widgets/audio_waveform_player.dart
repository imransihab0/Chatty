import 'dart:async';
import 'dart:math';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:flutter/material.dart';

/// Interactive audio note waveform player widget
class AudioWaveformPlayer extends StatefulWidget {
  final bool isMe;
  final String audioUrl;
  final String durationText;

  const AudioWaveformPlayer({
    super.key,
    required this.isMe,
    required this.audioUrl,
    this.durationText = '0:14',
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _playbackTimer;
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    final random = Random(widget.audioUrl.hashCode);
    _barHeights = List.generate(22, (i) => 6.0 + random.nextDouble() * 18.0);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    AppHaptics.light();
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) return;
        setState(() {
          _progress += 0.02;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            _playbackTimer?.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBarColor =
        widget.isMe ? const Color(0xFF67E8F9) : AppTheme.primary;
    final inactiveBarColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : context.borderColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Circle
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.25)
                    : context.primarySoftColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? Colors.white : AppTheme.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform Bars & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 26,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_barHeights.length, (index) {
                      final double barThreshold =
                          index / _barHeights.length;
                      final bool isPast = _progress >= barThreshold;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 3.2,
                        height: _isPlaying
                            ? min(24.0, max(6.0, _barHeights[index] + (index % 3 == 0 ? 4 : -3)))
                            : _barHeights[index],
                        decoration: BoxDecoration(
                          color: isPast ? activeBarColor : inactiveBarColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.durationText,
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.8)
                            : context.textMutedColor,
                      ),
                    ),
                    const Icon(
                      Icons.graphic_eq_rounded,
                      size: 13,
                      color: Colors.white70,
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
