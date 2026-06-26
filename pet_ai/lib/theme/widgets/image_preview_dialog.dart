import 'dart:io';

import 'package:flutter/material.dart';

/// Полноэкранный просмотр изображения с зумом — единый просмотрщик для фото
/// (как при открытии файла в истории документов).
class ImagePreviewDialog extends StatelessWidget {
  final File file;
  final String? title;

  const ImagePreviewDialog({super.key, required this.file, this.title});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: title == null
              ? null
              : Text(
                  title!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
