import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> scanTextFromPaper(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: const Color(0xFF1E1B24),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Colors.white70),
                title: const Text('Снять фото', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
                title: const Text('Из галереи', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (source == null || !context.mounted) return null;

  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: source,
    maxWidth: 2400,
    imageQuality: 90,
  );
  if (file == null || !context.mounted) return null;

  if (Platform.isAndroid || Platform.isIOS) {
    final input = InputImage.fromFilePath(file.path);
    final recognizer = TextRecognizer();
    try {
      final recognized = await recognizer.processImage(input);
      final text = recognized.text.trim();
      if (text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Текст не распознан. Сделайте фото светлее/ближе или введите текст вручную.',
              ),
            ),
          );
        }
        return '';
      }
      return text;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка распознавания: $e')),
        );
      }
      return '';
    } finally {
      await recognizer.close();
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Распознавание с фото доступно на телефоне (Android/iOS). Введите текст вручную.',
        ),
      ),
    );
  }
  return '';
}
