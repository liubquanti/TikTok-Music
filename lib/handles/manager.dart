import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioManager {
  static Future<List<File>> getAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.m4a'))
        .toList();
    return files;
  }
}