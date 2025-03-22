import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../enum/repeat.dart';
import '../handles/audio.dart';

class AudioProvider extends ChangeNotifier {
  final MyAudioHandler audioHandler;
  final List<File> _playlist = [];
  int? _currentIndex = -1;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  AudioProvider({required this.audioHandler}) {
    // Listen to playback state changes
    audioHandler.playbackState.listen((state) {
      notifyListeners();
    });
    
    // Listen to current index changes from the audio handler
    audioHandler.currentIndexNotifier.addListener(() {
      if (audioHandler.currentIndexNotifier.value != null) {
        _currentIndex = audioHandler.currentIndexNotifier.value;
        notifyListeners();
      }
    });
  }

  AudioPlayer get audioPlayer => audioHandler.player;
  
  File? get currentFile => _currentIndex != null && _currentIndex! >= 0 && 
      _currentIndex! < _playlist.length ? _playlist[_currentIndex!] : null;
  
  bool get isPlaying => audioPlayer.playing;
  bool get isShuffled => _isShuffled;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => audioPlayer.position;
  Duration get duration => audioPlayer.duration ?? Duration.zero;

  Future<void> setPlaylist(List<File> files, {int initialIndex = 0}) async {
    _playlist.clear();
    _playlist.addAll(files);
    _currentIndex = initialIndex;
    await audioHandler.setFiles(files);
    notifyListeners();
  }

  Future<void> playFile(File file) async {
    final index = _playlist.indexOf(file);
    if (index != -1) {
      _currentIndex = index;
      await audioHandler.playFromFile(file);
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    notifyListeners();
  }

  bool isCurrentTrack(File file) {
    if (_currentIndex == null || currentFile == null) return false;
    return currentFile?.path == file.path;
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    audioHandler.setShuffleMode(_isShuffled 
        ? AudioServiceShuffleMode.all 
        : AudioServiceShuffleMode.none);
    notifyListeners();
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    notifyListeners();
  }

  void clearCurrentTrack() {
    _currentIndex = -1;
    audioHandler.stop();
    notifyListeners();
  }

  Future<void> seekTo(Duration position) => audioHandler.seek(position);
  Future<void> playNext() => audioHandler.skipToNext();
  Future<void> playPrevious() => audioHandler.skipToPrevious();

  @override
  void dispose() {
    audioHandler.stop();
    super.dispose();
  }
}