#!/usr/bin/env bash
# Стабильный порт 8080 → одно и то же localStorage при каждом запуске.
set -e
cd "$(dirname "$0")/.."
exec flutter run -d chrome --web-port=8080 --dart-define-from-file=config/dart_defines/dev.json
