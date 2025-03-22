import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();
  List<File> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;

  AudioProvider() {
    // Listen for track completion
    audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playNext();
      }
    });
  }

  File? get currentFile => _currentIndex >= 0 && _currentIndex < _playlist.length 
      ? _playlist[_currentIndex] 
      : null;
  bool get isPlaying => _isPlaying;
  Duration get position => audioPlayer.position;
  Duration get duration => audioPlayer.duration ?? Duration.zero;

  void setPlaylist(List<File> files, {int initialIndex = 0}) {
    _playlist = files;
    _currentIndex = initialIndex;
    notifyListeners();
  }

  void setIsPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
    } else {
      // If it's the last track, go back to the first one
      _currentIndex = 0;
    }
    await _playFile(_playlist[_currentIndex]);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      // If it's the first track, go to the last one
      _currentIndex = _playlist.length - 1;
    }
    await _playFile(_playlist[_currentIndex]);
  }

  Future<void> playFile(File file) async {
    final index = _playlist.indexWhere((f) => f.path == file.path);
    if (index != -1) {
      _currentIndex = index;
      await _playFile(file);
    }
  }

  Future<void> _playFile(File file) async {
    await audioPlayer.setFilePath(file.path);
    await audioPlayer.play();
    _isPlaying = true;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await audioPlayer.seek(position);
  }

  void clearCurrentTrack() {
    _currentIndex = -1;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}