/// Non-web: синхронная запись не используется (только shared_preferences).
void writeLocalTasksSync(String json, int idSeed) {}

(String?, int?) readLocalTasksSync() => (null, null);
