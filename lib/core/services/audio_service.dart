import 'package:audioplayers/audioplayers.dart';


class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();


  bool _isMuted = false;
  bool _isVoiceEnabled = true;

  Future<void> init() async {
    // TTS initialization removed as per user request to use only beep sounds
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
    if (_isMuted) return;
    // Instead of voice, we just play the mark/beep sound
    await playMark();
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
