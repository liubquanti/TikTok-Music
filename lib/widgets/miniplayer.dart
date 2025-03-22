import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/audio.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _getFileName(String path) {
    return path.split('/').last.replaceAll('.m4a', '');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        if (audioProvider.currentFile == null) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: CupertinoTheme.of(context).barBackgroundColor,
            border: const Border(
              top: BorderSide(
                color: CupertinoColors.systemGrey5,
                width: 0.5,
              ),
            ),
          ),
            child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Timeline slider
              StreamBuilder<Duration>(
                stream: audioProvider.audioPlayer.positionStream,
                builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = audioProvider.duration;
                
                // Prevent division by zero and handle empty duration
                if (duration.inSeconds == 0) {
                  return const SizedBox(height: 20);
                }

                // Calculate normalized value between 0 and 1
                final value = duration.inSeconds > 0 
                  ? position.inSeconds / duration.inSeconds 
                  : 0.0;
                
                return Row(
                  children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position)),
                    ],
                    ),
                  ),
                  Spacer(),
                  SizedBox(
                    height: 40,
                    child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: CupertinoSlider(
                      value: value.clamp(0.0, 1.0),
                      onChanged: (value) {
                      final newPosition = value * duration.inSeconds;
                      audioProvider.seekTo(
                        Duration(seconds: newPosition.toInt()),
                      );
                      },
                      ),
                    ),
                    ),
                    
                  ),
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(duration)),
                    ],
                    ),
                  ),
                  ],
                );
                },
              ),
              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                children: [
                  Expanded(
                  child: Text(
                    _getFileName(audioProvider.currentFile!.path),
                    style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ),
                  Row(
                  children: [
                    CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.backward_fill,
                      color: CupertinoColors.systemPink,
                    ),
                    onPressed: () => audioProvider.playPrevious(),
                    ),
                    CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      audioProvider.isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                      color: CupertinoColors.systemPink,
                      size: 30,
                    ),
                    onPressed: () {
                      if (audioProvider.isPlaying) {
                      audioProvider.audioPlayer.pause();
                      audioProvider.setIsPlaying(false);
                      } else {
                      audioProvider.audioPlayer.play();
                      audioProvider.setIsPlaying(true);
                      }
                    },
                    ),
                    CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(
                      CupertinoIcons.forward_fill,
                      color: CupertinoColors.systemPink,
                    ),
                    onPressed: () => audioProvider.playNext(),
                    ),
                  ],
                  ),
                ],
                ),
              ),
              ],
            ),
            )
          
        );
      },
    );
  }
}