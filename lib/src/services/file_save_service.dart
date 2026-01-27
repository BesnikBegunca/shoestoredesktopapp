// file_save_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

/// Service për shpëtimin e PDF files në macOS desktop
class FileSaveService {
  /// Shpëton PDF bytes në file me "Save As" dialog
  static Future<void> savePdfBytes(
    Uint8List bytes,
    String suggestedFileName,
  ) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      // Përdor file_selector për desktop platforms
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: suggestedFileName,
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'PDF',
            extensions: ['pdf'],
          ),
        ],
      );

      if (location == null) {
        // User canceled
        return;
      }

      // Shpëto file-in
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: suggestedFileName,
      );
      await file.saveTo(location.path);
    } else {
      // Fallback për platforma të tjera
      throw UnsupportedError('Platform nuk mbështetet: ${Platform.operatingSystem}');
    }
  }

  /// Shpëton PDF dhe hap file-in (opsional)
  static Future<void> saveAndOpenPdf(
    Uint8List bytes,
    String suggestedFileName,
  ) async {
    await savePdfBytes(bytes, suggestedFileName);
    // Opsional: hap file-in pas shpëtimit
    // Mund të përdoret open_filex ose Process.run për të hapur PDF
  }
}
