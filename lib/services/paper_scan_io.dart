import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../translations.dart';

Future<String?> scanTextFromPaper(BuildContext context) async {
  final bp = context.bp;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: bp.modalSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: bp.modalBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: bp.textSecondary),
                title: Text(
                  tr('notesPickCamera'),
                  style: TextStyle(color: bp.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: bp.textSecondary),
                title: Text(
                  tr('notesPickGallery'),
                  style: TextStyle(color: bp.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    tr('cancel'),
                    style: TextStyle(color: bp.primary, fontWeight: FontWeight.w700),
                  ),
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
  XFile? file;
  try {
    file = await picker.pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 90,
    );
  } on PlatformException catch (e) {
    if (context.mounted) {
      final code = e.code.toLowerCase();
      final isCameraDenied =
          code.contains('camera_access_denied') || code.contains('photo_access_denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCameraDenied
                ? tr('scanAccessDenied')
                : trFill('scanOpenFailed', {'e': e.message ?? e.code}),
          ),
        ),
      );
    }
    return null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trFill('scanOpenFailed', {'e': '$e'}))),
      );
    }
    return null;
  }
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
            SnackBar(content: Text(tr('scanNoText'))),
          );
        }
        return '';
      }
      return text;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trFill('scanOcrError', {'e': '$e'}))),
        );
      }
      return '';
    } finally {
      await recognizer.close();
    }
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('scanMobileOnly'))),
    );
  }
  return '';
}
