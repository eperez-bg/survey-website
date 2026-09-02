// file_download_service.dart
// Browser/device save abstraction used by all export buttons.

import 'dart:typed_data';

import 'package:flutter_file_saver/flutter_file_saver.dart';

class FileDownloadService {
  const FileDownloadService();

  Future<void> saveBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    await FlutterFileSaver().writeFileAsBytes(fileName: fileName, bytes: bytes);
  }
}
