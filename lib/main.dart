import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'models/tiktok.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemPink,
      ),
      home: DownloaderScreen(),
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

  Future<void> _downloadVideo() async {
    if (_urlController.text.isEmpty) {
      setState(() => _status = 'Please enter a TikTok URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Fetching video info...';
    });

    try {
      final tiktokClient = TiktokApiClient(apiUrl: _urlController.text);
      final tiktokInfo = await tiktokClient.fetchTiktokInfo();

      if (tiktokInfo?.data?.play == null) {
        setState(() {
          _isLoading = false;
          _status = 'Failed to get video information';
        });
        return;
      }

      setState(() => _status = 'Downloading video...');

      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/tiktok_video.mp4';

      await dio.download(
        tiktokInfo!.data!.play!,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            setState(() => _status = 'Downloading: $progress%');
          }
        },
      );

      setState(() => _status = 'Saving to gallery...');

      final success = await GallerySaver.saveVideo(savePath);

      setState(() {
        _isLoading = false;
        _status = success == true ? 'Video saved to gallery!' : 'Failed to save video';
      });

      File(savePath).deleteSync();
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
        middle: Text('TikTok Downloader'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoTextField(
                controller: _urlController,
                placeholder: 'Enter TikTok video URL',
                padding: const EdgeInsets.all(16.0),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CupertinoActivityIndicator(radius: 15)
              else
                CupertinoButton.filled(
                  onPressed: _downloadVideo,
                  child: const Text('Download Video'),
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
