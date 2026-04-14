import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate app icon PNG', () async {
    const size = Size(1024, 1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1024, 1024),
      Paint()..color = const Color(0xFF000000),
    );

    const gold = Color(0xFFD4A847);
    final center = Offset(size.width / 2, size.height / 2);

    // App icon: centered large crescent moon only.
    final moonCenter = center;
    canvas.drawCircle(moonCenter, size.width * 0.22, Paint()..color = gold);
    canvas.drawCircle(
      Offset(moonCenter.dx + size.width * 0.095, moonCenter.dy - size.height * 0.01),
      size.width * 0.205,
      Paint()..color = const Color(0xFF000000),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      fail('Failed to encode PNG bytes.');
    }

    final dir = Directory('assets/icon');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('assets/icon/app_icon.png');
    file.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
  });
}

