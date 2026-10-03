import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Platform-safe Audio Player for Alarm Sirens across Web, Android, iOS.
class WebAudioPlayer {
  static final AudioPlayer _player = AudioPlayer();

  static void playAlarmSiren() async {
    try {
      await _player.play(UrlSource(
          'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (e) {
      debugPrint('Audio alarm error: $e');
    }
  }
}
