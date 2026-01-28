// windows_print_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Windows-specific printing service for POS80 receipts
class WindowsPrintService {
  /// Sends PDF bytes directly to default POS80 printer without dialog
  /// Tries to use SumatraPDF if available, otherwise uses Windows print command
  static Future<bool> printPdfToDefaultPrinter(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      if (!Platform.isWindows) {
        debugPrint('PrintService: Platform is not Windows, cannot print');
        return false;
      }

      // Save PDF to temp directory
      final tempDir = Directory.systemTemp;
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(pdfBytes);

      debugPrint('PrintService: Saved temp PDF to ${tempFile.path}');

      // Try to find SumatraPDF (common install paths)
      final sumatraPath = _findSumatraPDF();
      
      if (sumatraPath != null && File(sumatraPath).existsSync()) {
        debugPrint('PrintService: Found SumatraPDF at $sumatraPath');
        // Use SumatraPDF to print directly to default printer
        final result = await Process.run(
          sumatraPath,
          [
            '-print-to',
            'default',  // Print to default printer
            '-exit-when-done',
            tempFile.path,
          ],
        );
        
        if (result.exitCode == 0) {
          debugPrint('PrintService: Successfully printed via SumatraPDF');
          // Clean up temp file after a delay
          Future.delayed(const Duration(seconds: 2), () {
            try {
              tempFile.deleteSync();
            } catch (e) {
              debugPrint('PrintService: Could not delete temp file: $e');
            }
          });
          return true;
        } else {
          debugPrint('PrintService: SumatraPDF print failed: ${result.stderr}');
        }
      }

      // Fallback: Use Windows print command (without dialog)
      debugPrint('PrintService: Using Windows print command');
      final result = await Process.run(
        'cmd.exe',
        [
          '/c',
          'print /D:LPT1: "${tempFile.path}"',  // Print to LPT1 (default POS printer port)
        ],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        debugPrint('PrintService: Successfully printed via Windows print command');
        // Clean up temp file
        Future.delayed(const Duration(seconds: 2), () {
          try {
            tempFile.deleteSync();
          } catch (e) {
            debugPrint('PrintService: Could not delete temp file: $e');
          }
        });
        return true;
      } else {
        debugPrint('PrintService: Windows print failed: ${result.stderr}');
      }

      return false;
    } catch (e) {
      debugPrint('PrintService: Exception during printing: $e');
      return false;
    }
  }

  /// Finds SumatraPDF installation path
  /// Checks common install locations
  static String? _findSumatraPDF() {
    final commonPaths = [
      'C:\\Program Files\\SumatraPDF\\SumatraPDF.exe',
      'C:\\Program Files (x86)\\SumatraPDF\\SumatraPDF.exe',
      'C:\\Program Files (x86)\\sumatrapdf\\sumatrapdf.exe',
      'C:\\Program Files\\sumatrapdf\\sumatrapdf.exe',
    ];

    for (final path in commonPaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return null;
  }

  /// Alternative: Print to USB port (POS printers often use USB)
  /// This is a fallback method
  static Future<bool> printPdfToUsbPort(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      if (!Platform.isWindows) {
        return false;
      }

      // Save PDF to temp
      final tempDir = Directory.systemTemp;
      final tempFile = File(p.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(pdfBytes);

      // Try to use SumatraPDF with USB port
      final sumatraPath = _findSumatraPDF();
      if (sumatraPath != null && File(sumatraPath).existsSync()) {
        final result = await Process.run(
          sumatraPath,
          [
            '-print-to',
            'USB001:',  // Common USB port name
            '-exit-when-done',
            tempFile.path,
          ],
        );

        if (result.exitCode == 0) {
          Future.delayed(const Duration(seconds: 2), () {
            try {
              tempFile.deleteSync();
            } catch (e) {
              debugPrint('PrintService: Could not delete temp file: $e');
            }
          });
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('PrintService USB: Exception: $e');
      return false;
    }
  }
}
