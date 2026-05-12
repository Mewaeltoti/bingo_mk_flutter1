import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  bool _isMuted = false;
  bool _isVoiceEnabled = true;

  Future<void> init() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void toggleVoice(bool enabled) {
    _isVoiceEnabled = enabled;
  }

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    await _audioPlayer.play(AssetSource(assetPath));
  }

  Future<void> callNumber(int number) async {
    if (_isMuted || !_isVoiceEnabled) return;

    String letter = "";
    if (number <= 15) {
      letter = "B";
    } else if (number <= 30)
      letter = "I";
    else if (number <= 45)
      letter = "N";
    else if (number <= 60)
      letter = "G";
    else
      letter = "O";

    await _tts.speak("$letter. $number");
  }

  Future<void> playWin() async {
    await playSfx('sounds/win.mp3');
  }

  Future<void> playDraw() async {
    await playSfx('sounds/draw.mp3');
  }

  Future<void> playMark() async {
    await playSfx('sounds/mark.mp3');
  }

  Future<void> playError() async {
    await playSfx('sounds/error.mp3');
  }
}
