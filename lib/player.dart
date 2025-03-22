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
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, _) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: const Text('Музичний програвач'),
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
              final isCurrentTrack = audioProvider.isCurrentTrack(file);
              
              return Dismissible(
                key: Key(file.path),
                background: Container(
                  alignment: Alignment.centerRight,
                  color: CupertinoColors.systemRed,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(
                    CupertinoIcons.delete,
                    color: CupertinoColors.white,
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showCupertinoDialog<bool>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Delete Track'),
                      content: const Text('Are you sure you want to delete this track?'),
                      actions: [
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                        CupertinoDialogAction(
                          isDefaultAction: true,
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  _deleteAudio(file);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCurrentTrack 
                        ? CupertinoColors.systemGrey6 
                        : null,
                    border: const Border(
                      bottom: BorderSide(
                        color: CupertinoColors.systemGrey5,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: CupertinoListTile(
                    leading: Icon(
                      (isCurrentTrack && audioProvider.isPlaying)
                          ? CupertinoIcons.pause_circle_fill
                          : CupertinoIcons.play_circle_fill,
                      color: isCurrentTrack 
                          ? CupertinoColors.systemPink
                          : CupertinoColors.systemGrey,
                      size: 30,
                    ),
                    title: Text(
                      _getFileName(file.path),
                      style: TextStyle(
                        color: isCurrentTrack 
                            ? CupertinoColors.systemPink
                            : null,
                        fontWeight: isCurrentTrack 
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                    onTap: () async {
                      if (isCurrentTrack) {
                        await audioProvider.togglePlayPause();
                      } else {
                        await audioProvider.playFile(file);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}