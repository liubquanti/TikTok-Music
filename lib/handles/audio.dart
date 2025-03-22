import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

class MyAudioHandler extends BaseAudioHandler {
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

    // Listen to duration changes
    player.durationStream.listen((duration) {
      if (duration != null && _playlist.isNotEmpty) {
        final index = player.currentIndex ?? 0;
        if (index < _playlist.length) {
          mediaItem.add(_playlist[index].copyWith(
            duration: duration,
          ));
        }
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
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
      queueIndex: player.currentIndex,
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
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_audioSource == null || _audioSource!.length <= 1) return;
    
    try {
      // Store current repeat mode
      final currentLoopMode = player.loopMode;
      
      // Disable repeat mode temporarily
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(LoopMode.off);
      }

      final nextIndex = (player.currentIndex ?? -1) + 1;
      if (nextIndex < _audioSource!.length) {
        await player.seekToNext();
        if (_playlist.isNotEmpty && nextIndex < _playlist.length) {
          mediaItem.add(_playlist[nextIndex]);
        }
      } else if (_audioSource!.length > 0) {
        // Loop to first track
        await player.seek(Duration.zero, index: 0);
        if (_playlist.isNotEmpty) {
          mediaItem.add(_playlist[0]);
        }
      }

      await play();
      
      // Restore repeat mode
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(currentLoopMode);
      }
    } catch (e) {
      print('Error skipping to next: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_audioSource == null || _audioSource!.length <= 1) return;
    
    try {
      // Store current repeat mode
      final currentLoopMode = player.loopMode;
      
      // Disable repeat mode temporarily
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(LoopMode.off);
      }

      final previousIndex = (player.currentIndex ?? 1) - 1;
      if (previousIndex >= 0) {
        await player.seekToPrevious();
        if (_playlist.isNotEmpty && previousIndex < _playlist.length) {
          mediaItem.add(_playlist[previousIndex]);
        }
      } else if (_audioSource!.length > 0) {
        // Loop to last track
        final lastIndex = _audioSource!.length - 1;
        await player.seek(Duration.zero, index: lastIndex);
        if (_playlist.isNotEmpty) {
          mediaItem.add(_playlist[lastIndex]);
        }
      }

      await play();
      
      // Restore repeat mode
      if (currentLoopMode == LoopMode.one) {
        await player.setLoopMode(currentLoopMode);
      }
    } catch (e) {
      print('Error skipping to previous: $e');
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    await player.setShuffleModeEnabled(mode == AudioServiceShuffleMode.all);
    super.setShuffleMode(mode);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode mode) async {
    // Temporarily disable repeat mode for navigation
    await player.setLoopMode(LoopMode.off);
    
    switch (mode) {
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
        break;
    }
    super.setRepeatMode(mode);
  }

  Future<void> playFromFile(File file) async {
    try {
      if (_audioSource == null) {
        // If there's no playlist yet, set up the audio source
        await setFiles([file]);
      }
      
      // Find index of the file in current playlist
      final index = _playlist.indexWhere((item) => item.id == file.path);
      if (index != -1) {
        await player.seek(Duration.zero, index: index);
        await play();
        mediaItem.add(_playlist[index]);
      }
    } catch (e) {
      print('Error playing file: $e');
    }
  }

  Future<void> setFiles(List<File> files) async {
    _playlist.clear();
    // Create MediaItems
    for (var file in files) {
      final name = file.path.split('/').last.replaceAll('.m4a', '');
      _playlist.add(MediaItem(
        id: file.path,
        title: name,
        duration: await _getDuration(file),
        artUri: Uri.parse('asset:///assets/default_art.png'),
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
    
    if (_playlist.isNotEmpty) {
      mediaItem.add(_playlist[0]);
    }
  }

  Future<Duration?> _getDuration(File file) async {
    try {
      final duration = await player.setFilePath(file.path);
      return duration;
    } catch (e) {
      print('Error getting duration: $e');
      return null;
    }
  }
}