// file_download_service.dart
//
// Responsibility:
// Provides one browser-download abstraction for generated PDF and XLSX bytes.

import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class FileDownloadService {
  const FileDownloadService();

  Future<void> savePdf(String baseName, Uint8List bytes) async {
    await FileSaver.instance.saveFile(
      name: _sanitize(baseName),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  Future<void> saveXlsx(String baseName, Uint8List bytes) async {
    await FileSaver.instance.saveFile(
      name: _sanitize(baseName),
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  String _sanitize(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  }
}
