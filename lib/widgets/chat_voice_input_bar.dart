import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:chatty/api/apis.dart';
import 'package:chatty/helper/app_haptics.dart';
import 'package:chatty/helper/app_theme.dart';
import 'package:chatty/helper/dialogs.dart';
import 'package:chatty/models/chat_user.dart';
import 'package:chatty/models/message.dart';
import 'package:chatty/services/voice_recorder_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';

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

  // Preview Mode in Hands-Free
  bool _isPreviewing = false;
  File? _previewAudioFile;
  AudioPlayer? _previewPlayer;
  bool _isPlayingPreview = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  StreamSubscription? _previewPosSub;
  StreamSubscription? _previewStateSub;

  // Animations
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _trashScaleController;
  late final Animation<double> _trashScaleAnimation;
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;
  late final Animation<Offset> _chevronSlideAnimation;
  late final AnimationController _lockFloatController;
  late final Animation<double> _lockFloatAnimation;

  final VoiceRecorderService _voiceRecorder = VoiceRecorderService.instance;

  @override
  void initState() {
    super.initState();

    // Red dot pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Trash can pop animation
    _trashScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _trashScaleAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _trashScaleController, curve: Curves.easeOutBack),
    );

    // "Slide to cancel <" Shimmer & Chevron motion
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
    _chevronSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
    _shimmerController.repeat(reverse: true);

    // Slide-up-to-lock floating bounce animation
    _lockFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _lockFloatAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lockFloatController, curve: Curves.easeInOut),
    );
    _lockFloatController.repeat(reverse: true);
  }

  @override
  void dispose() {
    if (_isRecording && !_isPreviewing) {
      _voiceRecorder.cancelRecording();
    }
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _previewPosSub?.cancel();
    _previewStateSub?.cancel();
    _previewPlayer?.dispose();
    if (_previewAudioFile != null && _previewAudioFile!.existsSync()) {
      try {
        _previewAudioFile!.deleteSync();
      } catch (_) {}
    }
    _pulseController.dispose();
    _trashScaleController.dispose();
    _shimmerController.dispose();
    _lockFloatController.dispose();
    _amplitudesNotifier.dispose();
    super.dispose();
  }

  // ── Pause & Preview (Hands-Free Locked Recording) ──
  Future<void> _pauseAndPreviewRecording() async {
    AppHaptics.selection();
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();
    _pulseController.stop();

    if (_recordSeconds < 1) {
      await _cancelRecording();
      return;
    }

    final result = await _voiceRecorder.stopRecording();
    if (result != null) {
      final file = File(result.path);
      final player = AudioPlayer();
      try {
        await player.setFilePath(file.path);
        final dur = player.duration ?? Duration(seconds: _recordSeconds);
        _previewPosSub = player.positionStream.listen((pos) {
          if (mounted) setState(() => _previewPosition = pos);
        });
        _previewStateSub = player.playerStateStream.listen((state) {
          if (!mounted) return;
          if (state.processingState == ProcessingState.completed) {
            player.seek(Duration.zero);
            player.pause();
            setState(() {
              _isPlayingPreview = false;
              _previewPosition = Duration.zero;
            });
          }
        });

        setState(() {
          _isPreviewing = true;
          _previewAudioFile = file;
          _previewPlayer = player;
          _previewDuration = dur;
          _isPlayingPreview = false;
        });
      } catch (_) {}
    }
  }

  void _togglePreviewPlay() {
    AppHaptics.light();
    if (_previewPlayer == null) return;
    if (_previewPlayer!.playing) {
      _previewPlayer!.pause();
      setState(() => _isPlayingPreview = false);
    } else {
      _previewPlayer!.play();
      setState(() => _isPlayingPreview = true);
    }
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
      _isPreviewing = false;
      _previewAudioFile = null;
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

    if (_isPreviewing && _previewAudioFile != null) {
      _previewPlayer?.stop();
      _previewPlayer?.dispose();
      _previewPlayer = null;
      _previewPosSub?.cancel();
      _previewStateSub?.cancel();

      final durationMs = _recordSeconds * 1000;
      final file = _previewAudioFile!;
      setState(() {
        _isRecording = false;
        _isRecordingLocked = false;
        _isPreviewing = false;
        _previewAudioFile = null;
      });
      widget.onSendVoice(file, durationMs);
      widget.onClearReply();
      return;
    }

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
      widget.onClearReply();
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

    _previewPlayer?.stop();
    _previewPlayer?.dispose();
    _previewPlayer = null;
    _previewPosSub?.cancel();
    _previewStateSub?.cancel();
    if (_previewAudioFile != null && _previewAudioFile!.existsSync()) {
      try {
        _previewAudioFile!.deleteSync();
      } catch (_) {}
    }
    _previewAudioFile = null;

    if (!_isPreviewing) {
      await _voiceRecorder.cancelRecording();
    }

    AppHaptics.light();
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _isPreviewing = false;
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
        ? (widget.replyMessage!.fromId == APIs.myUid
            ? 'You'
            : widget.user.name)
        : '';

    widget.onSendText(text, replyMsg, replyUser);
    widget.textController.clear();
    widget.onClearReply();
  }

  // ── Telegram Attachment Action Bottom Sheet ──
  void _showTelegramAttachmentSheet(BuildContext context) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildAttachmentBottomSheet(ctx),
    );
  }

  Widget _buildAttachmentBottomSheet(BuildContext sheetContext) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor, width: 0.8),
          boxShadow: context.softShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Drag handle pill
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Share Content',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachmentTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      AppHaptics.selection();
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 70,
                      );
                      if (image != null) {
                        widget.onSendImage(File(image.path));
                      }
                    },
                  ),
                  _buildAttachmentTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      AppHaptics.selection();
                      final ImagePicker picker = ImagePicker();
                      final List<XFile> images =
                          await picker.pickMultiImage(imageQuality: 70);
                      for (var i in images) {
                        widget.onSendImage(File(i.path));
                      }
                    },
                  ),
                  _buildAttachmentTile(
                    icon: Icons.mic_rounded,
                    label: 'Voice Note',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      AppHaptics.light();
                      Dialogs.showSnackbar(
                        context,
                        'Hold the mic button to record, slide up to lock hands-free',
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: context.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: context.borderColor, width: 0.8),
            ),
            child: Icon(icon, color: context.textPrimaryColor, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Lexend',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return SafeArea(
      top: false,
      bottom: !hasKeyboard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyMessage != null) _buildReplyBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Telegram Input Bar Capsule / Voice Recording HUD ──
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(minHeight: 48),
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
                        width: 0.8,
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
                const SizedBox(width: 8),

                // ── Dynamic Action Button with Floating Lock ──
                _buildActionButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Frosted Reply Banner ──
  Widget _buildReplyBanner() {
    final reply = widget.replyMessage!;
    final bool isMe = reply.fromId == APIs.myUid;
    final String senderName = isMe ? 'You' : widget.user.name;

    final String snippetText;
    final IconData typeIcon;
    if (reply.type == Type.text) {
      snippetText = reply.msg;
      typeIcon = Icons.chat_bubble_outline_rounded;
    } else if (reply.type == Type.audio) {
      snippetText = 'Voice note';
      typeIcon = Icons.mic_rounded;
    } else {
      snippetText = 'Photo';
      typeIcon = Icons.photo_outlined;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 2),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (context.isDark ? const Color(0xFF1E1E1E) : Colors.white)
                  .withValues(alpha: context.isDark ? 0.82 : 0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(
                color: context.borderColor,
                width: 0.8,
              ),
              boxShadow: context.softShadow,
            ),
            child: Row(
              children: [
                // Vertical Accent Bar
                Container(
                  width: 3.5,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.primaryColor,
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
                          Icon(
                            Icons.reply_rounded,
                            size: 13,
                            color: context.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Replying to $senderName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            typeIcon,
                            size: 13,
                            color: context.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              snippetText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Lexend',
                                fontSize: 12,
                                color: context.textSecondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Circular Close Button
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.light();
                    widget.onClearReply();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: context.textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Standard Text Input Row ──
  Widget _buildTextInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Telegram Sleek Attachment Button (Paperclip)
        IconButton(
          splashRadius: 20,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(),
          onPressed: () => _showTelegramAttachmentSheet(context),
          icon: Transform.rotate(
            angle: -math.pi / 4,
            child: Icon(
              Icons.attach_file_rounded,
              color: context.textSecondaryColor,
              size: 22,
            ),
          ),
        ),
        // Clean Typography Text Field auto-expanding up to 5 lines
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextField(
              controller: widget.textController,
              onChanged: widget.onTextChanged,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
              cursorColor: context.primaryColor,
              style: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: context.textPrimaryColor,
              ),
              decoration: InputDecoration(
                hintText: 'Message',
                hintStyle: TextStyle(
                  fontFamily: 'Lexend',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: context.textMutedColor,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
              ),
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
          // Blinking pulsing red dot
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.danger,
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

          // High-performance Live Waveform Canvas
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
                        activeColor: context.textPrimaryColor.withValues(alpha: 0.65),
                        idleColor: context.textMutedColor.withValues(alpha: 0.22),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // "Slide to cancel <" Shimmer & Chevron Animation
          _buildSlideToCancel(),
        ],
      ),
    );
  }

  Widget _buildSlideToCancel() {
    return Transform.translate(
      offset: Offset(_dragOffsetX * 0.35, 0),
      child: Opacity(
        opacity: _cancelThresholdCrossed
            ? 1.0
            : (1.0 + _dragOffsetX / 100).clamp(0.2, 1.0),
        child: _cancelThresholdCrossed
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _trashScaleAnimation,
                    child: const Icon(
                      Icons.delete_rounded,
                      size: 16,
                      color: AppTheme.danger,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Release to cancel',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              )
            : AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      final shimmerVal = _shimmerAnimation.value;
                      return LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          context.textMutedColor.withValues(alpha: 0.4),
                          context.textPrimaryColor,
                          context.textMutedColor.withValues(alpha: 0.4),
                        ],
                        stops: [
                          (shimmerVal - 0.25).clamp(0.0, 1.0),
                          shimmerVal.clamp(0.0, 1.0),
                          (shimmerVal + 0.25).clamp(0.0, 1.0),
                        ],
                      ).createShader(bounds);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SlideTransition(
                          position: _chevronSlideAnimation,
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'Slide to cancel',
                          style: TextStyle(
                            fontFamily: 'Lexend',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ── Locked Hands-Free Recording HUD ──
  Widget _buildLockedRecordingHUD() {
    if (_isPreviewing) {
      final double progress = _previewDuration.inMilliseconds > 0
          ? (_previewPosition.inMilliseconds / _previewDuration.inMilliseconds)
              .clamp(0.0, 1.0)
          : 0.0;
      final int currentSec = _previewPosition.inSeconds;
      final int totalSec = _previewDuration.inSeconds > 0
          ? _previewDuration.inSeconds
          : _recordSeconds;
      final String timeLabel =
          '${currentSec ~/ 60}:${(currentSec % 60).toString().padLeft(2, '0')} / ${totalSec ~/ 60}:${(totalSec % 60).toString().padLeft(2, '0')}';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            // Trash / Discard Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cancelRecording,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 36,
                  height: 36,
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
            ),
            const SizedBox(width: 4),

            // Play / Pause Preview Button
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePreviewPlay,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.primarySoftColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlayingPreview
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: context.textPrimaryColor,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Progress bar & Time label
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: context.borderColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final int minutes = _recordSeconds ~/ 60;
    final int seconds = _recordSeconds % 60;
    final String timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseAnimation,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppTheme.danger,
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
          const SizedBox(width: 8),

          // Live Waveform
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
                        activeColor: context.textPrimaryColor.withValues(alpha: 0.65),
                        idleColor: context.textMutedColor.withValues(alpha: 0.22),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Pause & Preview Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pauseAndPreviewRecording,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.primarySoftColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_rounded,
                  color: context.textPrimaryColor,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Cancel (trash) button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cancelRecording,
            child: Padding(
              padding: const EdgeInsets.all(4),
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
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dynamic Action Button (Morphing Mic / Send / Lock) ──
  Widget _buildActionButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.textController,
      builder: (context, value, _) {
        final bool hasText = value.text.trim().isNotEmpty;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Floating Lock Capsule (Telegram style)
            if (_isRecording && !_isRecordingLocked)
              Positioned(
                bottom: 58,
                child: _buildFloatingLockCapsule(),
              ),

            // Action Button Circle / Gestures
            _buildActionGestureTarget(hasText),
          ],
        );
      },
    );
  }

  Widget _buildFloatingLockCapsule() {
    final bool isNearLock = _dragOffsetY < -40;

    return AnimatedBuilder(
      animation: _lockFloatAnimation,
      builder: (context, child) {
        final floatOffset = _lockFloatAnimation.value * 3.5;
        return Transform.translate(
          offset: Offset(0, _dragOffsetY.clamp(-26.0, 0.0) - floatOffset),
          child: Container(
            width: 38,
            height: 68,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: isNearLock
                    ? (context.isDark ? Colors.white : Colors.black)
                    : context.borderColor,
                width: 0.8,
              ),
              boxShadow: context.softShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(
                  isNearLock ? Icons.lock_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: isNearLock
                      ? (context.isDark ? Colors.white : Colors.black)
                      : context.textPrimaryColor,
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 16,
                  color: context.textMutedColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionGestureTarget(bool hasText) {
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
                        context.isDark ? Colors.black : Colors.white,
                      ),
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

    // 2. Active recording: Hold & Drag gestures
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
            AppHaptics.heavy();
            setState(() {
              _isRecordingLocked = true;
              _dragOffsetY = 0.0;
            });
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
          width: 48,
          height: 48,
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
                AppHaptics.heavy();
                setState(() {
                  _isRecordingLocked = true;
                  _dragOffsetY = 0.0;
                });
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
  }
}

/// GPU-accelerated Live Waveform CustomPainter
class _LiveWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color activeColor;
  final Color idleColor;

  _LiveWaveformPainter({
    required this.amplitudes,
    required this.activeColor,
    required this.idleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double barSpacing = 4.0;
    const double barWidth = 2.4;
    final int maxBars = (size.width / barSpacing).floor();

    final activePaint = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final idlePaint = Paint()
      ..color = idleColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    // Draw placeholder bars across entire width if amplitudes are short
    for (int i = 0; i < maxBars; i++) {
      final double x = size.width - 2.0 - (i * barSpacing);
      if (x < 0) break;
      final double yTop = (size.height - 3.5) / 2;
      canvas.drawLine(Offset(x, yTop), Offset(x, yTop + 3.5), idlePaint);
    }

    if (amplitudes.isEmpty) return;

    final count = amplitudes.length > maxBars ? maxBars : amplitudes.length;

    for (int i = 0; i < count; i++) {
      final amp = amplitudes[amplitudes.length - 1 - i];
      final double x = size.width - 2.0 - (i * barSpacing);
      if (x < 0) break;
      final double barHeight =
          (3.5 + (amp * (size.height - 5.0))).clamp(3.5, size.height);
      final double yTop = (size.height - barHeight) / 2;
      final double yBottom = yTop + barHeight;

      canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWaveformPainter oldDelegate) => true;
}
