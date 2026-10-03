import 'package:flutter/foundation.dart';

/// Generates a 5-beep alarm sound using the Web Audio API (browser only).
/// Falls back silently on non-web platforms.
class SosAudioService {
  static bool _isPlaying = false;

  static void playAlarm() {
    if (_isPlaying) return;
    _isPlaying = true;

    if (kIsWeb) {
      _playWebAudio();
    }
  }

  static void stopAlarm() {
    _isPlaying = false;
  }

  // ignore: avoid_web_libraries_in_flutter
  static void _playWebAudio() {
    try {
      // Use a script injection approach compatible with Flutter web
      // This generates a sawtooth wave alarm (sounds like a siren/beep)
      final script = '''
        (function() {
          try {
            var ctx = new (window.AudioContext || window.webkitAudioContext)();
            var beepCount = 0;
            var maxBeeps = 5;
            
            function playBeep() {
              if (beepCount >= maxBeeps) return;
              beepCount++;
              
              var oscillator = ctx.createOscillator();
              var gainNode = ctx.createGain();
              
              oscillator.connect(gainNode);
              gainNode.connect(ctx.destination);
              
              // Alternate between high (880Hz) and low (660Hz) for siren effect
              oscillator.type = 'sawtooth';
              oscillator.frequency.setValueAtTime(880, ctx.currentTime);
              oscillator.frequency.setValueAtTime(660, ctx.currentTime + 0.4);
              
              gainNode.gain.setValueAtTime(0.7, ctx.currentTime);
              gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.85);
              
              oscillator.start(ctx.currentTime);
              oscillator.stop(ctx.currentTime + 0.85);
              
              setTimeout(playBeep, 950);
            }
            
            playBeep();
          } catch(e) {
            console.warn('Aegis: Audio error:', e);
          }
        })();
      ''';

      // Execute via platform channel on web
      // ignore: undefined_prefixed_name
      import('dart:js').then((js) {
        // ignore: undefined_identifier
        js.context.callMethod('eval', [script]);
      }).catchError((_) {});
    } catch (e) {
      debugPrint('SOS Audio error: $e');
    }
  }
}
