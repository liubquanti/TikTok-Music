import 'package:flutter/cupertino.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'handles/manager.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<File> _audioFiles = [];
  File? _currentFile;
  bool _isPlaying = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  Future<void> _loadAudioFiles() async {
    final files = await AudioManager.getAudioFiles();
    if (mounted) {
      setState(() {
        _audioFiles = files;
      });
    }
  }

  Future<void> _playAudio(File file) async {
    if (_currentFile?.path == file.path && _isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();
      setState(() {
        _currentFile = file;
      });
    }
  }

  Future<void> _deleteAudio(File file) async {
    if (_currentFile?.path == file.path) {
      await _audioPlayer.stop();
      setState(() {
        _currentFile = null;
      });
    }
    await file.delete();
    _loadAudioFiles();
  }

  Future<void> _refreshAudioFiles() async {
    setState(() {
      _isRefreshing = true;
    });

    await _loadAudioFiles();

    setState(() {
      _isRefreshing = false;
    });
  }

  String _getFileName(String path) {
    return path.split('/').last.replaceAll('.m4a', '');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Music Player'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: _isRefreshing 
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.refresh),
          onPressed: _isRefreshing ? null : _refreshAudioFiles,
        ),
      ),
      child: SafeArea(
        child: _audioFiles.isEmpty
            ? const Center(
                child: Text('No audio files found'),
              )
            : ListView.builder(
                itemCount: _audioFiles.length,
                itemBuilder: (context, index) {
                  final file = _audioFiles[index];
                  final isPlaying = 
                      _currentFile?.path == file.path && _isPlaying;
                  
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: CupertinoColors.systemGrey5,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: CupertinoListTile(
                      leading: Icon(
                        isPlaying
                            ? CupertinoIcons.pause_circle_fill
                            : CupertinoIcons.play_circle_fill,
                        color: CupertinoColors.systemPink,
                        size: 30,
                      ),
                      title: Text(_getFileName(file.path)),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(
                          CupertinoIcons.delete,
                          color: CupertinoColors.systemRed,
                        ),
                        onPressed: () => _deleteAudio(file),
                      ),
                      onTap: () => _playAudio(file),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}