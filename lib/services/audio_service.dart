import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioMode { mute, alertsOnly, assistant }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  AudioMode _currentMode = AudioMode.alertsOnly;

  DateTime? _lastViolationAnnouncement;

  // Cached SharedPreferences instance — avoids repeated getInstance() calls
  SharedPreferences? _prefs;

  AudioService._internal() {
    _initTts();
    _loadMode();
  }

  AudioMode get currentMode => _currentMode;

  /// Lazily obtain and cache the SharedPreferences instance.
  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.5); // Normal speed
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
    }
  }

  Future<void> _loadMode() async {
    try {
      final prefs = await _preferences;
      final modeIndex = prefs.getInt('audio_mode') ?? AudioMode.alertsOnly.index;
      _currentMode = AudioMode.values[modeIndex];
    } catch (e) {
      debugPrint('Failed to load audio mode: $e');
    }
  }

  Future<void> setMode(AudioMode mode) async {
    _currentMode = mode;
    try {
      final prefs = await _preferences;
      await prefs.setInt('audio_mode', mode.index);
    } catch (e) {
      debugPrint('Failed to save audio mode: $e');
    }

    switch (mode) {
      case AudioMode.mute:
        try {
          await _flutterTts.stop();
        } catch (e) {
          debugPrint('TTS stop failed: $e');
        }
        break;
      case AudioMode.alertsOnly:
        break;
      case AudioMode.assistant:
        break;
    }
  }

  Future<void> cycleMode() async {
    final nextIndex = (_currentMode.index + 1) % AudioMode.values.length;
    await setMode(AudioMode.values[nextIndex]);
  }

  Future<void> speakViolation() async {
    if (_currentMode == AudioMode.mute) return;

    final now = DateTime.now();
    // Spam engelleme: En son ihlal duyurusundan bu yana en az 2 dakika geçmeli
    if (_lastViolationAnnouncement != null) {
      final diff = now.difference(_lastViolationAnnouncement!).inSeconds;
      if (diff < 120) return;
    }

    _lastViolationAnnouncement = now;
    try {
      await _flutterTts.speak("Hız sınırını aştınız.");
    } catch (e) {
      debugPrint('TTS speak (violation) failed: $e');
    }
  }

  Future<void> speakSafe() async {
    if (_currentMode == AudioMode.mute) return;
    if (_lastViolationAnnouncement == null) return;

    _lastViolationAnnouncement = null;
    try {
      await _flutterTts.speak("Hızınız güvenli seviyede.");
    } catch (e) {
      debugPrint('TTS speak (safe) failed: $e');
    }
  }

  Future<void> speakMilestone(
    int averageSpeed,
    double currentDistanceKm,
  ) async {
    if (_currentMode != AudioMode.assistant) return;
    try {
      await _flutterTts.speak("Ortalama hızınız $averageSpeed.");
    } catch (e) {
      debugPrint('TTS speak (milestone) failed: $e');
    }
  }
}
