import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';  // Updated import
import 'dart:io';
import 'models/tiktok.dart';
import 'player.dart';
import 'package:provider/provider.dart';
import 'providers/audio.dart';
import 'widgets/miniplayer.dart';
import 'package:audio_service/audio_service.dart';
import 'handles/audio.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.myapp.audio',
      androidNotificationChannelName: 'Audio Service',
      androidNotificationOngoing: true,
      notificationColor: Color(0xFFFF0000),
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AudioProvider(audioHandler: audioHandler),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemPink,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        height: 60,
        items: const [
          BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.music_note),
        label: 'Програвач',
          ),
          BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.cloud_download),
        label: 'Завантаження',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 60), // Add space for miniplayer
                child: index == 0
                    ? const PlayerScreen()
                    : const DownloaderScreen(),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String _status = '';

  Future<void> _downloadAndConvertToAudio() async {
    if (_urlController.text.isEmpty) {
      setState(() => _status = 'Вставте посилання на TikTok відео');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Отримання інформації про відео...';
    });

    try {
      final tiktokClient = TiktokApiClient(apiUrl: _urlController.text);
      final tiktokInfo = await tiktokClient.fetchTiktokInfo();

      if (tiktokInfo?.data?.play == null) {
        setState(() {
          _isLoading = false;
          _status = 'Не вдалося отримати інформацію про відео';
        });
        return;
      }

      setState(() => _status = 'Завантаження відео...');

      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final videoPath = '${tempDir.path}/tiktok_video.mp4';
      final audioPath = '${tempDir.path}/tiktok_audio.m4a';

      await dio.download(
        tiktokInfo!.data!.play!,
        videoPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            setState(() => _status = 'Завантаження: $progress%');
          }
        },
      );

      setState(() => _status = 'Перетворення на аудіо...');

      // Convert video to audio using FFmpeg
      await FFmpegKit.execute(
          '-i $videoPath -vn -acodec copy $audioPath'
      );

      setState(() => _status = 'Збереження до музики...');

      // Save to Music library
      final documentsDir = await getApplicationDocumentsDirectory();
      final finalAudioPath = '${documentsDir.path}/TikTok_Audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await File(audioPath).copy(finalAudioPath);

      setState(() {
        _isLoading = false;
        _status = 'Трек успішно збережено!';
      });

      // Clear URL field after successful download
      _urlController.clear();

      // Clean up temporary files
      File(videoPath).deleteSync();
      File(audioPath).deleteSync();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Завантаження TikTok аудіо'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoTextField(
                controller: _urlController,
                placeholder: 'Вставте посилання на TikTok відео',
                padding: const EdgeInsets.all(16.0),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CupertinoActivityIndicator(radius: 15)
              else
                CupertinoButton.filled(
                  onPressed: _downloadAndConvertToAudio,
                  child: const Text('Завантажити аудіо'),
                ),
              const SizedBox(height: 20),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
