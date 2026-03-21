import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:koememo/core/constants.dart';

class ModelManager {
  static String? _modelDir;

  static Future<String> ensureModelReady() async {
    if (_modelDir != null) return _modelDir!;

    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models', 'sense-voice'));

    final tokensFile = File(p.join(modelDir.path, AppConstants.tokensFileName));
    if (!await tokensFile.exists()) {
      await modelDir.create(recursive: true);
      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.modelFileName}',
        p.join(modelDir.path, AppConstants.modelFileName),
      );
      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.tokensFileName}',
        p.join(modelDir.path, AppConstants.tokensFileName),
      );
      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.vadFileName}',
        p.join(modelDir.path, AppConstants.vadFileName),
      );
    }

    _modelDir = modelDir.path;
    return _modelDir!;
  }

  static Future<void> _copyAssetFile(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await File(destPath).writeAsBytes(bytes, flush: true);
  }
}
