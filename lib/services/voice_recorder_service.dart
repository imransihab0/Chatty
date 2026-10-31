import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Singleton service wrapping the `record` package for butter-smooth voice notes.
///
/// Provides:
/// - Runtime microphone permission request
/// - Start / stop / cancel recording to .m4a temp file
/// - Live amplitude stream (0.0–1.0) for waveform visualization
class VoiceRecorderService {
  VoiceRecorderService._();
  static final VoiceRecorderService instance = VoiceRecorderService._();

  final AudioRecorder _recorder = AudioRecorder();

  String? _currentPath;
  bool _recording = false;

  Timer? _amplitudeTimer;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  /// Normalized amplitude stream (0.0 – 1.0) emitting ~30 times per second.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  bool get isRecording => _recording;
  String? get currentPath => _currentPath;

  /// Request microphone permission. Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      log('VoiceRecorder: permission error: $e');
      return false;
    }
  }

  /// Start recording to a temporary .m4a file.
  Future<bool> startRecording() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return false;

      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/voice_note_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
          numChannels: 1,
        ),
        path: _currentPath!,
      );

      _recording = true;

      // Start polling amplitude at ~30fps for smooth waveform
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _pollAmplitude(),
      );

      log('VoiceRecorder: started recording to $_currentPath');
      return true;
    } catch (e) {
      log('VoiceRecorder: start error: $e');
      _recording = false;
      return false;
    }
  }

  void _pollAmplitude() async {
    if (!_recording) return;
    try {
      final amp = await _recorder.getAmplitude();
      // amp.current is in dBFS (negative, typically -60 to 0)
      // Normalize to 0.0–1.0
      final double dbfs = amp.current;
      // Clamp and normalize: -50 dB → 0.0, 0 dB → 1.0
      final double normalized = ((dbfs + 50) / 50).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    } catch (_) {}
  }

  /// Stop recording and return the file path + duration in milliseconds.
  /// Returns null if not recording or if something went wrong.
  Future<RecordingResult?> stopRecording() async {
    if (!_recording) return null;
    try {
      _amplitudeTimer?.cancel();
      _recording = false;

      final path = await _recorder.stop();
      if (path == null || path.isEmpty) return null;

      // Get file duration by checking the file exists
      final file = File(path);
      if (!await file.exists()) return null;

      log('VoiceRecorder: stopped recording, file at $path');
      return RecordingResult(path: path);
    } catch (e) {
      log('VoiceRecorder: stop error: $e');
      _recording = false;
      return null;
    }
  }

  /// Cancel the current recording and delete the temp file.
  Future<void> cancelRecording() async {
    try {
      _amplitudeTimer?.cancel();
      _recording = false;

      await _recorder.stop();

      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
          log('VoiceRecorder: cancelled and deleted $_currentPath');
        }
      }
      _currentPath = null;
    } catch (e) {
      log('VoiceRecorder: cancel error: $e');
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    await _amplitudeController.close();
    await _recorder.dispose();
  }
}

/// Result of a completed voice recording.
class RecordingResult {
  final String path;
  const RecordingResult({required this.path});
}
