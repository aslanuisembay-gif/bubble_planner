import 'package:flutter/material.dart';

import 'paper_scan_io.dart' if (dart.library.html) 'paper_scan_web.dart' as impl;

/// Распознаёт текст с фото бумажной записи (Android/iOS — ML Kit). На web/desktop — ручной ввод.
Future<String?> scanTextFromPaper(BuildContext context) =>
    impl.scanTextFromPaper(context);
