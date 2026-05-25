# FurClient — Fur Affinity Client

Кроссплатформенный клиент для Fur Affinity на React Native.

## Платформы

| Платформа | Технология | Бинарник |
|---|---|---|
| Windows | Electron | `npm run electron:build:win` → EXE |
| macOS | Electron | `npm run electron:build:mac` → DMG |
| Linux | Electron | `npm run electron:build:linux` → AppImage |
| Android | Capacitor | `cd android && ./gradlew assembleRelease` → APK |

## Команды

```bash
# Установка
npm install

# Веб-сборка (общая для всех десктоп-платформ)
npm run web:build

# Linux
npm run electron:build:linux

# Android
cd android && ./gradlew assembleDebug

# Разработка
npm run web:dev          # браузер
npm run electron:dev     # Electron окно
```

## Структура

```
src/           — React Native код (общий)
electron/      — Electron main process
android/       — Capacitor Android проект
web-build/     — собранные веб-ресурсы (gitignored)
dist-electron/ — Electron бинарники (gitignored)
```

## Git workflow

```bash
git add .
git commit -m "что сделано"
git push          # залить на GitHub
git pull          # скачать изменения
```
