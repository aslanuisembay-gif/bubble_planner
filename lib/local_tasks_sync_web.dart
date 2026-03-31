import 'dart:convert';

import 'package:web/web.dart' as web;

/// Как в shared_preferences_web: ключ = `flutter.` + имя, значение = json.encode(...).
const String _kTasks = 'flutter.bubble_planner_local_tasks_v1';
const String _kSeed = 'flutter.bubble_planner_local_id_seed_v1';

void writeLocalTasksSync(String json, int idSeed) {
  web.window.localStorage.setItem(_kTasks, jsonEncode(json));
  web.window.localStorage.setItem(_kSeed, jsonEncode(idSeed));
}

(String?, int?) readLocalTasksSync() {
  final ts = web.window.localStorage.getItem(_kTasks);
  final ss = web.window.localStorage.getItem(_kSeed);
  if (ts == null || ts.isEmpty) {
    return (null, null);
  }
  String? tasksRaw;
  try {
    final d = jsonDecode(ts);
    if (d is String) {
      tasksRaw = d;
    } else if (d is List || d is Map) {
      tasksRaw = jsonEncode(d);
    } else {
      tasksRaw = ts;
    }
  } catch (_) {
    tasksRaw = ts;
  }
  int? seed;
  if (ss != null && ss.isNotEmpty) {
    try {
      final d = jsonDecode(ss);
      if (d is int) {
        seed = d;
      } else if (d is num) {
        seed = d.toInt();
      }
    } catch (_) {
      seed = int.tryParse(ss);
    }
  }
  return (tasksRaw, seed);
}
