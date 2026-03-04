# iPhone Testing Guide - Camera HRV POC

## Быстрый старт на iPhone

### Предварительные требования

1. **Xcode установлен** (версия 14.0+)
2. **iPhone подключен** к Mac через USB
3. **Apple Developer аккаунт** (бесплатный или платный)
4. **Flutter настроен** для iOS разработки

---

## Шаг 1: Проверка окружения

```bash
# Проверить Flutter
flutter doctor

# Должно быть:
# [✓] Flutter (Channel stable, 3.38+)
# [✓] Xcode - develop for iOS
# [✓] Connected device (iPhone)
```

Если есть проблемы:
```bash
# Установить/обновить CocoaPods
sudo gem install cocoapods

# Принять лицензии Xcode
sudo xcodebuild -license accept
```

---

## Шаг 2: Подключить iPhone

1. **Подключите iPhone** к Mac через USB
2. **Разблокируйте iPhone**
3. **Доверьтесь компьютеру** (Trust This Computer)

Проверить подключение:
```bash
flutter devices
```

Должно показать:
```
iPhone (mobile) • 00008030-XXXXXXXXXXXX • ios • iOS 16.0
```

---

## Шаг 3: Настроить подписание (Signing)

### Вариант A: Через Flutter (Автоматически)

```bash
# Flutter автоматически настроит подписание
flutter run
```

### Вариант B: Через Xcode (Вручную)

1. **Открыть проект в Xcode**:
```bash
open ios/Runner.xcworkspace
```

2. **Выбрать Runner** в левой панели

3. **Signing & Capabilities**:
   - Team: Выбрать ваш Apple ID
   - Bundle Identifier: `com.atmo.shield` (или уникальный)
   - Automatically manage signing: ✓

4. **Если нет Team**:
   - Xcode → Preferences → Accounts
   - Добавить Apple ID (+)
   - Выбрать Personal Team

---

## Шаг 4: Запустить на iPhone

### Способ 1: Через Flutter CLI (Рекомендуется)

```bash
# Установить зависимости
flutter pub get

# Запустить на iPhone
flutter run

# Или указать конкретное устройство
flutter run -d 00008030-XXXXXXXXXXXX
```

### Способ 2: Через Xcode

1. Открыть `ios/Runner.xcworkspace`
2. Выбрать iPhone в списке устройств (вверху)
3. Нажать ▶️ (Run)

### Способ 3: Через скрипт

```bash
./run_poc.sh
# Выбрать iPhone из списка
```

---

## Шаг 5: Первый запуск на iPhone

### На iPhone появится:

1. **"Untrusted Developer"** предупреждение
   
   **Решение**:
   - Settings → General → VPN & Device Management
   - Найти ваш Apple ID
   - Tap "Trust [Your Apple ID]"
   - Confirm

2. **Разрешения**:
   - Camera access → Allow
   - (Опционально) Health access → Allow

3. **Приложение запустится**

---

## Шаг 6: Тестирование

### Базовый тест

1. ✅ Принять disclaimer
2. ✅ Разрешить камеру
3. ✅ Пройти/пропустить tutorial
4. ✅ Выбрать Quick Mode
5. ✅ Нажать кнопку измерения
6. ✅ Положить палец на камеру + вспышку
7. ✅ Держать 30 секунд
8. ✅ Посмотреть результаты

### Проверка качества

Попробуйте разные объекты:
- ✅ Палец → должно работать
- ❌ Бумага → "Poor" quality
- ❌ Ткань → "Poor" quality
- ❌ Без пальца → "Place finger on camera"

---

## Troubleshooting

### Проблема: "No devices found"

**Решение**:
```bash
# Перезапустить Flutter daemon
flutter devices

# Или перезагрузить iPhone
# Или переподключить USB кабель
```

### Проблема: "Could not find an option named 'device'"

**Решение**:
```bash
# Обновить Flutter
flutter upgrade

# Или использовать полную команду
flutter run --device-id=00008030-XXXXXXXXXXXX
```

### Проблема: "Signing for Runner requires a development team"

**Решение**:
1. Открыть Xcode
2. Runner → Signing & Capabilities
3. Выбрать Team (ваш Apple ID)
4. Изменить Bundle ID если нужно

### Проблема: "The application could not be verified"

**Решение**:
1. iPhone: Settings → General → VPN & Device Management
2. Trust your developer certificate

### Проблема: "Camera permission denied"

**Решение**:
1. iPhone: Settings → Privacy → Camera
2. Найти "ATMO Shield Premium"
3. Enable

### Проблема: "Build failed" в Xcode

**Решение**:
```bash
# Очистить build
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

# Или через Flutter
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter run
```

---

## Hot Reload во время разработки

Пока приложение запущено на iPhone:

```bash
# В терминале где запущен flutter run:
r  # Hot reload (быстро)
R  # Hot restart (полная перезагрузка)
q  # Quit
```

Или в IDE:
- VS Code: ⚡ Hot Reload button
- Android Studio: ⚡ Hot Reload button

---

## Отладка (Debugging)

### Просмотр логов

```bash
# В терминале где запущен flutter run
# Логи будут показываться автоматически

# Или отдельно:
flutter logs
```

### Debug в Xcode

1. Открыть `ios/Runner.xcworkspace`
2. Run с Xcode
3. View → Debug Area → Show Debug Area
4. Смотреть console output

### Flutter DevTools

```bash
# Запустить DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Откроется браузер с инструментами
```

---

## Производительность на iPhone

### Ожидаемые показатели

- **FPS**: ~10-15 (зависит от модели iPhone)
- **Обработка кадра**: <50ms
- **Память**: <100MB
- **Батарея**: ~5-10% за измерение

### Проверка FPS

Добавьте в код (временно):
```dart
// В CameraService._processImage
debugPrint('FPS: ${_frameCount / elapsed.inSeconds}');
```

---

## Тестирование с Polar H10

Если у вас есть Polar H10:

1. **Подключить Polar H10** к iPhone через Bluetooth
2. **Запустить Polar Beat** app
3. **Начать запись** в Polar Beat
4. **Одновременно** запустить измерение в ATMO
5. **Сравнить результаты**:
   - BPM должен быть ±5 BPM
   - RMSSD должен быть ±10-15ms

---

## Полезные команды

```bash
# Список устройств
flutter devices

# Запуск на конкретном устройстве
flutter run -d <device-id>

# Запуск в release режиме (быстрее)
flutter run --release

# Очистка
flutter clean

# Обновление зависимостей
flutter pub get
cd ios && pod install && cd ..

# Проверка проблем
flutter doctor -v

# Просмотр логов
flutter logs

# Скриншот
flutter screenshot
```

---

## Checklist перед тестированием

- [ ] iPhone подключен и разблокирован
- [ ] Trust This Computer выполнен
- [ ] Xcode установлен и настроен
- [ ] Flutter doctor показывает ✓ для iOS
- [ ] CocoaPods установлен
- [ ] Developer certificate trusted на iPhone
- [ ] Camera permission будет запрошено
- [ ] Достаточно заряда батареи (>50%)

---

## Быстрый старт (TL;DR)

```bash
# 1. Подключить iPhone
# 2. Разблокировать и Trust

# 3. Запустить
flutter pub get
cd ios && pod install && cd ..
flutter run

# 4. На iPhone: Trust developer certificate
# 5. Разрешить камеру
# 6. Тестировать!
```

---

## Что тестировать

### Функциональность
- [ ] Disclaimer показывается
- [ ] Camera permission работает
- [ ] Tutorial показывается
- [ ] Quick Mode (30s) работает
- [ ] Accurate Mode (60s) работает
- [ ] Breathing metronome анимируется
- [ ] Quality indicator обновляется
- [ ] Waveform отображается
- [ ] Results screen показывает BPM
- [ ] Results screen показывает RMSSD (Accurate)
- [ ] Save сохраняет результат
- [ ] Last measurement показывается

### Качество детекции
- [ ] Палец детектируется → Good/Fair
- [ ] Бумага → Poor
- [ ] Без пальца → Poor
- [ ] Слишком сильное давление → Poor
- [ ] Движение → Fair/Poor + "Keep still"

### Производительность
- [ ] Нет лагов в UI
- [ ] Camera preview плавный
- [ ] Waveform обновляется
- [ ] Не перегревается
- [ ] Батарея не садится быстро

---

## Следующие шаги

После успешного запуска:
1. ✅ Выполнить базовые тесты
2. ✅ Записать результаты в TESTING_GUIDE.md
3. ✅ Сравнить с Polar H10 (если есть)
4. ✅ Протестировать разные условия
5. ✅ Документировать проблемы

---

**Готово к тестированию на iPhone!** 📱✨
