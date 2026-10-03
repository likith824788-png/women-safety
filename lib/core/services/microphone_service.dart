import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Real Android microphone recording service.
/// Uses flutter_sound to capture WAV audio, then converts to
/// float32 samples for AudioRiskAnalyzer.
/// Falls back to simulated danger audio if mic is unavailable.
class MicrophoneService {
  static bool _isRecording = false;

  /// Records 5 seconds of audio from the device microphone.
  /// Returns float32 PCM samples in range [-1.0, 1.0].
  /// Falls back to [simulateDangerAudio] on any failure.
  static Future<List<double>> record5Seconds() async {
    if (_isRecording) return simulateDangerAudio();
    _isRecording = true;

    // Web: no flutter_sound support — always use simulation
    if (kIsWeb) {
      await Future.delayed(const Duration(seconds: 2));
      _isRecording = false;
      return simulateDangerAudio();
    }

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('MicrophoneService: mic permission denied — using simulation');
        _isRecording = false;
        return simulateDangerAudio();
      }

      final tmpDir = await getTemporaryDirectory();
      final filePath =
          '${tmpDir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.wav';

      final recorder = FlutterSoundRecorder();
      await recorder.openRecorder();

      await recorder.startRecorder(
        toFile: filePath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Record for 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      await recorder.stopRecorder();
      await recorder.closeRecorder();

      // Parse WAV → float samples
      final samples = await _wavToFloats(filePath);

      // Clean up
      try {
        await File(filePath).delete();
      } catch (_) {}

      _isRecording = false;
      debugPrint('MicrophoneService: captured ${samples.length} samples');
      return samples.isEmpty ? simulateDangerAudio() : samples;
    } catch (e) {
      debugPrint('MicrophoneService error: $e');
      _isRecording = false;
      return simulateDangerAudio();
    }
  }

  /// Reads a 16-bit mono WAV file and converts PCM data to float32 [-1.0, 1.0].
  static Future<List<double>> _wavToFloats(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return [];
      final bytes = await file.readAsBytes();

      // Standard WAV header = 44 bytes; PCM data starts at byte 44
      if (bytes.length <= 44) return [];

      final pcm = bytes.sublist(44);
      final samples = <double>[];

      for (int i = 0; i + 1 < pcm.length; i += 2) {
        // Little-endian 16-bit signed int
        int s16 = pcm[i] | (pcm[i + 1] << 8);
        if (s16 > 32767) s16 -= 65536;
        samples.add(s16 / 32768.0);
      }
      return samples;
    } catch (e) {
      debugPrint('WAV parse error: $e');
      return [];
    }
  }

  /// Generates realistic "aggressive voice" audio data for environments
  /// where mic access is unavailable. Used as a fallback for the CNN analyzer.
  static List<double> simulateDangerAudio() {
    const int n = 80000; // ~5 s at 16 kHz
    final samples = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final double t = i / 16000.0;
      final double f0 = 250 + 100 * math.sin(2 * math.pi * 0.5 * t);
      final double env = 0.5 + 0.3 * math.sin(2 * math.pi * 3 * t).abs();
      samples[i] = (env *
              (0.45 * math.sin(2 * math.pi * f0 * t) +
                  0.15 * math.sin(2 * math.pi * f0 * 2 * t) +
                  0.05 * (2 * (i % 100) / 100.0 - 1)))
          .clamp(-1.0, 1.0);
    }
    return samples;
  }
}
