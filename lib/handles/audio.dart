import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer player = AudioPlayer();
  final List<MediaItem> _playlist = [];
  ConcatenatingAudioSource? _audioSource;

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    // Listen to playback events
    player.playbackEventStream.listen(_broadcastState);
    
    // Listen to position updates
    player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: player.bufferedPosition,
      ));
    });
    
    // Listen to current index
    player.currentIndexStream.listen((index) {
      if (index != null && _playlist.isNotEmpty && index < _playlist.length) {
        mediaItem.add(_playlist[index]);
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: player.currentIndex ?? -1,
    ));
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await player.seek(Duration.zero, index: index);
    await play();
  }

  @override
  Future<void> skipToNext() async {
    if (_audioSource == null || _audioSource!.length <= 1) return;
    
    final currentLoopMode = player.loopMode;
    if (currentLoopMode == LoopMode.one) {
      await player.setLoopMode(LoopMode.off);
    }
    
    try {
      if (player.hasNext) {
        await player.seekToNext();
        await play();
      } else if (_audioSource!.length > 0) {
        await player.seek(Duration.zero, index: 0);
        await play();
      }
    } finally {
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(currentLoopMode);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audioSource == null || _audioSource!.length <= 1) return;
    
    final currentLoopMode = player.loopMode;
    if (currentLoopMode == LoopMode.one) {
      await player.setLoopMode(LoopMode.off);
    }
    
    try {
      if (player.hasPrevious) {
        await player.seekToPrevious();
        await play();
      } else if (_audioSource!.length > 0) {
        final lastIndex = _audioSource!.length - 1;
        await player.seek(Duration.zero, index: lastIndex);
        await play();
      }
    } finally {
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(currentLoopMode);
      }
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
        await player.setLoopMode(LoopMode.all);
        break;
      case AudioServiceRepeatMode.group:
        await player.setLoopMode(LoopMode.all);
        break;
    }
    super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await player.setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);
    super.setShuffleMode(shuffleMode);
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> playFromFile(File file) async {
    try {
      // Get the file duration (this requires temporarily setting the file)
      final tempPlayer = AudioPlayer();
      final duration = await tempPlayer.setFilePath(file.path);
      await tempPlayer.dispose();
      
      final name = file.path.split('/').last.replaceAll('.m4a', '');
      final item = MediaItem(
        id: file.path,
        title: name,
        duration: duration,
        artUri: Uri.file('${file.parent.path}/assets/default_art.png'),
        playable: true,
      );
      
      mediaItem.add(item);
      
      // If we don't have a playlist yet, create one with only this file
      if (_audioSource == null || _playlist.isEmpty) {
        _playlist.clear();
        _playlist.add(item);
        
        _audioSource = ConcatenatingAudioSource(
          children: [AudioSource.uri(Uri.file(file.path))],
        );
        
        await player.setAudioSource(_audioSource!);
        queue.add(_playlist);
      } else {
        // Find file in existing playlist
        final index = _playlist.indexWhere((i) => i.id == file.path);
        if (index != -1) {
          await player.seek(Duration.zero, index: index);
        }
      }
      
      await play();
    } catch (e) {
      debugPrint('Error playing file: $e');
    }
  }

  Future<void> setFiles(List<File> files) async {
    try {
      _playlist.clear();
      
      // Create MediaItems with durations
      for (var file in files) {
        final name = file.path.split('/').last.replaceAll('.m4a', '');
        _playlist.add(MediaItem(
          id: file.path,
          title: name,
          artUri: Uri.file('${file.parent.path}/assets/default_art.png'),
          playable: true,
        ));
      }
      
      // Create audio source
      _audioSource = ConcatenatingAudioSource(
        children: files.map((file) => 
          AudioSource.uri(Uri.file(file.path))
        ).toList(),
      );
      
      // Set the audio source and update queue
      await player.setAudioSource(_audioSource!, initialIndex: 0);
      queue.add(_playlist);
      
      // Update durations for media items
      if (_playlist.isNotEmpty) {
        for (int i = 0; i < _playlist.length; i++) {
          await player.seek(Duration.zero, index: i);
          final duration = player.duration;
          if (duration != null) {
            _playlist[i] = _playlist[i].copyWith(duration: duration);
          }
        }
        
        // Reset back to first track
        await player.seek(Duration.zero, index: 0);
        mediaItem.add(_playlist[0]);
      }
    } catch (e) {
      debugPrint('Error setting files: $e');
    }
  }
}