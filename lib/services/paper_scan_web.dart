// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final denied = code.contains('camera_access_denied') || code.contains('photo_access_denied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
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

  try {
    final bytes = await file.readAsBytes();
    final form = html.FormData();
    form.append('apikey', 'helloworld');
    form.append('language', 'eng');
    form.append('isOverlayRequired', 'false');
    form.appendBlob('file', html.Blob([bytes]), file.name);
    final req = await html.HttpRequest.request(
      'https://api.ocr.space/parse/image',
      method: 'POST',
      sendData: form,
    );
    if (req.status != 200) {
      throw Exception('OCR HTTP ${req.status}');
    }
    final decoded = jsonDecode(req.responseText ?? '{}');
    final parsed = decoded is Map ? decoded['ParsedResults'] : null;
    if (parsed is! List || parsed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('scanNoText'))),
        );
      }
      return '';
    }
    final text = parsed
        .map((e) => (e is Map ? (e['ParsedText'] ?? '') : '').toString())
        .join('\n')
        .trim();
    if (text.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('scanNoText'))),
      );
    }
    return text;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trFill('scanOcrError', {'e': '$e'}))),
      );
    }
    return '';
  }
}
