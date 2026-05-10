import 'local_tasks_sync_stub.dart'
    if (dart.library.html) 'local_tasks_sync_web.dart' as impl;

/// Web: синхронная запись в localStorage (тот же префикс, что у shared_preferences).
void writeLocalTasksSync(String json, int idSeed) =>
    impl.writeLocalTasksSync(json, idSeed);

(String?, int?) readLocalTasksSync() => impl.readLocalTasksSync();

/// Снимок облачных задач перед logout (веб: синхронно в localStorage).
void writeCloudTasksSnapshotSync(String jsonPayload) =>
    impl.writeCloudTasksSnapshotSync(jsonPayload);

String? readCloudTasksSnapshotSync() => impl.readCloudTasksSnapshotSync();
