import 'dart:io';
import 'package:flutter/foundation.dart';
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
    debugPrint('ModelManager: modelDir = ${modelDir.path}');

    final tokensFile = File(p.join(modelDir.path, AppConstants.tokensFileName));
    if (!await tokensFile.exists()) {
      debugPrint('ModelManager: tokens not found, copying assets...');
      await modelDir.create(recursive: true);

      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.modelFileName}',
        p.join(modelDir.path, AppConstants.modelFileName),
      );
      debugPrint('ModelManager: model.int8.onnx copied');

      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.tokensFileName}',
        p.join(modelDir.path, AppConstants.tokensFileName),
      );
      debugPrint('ModelManager: tokens.txt copied');

      await _copyAssetFile(
        '${AppConstants.modelAssetDir}/${AppConstants.vadFileName}',
        p.join(modelDir.path, AppConstants.vadFileName),
      );
      debugPrint('ModelManager: silero_vad.onnx copied');
    } else {
      debugPrint('ModelManager: models already exist');
    }

    // ファイルサイズの検証
    final modelFile = File(p.join(modelDir.path, AppConstants.modelFileName));
    final vadFile = File(p.join(modelDir.path, AppConstants.vadFileName));
    debugPrint(
      'ModelManager: model=${await modelFile.length()} bytes, '
      'tokens=${await tokensFile.length()} bytes, '
      'vad=${await vadFile.length()} bytes',
    );

    _modelDir = modelDir.path;
    return _modelDir!;
  }

  static Future<void> _copyAssetFile(String assetPath, String destPath) async {
    debugPrint('ModelManager: copying $assetPath -> $destPath');
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await File(destPath).writeAsBytes(bytes, flush: true);
    debugPrint('ModelManager: copied ${bytes.length} bytes');
  }
}
