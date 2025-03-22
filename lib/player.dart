import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'handles/manager.dart';
import 'package:provider/provider.dart';
import '/providers/audio.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  List<File> _audioFiles = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  Future<void> _playAudio(File file, AudioProvider audioProvider) async {
    await audioProvider.playFile(file);
  }

  Future<void> _loadAudioFiles() async {
    final files = await AudioManager.getAudioFiles();
    if (mounted) {
      setState(() {
        _audioFiles = files;
      });
      // Update playlist in AudioProvider
      Provider.of<AudioProvider>(context, listen: false).setPlaylist(files);
    }
  }

  Future<void> _deleteAudio(File file) async {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    if (audioProvider.currentFile?.path == file.path) {
      await audioProvider.audioPlayer.stop();
      audioProvider.clearCurrentTrack();  // Use new method
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
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    
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
      child: ListView.builder(
        itemCount: _audioFiles.length,
        itemBuilder: (context, index) {
          final file = _audioFiles[index];
          final isPlaying = 
              audioProvider.currentFile?.path == file.path && 
              audioProvider.isPlaying;
          
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
              onTap: () => _playAudio(file, audioProvider),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}