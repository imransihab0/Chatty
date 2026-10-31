import 'dart:async';
import 'dart:io';
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/services/voice_recorder_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Ultra-smooth Telegram-style chat input & voice recording bar.
///
/// Fully isolated from the parent ChatScreen to prevent message list
/// sharding, blinking, or layout thrashing during 30fps waveform streaming.
class ChatVoiceInputBar extends StatefulWidget {
  final ChatUser user;
  final TextEditingController textController;
  final Message? replyMessage;
  final VoidCallback onClearReply;
  final Function(String text, String replyMsg, String replyUser) onSendText;
  final Function(File audioFile, int durationMs) onSendVoice;
  final Function(File imageFile) onSendImage;
  final Function(String val) onTextChanged;

  const ChatVoiceInputBar({
    super.key,
    required this.user,
    required this.textController,
    required this.replyMessage,
    required this.onClearReply,
    required this.onSendText,
    required this.onSendVoice,
    required this.onSendImage,
    required this.onTextChanged,
  });

  @override
  State<ChatVoiceInputBar> createState() => _ChatVoiceInputBarState();
}

class _ChatVoiceInputBarState extends State<ChatVoiceInputBar>
    with TickerProviderStateMixin {
  // ── Recording States ──
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  bool _isSendingVoice = false;
  bool _cancelThresholdCrossed = false;
  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;

  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Live waveform values isolated to ValueNotifier
  final ValueNotifier<List<double>> _amplitudesNotifier =
      ValueNotifier<List<double>>([]);
  StreamSubscription<double>? _amplitudeSub;

  // Animations
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _trashScaleController;
  late final Animation<double> _trashScaleAnimation;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService.instance;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _trashScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _trashScaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _trashScaleController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.dispose();
    _trashScaleController.dispose();
    _amplitudesNotifier.dispose();
    super.dispose();
  }

  // ── Start Recording ──
  Future<void> _startRecording() async {
    final started = await _voiceRecorder.startRecording();
    if (!started) {
      if (mounted) {
        Dialogs.showSnackbar(context, 'Microphone permission required');
      }
      return;
    }

    AppHaptics.medium();
    _pulseController.repeat(reverse: true);

    _amplitudesNotifier.value = [];
    _amplitudeSub?.cancel();
    _amplitudeSub = _voiceRecorder.amplitudeStream.listen((amp) {
      final list = List<double>.from(_amplitudesNotifier.value);
      list.add(amp);
      if (list.length > 50) list.removeAt(0);
      _amplitudesNotifier.value = list;
    });

    setState(() {
      _isRecording = true;
      _isRecordingLocked = false;
      _recordSeconds = 0;
      _dragOffsetX = 0.0;
      _dragOffsetY = 0.0;
      _cancelThresholdCrossed = false;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() => _recordSeconds++);
      }
    });
  }

  // ── Stop & Send ──
  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    if (_recordSeconds < 1) {
      await _voiceRecorder.cancelRecording();
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
      });
      if (mounted) {
        Dialogs.showSnackbar(context, 'Hold longer to record voice note');
      }
      return;
    }

    setState(() {
      _isSendingVoice = true;
    });

    final result = await _voiceRecorder.stopRecording();
    final durationMs = _recordSeconds * 1000;

    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
    });

    if (result != null) {
      widget.onSendVoice(File(result.path), durationMs);
    }

    if (mounted) {
      setState(() => _isSendingVoice = false);
    }
  }

  // ── Cancel Recording ──
  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _trashScaleController.reset();

    await _voiceRecorder.cancelRecording();

    AppHaptics.light();
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _cancelThresholdCrossed = false;
    });

    if (mounted) {
      Dialogs.showSnackbar(context, 'Recording cancelled');
    }
  }

  void _sendTextMessage() {
    final text = widget.textController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.light();
    final replyMsg = widget.replyMessage != null
        ? (widget.replyMessage!.type == Type.text
            ? widget.replyMessage!.msg
            : widget.replyMessage!.type == Type.audio
                ? '🎙️ Voice note'
                : '📷 Photo')
        : '';
    final replyUser = widget.replyMessage != null
        ? (widget.replyMessage!.fromId == APIs.user.uid
            ? 'You'
            : widget.user.name)
        : '';

    widget.onSendText(text, replyMsg, replyUser);
    widget.textController.clear();
    widget.onClearReply();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.replyMessage != null) _buildReplyBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Row(
            children: [
              // ── Input Container / Voice Recording HUD ──
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? (context.isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF4F4F5))
                        : context.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isRecording
                          ? (_cancelThresholdCrossed
                              ? AppTheme.danger
                              : context.borderColor)
                          : context.borderColor,
                      width: _isRecording ? 1.5 : 1,
                    ),
                    boxShadow: context.softShadow,
                  ),
                  child: _isRecording
                      ? (_isRecordingLocked
                          ? _buildLockedRecordingHUD()
                          : _buildActiveRecordingHUD())
                      : _buildTextInputRow(),
                ),
              ),
              const SizedBox(width: 10),

              // ── Action Button (Mic / Send / Lock / Stop) ──
              _buildActionButton(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Docked Reply Preview Banner ──
  Widget _buildReplyBanner() {
    final reply = widget.replyMessage!;
    final bool isMe = reply.fromId == APIs.user.uid;
    final String senderName = isMe ? 'You' : widget.user.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: context.borderColor),
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 36,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.reply_rounded,
                        size: 14,
                        color: context.isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      'Replying to $senderName',
                      style: TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.type == Type.text
                      ? reply.msg
                      : reply.type == Type.audio
                          ? '🎙️ Voice note'
                          : '📷 Photo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lexend',
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            splashRadius: 16,
            onPressed: widget.onClearReply,
            icon: Icon(Icons.close_rounded,
                size: 18, color: context.textMutedColor),
          ),
        ],
      ),
    );
  }

  // ── Standard Text Input Row ──
  Widget _buildTextInputRow() {
    return Row(
      children: [
        IconButton(
          splashRadius: 20,
          onPressed: () async {
            AppHaptics.selection();
            final ImagePicker picker = ImagePicker();
            final List<XFile> images =
                await picker.pickMultiImage(imageQuality: 30);
            for (var i in images) {
              widget.onSendImage(File(i.path));
            }
          },
          icon: Icon(
            Icons.photo_library_outlined,
            color: context.textSecondaryColor,
            size: 22,
          ),
        ),
        IconButton(
          splashRadius: 20,
          onPressed: () async {
            AppHaptics.selection();
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(
                source: ImageSource.camera, imageQuality: 30);
            if (image != null) {
              widget.onSendImage(File(image.path));
            }
          },
          icon: Icon(
            Icons.camera_alt_outlined,
            color: context.textSecondaryColor,
            size: 22,
          ),
        ),
        Expanded(
          child: TextField(
            controller: widget.textController,
            onChanged: widget.onTextChanged,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              color: context.textPrimaryColor,
            ),
            decoration: InputDecoration(
              hintText: 'Message...',
              hintStyle: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                color: context.textMutedColor,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Active Hold-to-Record HUD ──
  Widget _buildActiveRecordingHUD() {
    final int minutes = _recordSeconds ~/ 60;
    final int seconds = _recordSeconds % 60;
    final String timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Pulsing red dot
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Duration counter
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 10),

          // High-performance Canvas Waveform (RepaintBoundary isolated)
          Expanded(
            child: RepaintBoundary(
              child: SizedBox(
                height: 24,
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: _amplitudesNotifier,
                  builder: (context, amps, _) {
                    return CustomPaint(
                      painter: _LiveWaveformPainter(
                        amplitudes: amps,
                        color: context.textPrimaryColor.withValues(alpha: 0.55),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Slide to cancel hint
          Transform.translate(
            offset: Offset(_dragOffsetX * 0.3, 0),
            child: Opacity(
              opacity: (1.0 + _dragOffsetX / 120).clamp(0.25, 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _cancelThresholdCrossed
                        ? Icons.delete_rounded
                        : Icons.chevron_left_rounded,
                    size: 16,
                    color: _cancelThresholdCrossed
                        ? AppTheme.danger
                        : context.textMutedColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _cancelThresholdCrossed
                        ? 'Release to cancel'
                        : 'Slide to cancel',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 11,
                      fontWeight: _cancelThresholdCrossed
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: _cancelThresholdCrossed
                          ? AppTheme.danger
                          : context.textMutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Locked Hands-Free Recording HUD ──
  Widget _buildLockedRecordingHUD() {
    final int minutes = _recordSeconds ~/ 60;
    final int seconds = _recordSeconds % 60;
    final String timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimaryColor,
            ),
          ),
          const SizedBox(width: 10),

          // Waveform
          Expanded(
            child: RepaintBoundary(
              child: SizedBox(
                height: 24,
                child: ValueListenableBuilder<List<double>>(
                  valueListenable: _amplitudesNotifier,
                  builder: (context, amps, _) {
                    return CustomPaint(
                      painter: _LiveWaveformPainter(
                        amplitudes: amps,
                        color: context.textPrimaryColor.withValues(alpha: 0.55),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Cancel (trash) button
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.danger,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Button (Mic / Send / Lock) ──
  Widget _buildActionButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.textController,
      builder: (context, value, _) {
        final bool hasText = value.text.trim().isNotEmpty;

        // 1. Locked mode: Tap to Send
        if (_isRecordingLocked) {
          return GestureDetector(
            onTap: _isSendingVoice ? null : _stopAndSendRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white : Colors.black,
                shape: BoxShape.circle,
                boxShadow: context.isDark ? null : AppTheme.buttonShadow,
              ),
              child: Center(
                child: _isSendingVoice
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              context.isDark ? Colors.black : Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: context.isDark ? Colors.black : Colors.white,
                        size: 24,
                      ),
              ),
            ),
          );
        }

        // 2. Active recording: Hold & drag gestures
        if (_isRecording) {
          return GestureDetector(
            onLongPressMoveUpdate: (details) {
              final dx = details.offsetFromOrigin.dx.clamp(-160.0, 0.0);
              final dy = details.offsetFromOrigin.dy.clamp(-120.0, 0.0);

              final wasCrossed = _cancelThresholdCrossed;
              final nowCrossed = dx < -80;

              if (nowCrossed && !wasCrossed) {
                AppHaptics.heavy();
                _trashScaleController.forward();
              } else if (!nowCrossed && wasCrossed) {
                _trashScaleController.reverse();
              }

              setState(() {
                _dragOffsetX = dx;
                _dragOffsetY = dy;
                _cancelThresholdCrossed = nowCrossed;
              });

              // Swipe up to lock
              if (dy < -60 && !_isRecordingLocked) {
                AppHaptics.medium();
                setState(() => _isRecordingLocked = true);
              }
            },
            onLongPressEnd: (details) {
              if (_isRecordingLocked) return;

              if (_cancelThresholdCrossed) {
                _cancelRecording();
              } else {
                _stopAndSendRecording();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _cancelThresholdCrossed
                    ? AppTheme.danger
                    : (context.isDark ? Colors.white : Colors.black),
                shape: BoxShape.circle,
                boxShadow: context.isDark ? null : AppTheme.buttonShadow,
              ),
              child: Center(
                child: _cancelThresholdCrossed
                    ? ScaleTransition(
                        scale: _trashScaleAnimation,
                        child: const Icon(
                          Icons.delete_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                      )
                    : (_dragOffsetY < -30
                        ? Icon(
                            Icons.lock_rounded,
                            color: context.isDark ? Colors.black : Colors.white,
                            size: 22,
                          )
                        : Icon(
                            Icons.mic_rounded,
                            color: context.isDark ? Colors.black : Colors.white,
                            size: 25,
                          )),
              ),
            ),
          );
        }

        // 3. Normal mode: Tap to Send or Hold to Record
        return GestureDetector(
          onTap: () {
            if (hasText) {
              _sendTextMessage();
            } else {
              Dialogs.showSnackbar(context, 'Hold to record, slide up to lock');
            }
          },
          onLongPressStart: hasText
              ? null
              : (details) {
                  _startRecording();
                },
          onLongPressMoveUpdate: hasText
              ? null
              : (details) {
                  if (!_isRecording) return;
                  final dx = details.offsetFromOrigin.dx.clamp(-160.0, 0.0);
                  final dy = details.offsetFromOrigin.dy.clamp(-120.0, 0.0);

                  final wasCrossed = _cancelThresholdCrossed;
                  final nowCrossed = dx < -80;

                  if (nowCrossed && !wasCrossed) {
                    AppHaptics.heavy();
                    _trashScaleController.forward();
                  } else if (!nowCrossed && wasCrossed) {
                    _trashScaleController.reverse();
                  }

                  setState(() {
                    _dragOffsetX = dx;
                    _dragOffsetY = dy;
                    _cancelThresholdCrossed = nowCrossed;
                  });

                  if (dy < -60 && !_isRecordingLocked) {
                    AppHaptics.medium();
                    setState(() => _isRecordingLocked = true);
                  }
                },
          onLongPressEnd: hasText
              ? null
              : (details) {
                  if (!_isRecording) return;
                  if (_isRecordingLocked) return;

                  if (_cancelThresholdCrossed) {
                    _cancelRecording();
                  } else {
                    _stopAndSendRecording();
                  }
                },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              boxShadow: context.isDark ? null : AppTheme.buttonShadow,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _isSendingVoice
                    ? SizedBox(
                        key: const ValueKey('sending'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        hasText
                            ? Icons.arrow_upward_rounded
                            : Icons.mic_rounded,
                        key: ValueKey(hasText ? 'send' : 'mic'),
                        color: context.isDark ? Colors.black : Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// GPU-accelerated Live Waveform CustomPainter
class _LiveWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _LiveWaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    const double barSpacing = 4.0;
    final int maxBars = (size.width / barSpacing).floor();
    final count = amplitudes.length > maxBars ? maxBars : amplitudes.length;

    for (int i = 0; i < count; i++) {
      final amp = amplitudes[amplitudes.length - 1 - i];
      final double x = size.width - 2.0 - (i * barSpacing);
      final double barHeight =
          (3.5 + (amp * (size.height - 5.0))).clamp(3.5, size.height);
      final double yTop = (size.height - barHeight) / 2;
      final double yBottom = yTop + barHeight;

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) => true;
}
