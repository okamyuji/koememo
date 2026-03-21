import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  sherpa.initBindings();
  runApp(const ProviderScope(child: KoememoApp()));
}
