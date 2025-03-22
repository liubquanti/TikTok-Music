import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import '../enum/repeat.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();
  List<File> _playlist = [];
  List<File> _shuffledPlaylist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;

  AudioProvider() {
    // Listen to both completion and player state changes
    audioPlayer.playerStateStream.listen((state) {
      // Update playing state based on player state
      _isPlaying = state.playing;
      
      if (state.processingState == ProcessingState.completed) {
        _onTrackComplete();
      }
      notifyListeners();
    });
  }

  // Getters
  File? get currentFile => _currentIndex >= 0 && _currentIndex < currentPlaylist.length 
      ? currentPlaylist[_currentIndex] 
      : null;
  bool get isPlaying => _isPlaying;
  bool get isShuffled => _isShuffled;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => audioPlayer.position;
  Duration get duration => audioPlayer.duration ?? Duration.zero;
  List<File> get currentPlaylist => _isShuffled ? _shuffledPlaylist : _playlist;

  void setPlaylist(List<File> files, {int initialIndex = 0}) {
    _playlist = files;
    _shuffledPlaylist = List.from(files);
    _currentIndex = initialIndex;
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      // Save current track
      final currentFile = this.currentFile;
      // Shuffle playlist
      _shuffledPlaylist.shuffle();
      // Move current track to new position
      if (currentFile != null) {
        final newIndex = _shuffledPlaylist.indexOf(currentFile);
        if (newIndex != -1) {
          _currentIndex = newIndex;
        }
      }
    } else {
      // When turning shuffle off, find the current track in original playlist
      final currentFile = this.currentFile;
      if (currentFile != null) {
        _currentIndex = _playlist.indexOf(currentFile);
      }
    }
    notifyListeners();
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
  }

  Future<void> _onTrackComplete() async {
    switch (_repeatMode) {
      case RepeatMode.one:
        await _playFile(currentFile!);
        break;
      case RepeatMode.all:
        await playNext();
        break;
      case RepeatMode.off:
        if (_currentIndex < currentPlaylist.length - 1) {
          await playNext();
        }
        break;
    }
  }

  Future<void> playNext() async {
    if (currentPlaylist.isEmpty) return;

    if (_currentIndex < currentPlaylist.length - 1) {
      _currentIndex++;
      await _playFile(currentPlaylist[_currentIndex]);
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = 0;
      await _playFile(currentPlaylist[_currentIndex]);
    }
  }

  Future<void> playPrevious() async {
    if (currentPlaylist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
      await _playFile(currentPlaylist[_currentIndex]);
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = currentPlaylist.length - 1;
      await _playFile(currentPlaylist[_currentIndex]);
    }
  }

  Future<void> playFile(File file) async {
    final index = currentPlaylist.indexWhere((f) => f.path == file.path);
    if (index != -1) {
      _currentIndex = index;
      await _playFile(file);
    }
  }

  Future<void> _playFile(File file) async {
    try {
      await audioPlayer.setFilePath(file.path);
      await audioPlayer.play();
      // Don't set _isPlaying here - it will be updated by the stream listener
      notifyListeners();
    } catch (e) {
      print('Error playing file: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    await audioPlayer.seek(position);
  }

  void clearCurrentTrack() {
    _currentIndex = -1;
    _isPlaying = false;
    notifyListeners();
  }

  void setIsPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play();
      }
      // Don't set _isPlaying here - it will be updated by the stream listener
    } catch (e) {
      print('Error toggling play/pause: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}