# bubble_planner

A new Flutter project.

## Getting Started

### Convex (dev/prod URLs)

Dev (локальная разработка с авто-перезаливкой функций):

```bash
cd "/Users/aliya/Desktop/Buble Planner 21022026"
npx convex dev
```

Запуск Flutter на **dev**:

```bash
flutter run -d chrome --dart-define=ENV=dev --dart-define=CONVEX_URL_DEV=https://<your-dev>.convex.cloud
```

Упрощенный запуск без ручного ввода URL (использует файл):

```bash
flutter run -d chrome --dart-define-from-file=config/dart_defines/dev.json
```

Деплой в **prod**:

```bash
npm run convex:deploy
```

Запуск Flutter на **prod**:

```bash
flutter run -d chrome --dart-define=ENV=prod --dart-define=CONVEX_URL_PROD=https://<your-prod>.convex.cloud
```

Упрощенный запуск prod (из файла):

```bash
flutter run -d chrome --dart-define-from-file=config/dart_defines/prod.json
```

Fallback (старый способ, один URL):

```bash
flutter run -d chrome --dart-define=CONVEX_URL=https://<your>.convex.cloud
```

### Convex Auth (email + password)

В проекте включён `@convex-dev/auth` с провайдером **Password**. Сервер узнаёт пользователя по JWT; задачи привязаны к `users` через `getAuthUserId`, а не к строке из клиента.

После `npx @convex-dev/auth` в dev уже должны быть переменные `JWT_PRIVATE_KEY`, `JWKS`, `SITE_URL`. Для **production** deployment скопируй те же переменные в настройки prod в [Convex Dashboard](https://dashboard.convex.dev) (или задай через `npx convex env set` для prod).

Первый вход: на экране логина включи **Create account**, укажи email и пароль (не короче 8 символов). Дальше — **Sign in**.

Без `CONVEX_URL` приложение по-прежнему работает офлайн с парой **demo / demo** (локальные задачи).

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
