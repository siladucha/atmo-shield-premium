# Algorithm Implementation Status

## Что планировалось vs Что реализовано

### 📊 Сводная таблица

| Компонент | Планировалось (Spec) | Реализовано (POC) | Статус |
|-----------|---------------------|-------------------|--------|
| **Фильтрация** | Butterworth 4-го порядка, 0.8-4.0 Hz | Moving Average (окно 5) | ⚠️ Упрощено |
| **Детекция пиков** | Адаптивный порог + параболическая интерполяция | Адаптивный порог (mean + 20% amplitude) | ⚠️ Частично |
| **Удаление артефактов** | 3σ outlier removal + cubic spline | Не реализовано | ❌ Отложено |
| **Качество сигнала** | 5 уровней (1-5) | 3 уровня (poor/fair/good) | ⚠️ Упрощено |
| **Детекция пальца** | Яркость + variance + цветовые соотношения + движение | Яркость + variance + история | ⚠️ Частично |
| **BPM расчет** | 60000 / mean(IBI), валидация 30-220 | 60000 / mean(IBI), валидация 30-220 | ✅ Полностью |
| **RMSSD расчет** | sqrt(mean(diff²)), валидация 10-150ms | sqrt(mean(diff²)), валидация 10-150ms | ✅ Полностью |
| **SDNN расчет** | std(IBI) | Не реализовано | ❌ Отложено |
| **FPS** | 30 (Quick) / 60 (Accurate) | ~10 FPS | ❌ Низкий |
| **ROI** | 5% сенсора, 80-150px, центр | 5% сенсора, 80-150px, центр | ✅ Полностью |
| **Цветовые каналы** | RGB extraction + соотношения | Только Green (R/B вычисляются но не используются) | ⚠️ Частично |

---

## Детальный анализ

### 1. Фильтрация сигнала

#### Планировалось (Requirements 4, Design)
```
Butterworth bandpass filter:
- Order: 4
- Passband: 0.8-4.0 Hz (48-240 BPM)
- Zero-phase filtering (filtfilt)
- Artifact removal: 3σ outlier detection
- Cubic spline interpolation
```

#### Реализовано
```dart
// Moving average filter
List<double> applyMovingAverageFilter(List<double> signal, {int windowSize = 5}) {
  // Simple averaging over window
  // No frequency-domain filtering
  // No artifact removal
}
```

#### Проблемы
- ❌ Нет частотной фильтрации (пропускает шум вне 0.8-4.0 Hz)
- ❌ Нет zero-phase (может сдвигать пики)
- ❌ Нет удаления артефактов (движение = плохой результат)
- ⚠️ Слишком простой для точных измерений

#### Влияние на точность
- Ожидаемое снижение BPM correlation: 0.90 → 0.75-0.80
- Ожидаемое снижение RMSSD correlation: 0.85 → 0.65-0.70
- Высокая чувствительность к движению

---

### 2. Детекция пиков

#### Планировалось (Requirements 5)
```
- Adaptive threshold: 60% of amplitude range
- Minimum separation: 250ms (240 BPM max)
- Parabolic interpolation for sub-sample accuracy
- Peak validation
```

#### Реализовано
```dart
// Adaptive threshold: mean + 20% amplitude
double threshold = mean + (amplitude * 0.2);

// Minimum separation: 250ms ✓
int minSeparation = (samplingRate * 0.25).round();

// Simple peak detection (no interpolation)
if (signal[i] > threshold &&
    signal[i] > signal[i - 1] &&
    signal[i] > signal[i + 1]) {
  peaks.add(i);
}
```

#### Проблемы
- ❌ Нет параболической интерполяции (точность ±1 sample)
- ⚠️ Порог 20% вместо 60% (может быть слишком низким)
- ✅ Минимальное расстояние реализовано правильно

#### Влияние на точность
- Точность пиков: ±100ms при 10 FPS (вместо ±10ms)
- Может пропускать слабые пики
- Может детектировать ложные пики при шуме

---

### 3. Качество сигнала

#### Планировалось (Requirements 3)
```
5 уровней:
1. No finger (brightness <20% or >80%)
2. Overpressure (variance <2.0)
3. Weak blood flow (R/G <0.6 or B/G <0.5)
4. Movement (variance >15.0 or accel >0.5 m/s²)
5. Good signal (autocorrelation >0.3, ≥60 samples)
```

#### Реализовано
```dart
3 уровня:
- Poor: brightness out of range OR variance <2.0
- Fair: variance 2.0-5.0 OR movement detected
- Good: variance ≥5.0

Проверки:
✓ Brightness range (20%-80%)
✓ Variance threshold
✓ Adaptive baseline calibration
✓ Temporal stability (movement)
✗ Color ratios (вычисляются но не используются)
✗ Autocorrelation
✗ Accelerometer
```

#### Проблемы
- ❌ Нет проверки цветовых соотношений (не детектирует не-палец)
- ❌ Нет автокорреляции (не проверяет периодичность)
- ❌ Нет акселерометра (не детектирует мелкие движения)
- ⚠️ Упрощенная логика может давать false positives

#### Влияние на UX
- Может показывать "Good" для плохого сигнала
- Не различает "нет пальца" vs "плохой контакт"
- Нет специфичных подсказок для разных проблем

---

### 4. Детекция пальца

#### Планировалось
```
Многофакторная проверка:
1. Brightness: 20-80% baseline
2. Variance: >2.0 (пульсация)
3. R/G ratio: >0.6 (кровь)
4. B/G ratio: >0.5 (кровь)
5. Temporal stability
6. Autocorrelation
```

#### Реализовано
```dart
Частичная проверка:
✓ Brightness: 20-80% baseline
✓ Variance: >2.0
✓ Adaptive baseline
✓ Temporal stability (история 10 samples)
✗ Color ratios (код есть, но не вызывается)
✗ Autocorrelation
```

#### Критическая проблема
```dart
// В CameraService только Green извлекается
Map<String, dynamic> _extractGreenMean(CameraImage image) {
  // ...
  final int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
  final int g = (yValue - 0.344136 * uValue - 0.714136 * vValue)...
  final int b = (yValue + 1.772 * uValue).round().clamp(0, 255);
  
  // НО: только g используется!
  greenValues.add(g.toDouble());
  sumGreen += g;
  // r и b вычисляются но не возвращаются
}

// В QualityValidator
QualityLevel assessQuality(
  double meanBrightness,
  double variance, {
  double? redMean,    // Всегда null!
  double? blueMean,   // Всегда null!
}) {
  // Проверка цветов никогда не выполняется
  if (redMean != null && blueMean != null && meanBrightness > 0) {
    // Этот код недостижим
  }
}
```

#### Влияние
- ❌ Не может отличить палец от других объектов
- ❌ Может принять бумагу/ткань за палец
- ❌ Не детектирует слабый кровоток

---

### 5. Frame Rate

#### Планировалось
```
Quick Mode: 30 FPS
Accurate Mode: 60 FPS
```

#### Реализовано
```
~10 FPS (зависит от устройства)
```

#### Проблемы
- ❌ Низкий FPS = низкая точность пиков
- ❌ Недостаточно для точного RMSSD
- ❌ Не различается между режимами

#### Влияние на точность
- При 10 FPS: точность пиков ±100ms
- При 30 FPS: точность пиков ±33ms
- При 60 FPS: точность пиков ±16ms

Для RMSSD критично: ошибка ±100ms → ошибка RMSSD ~20-30%

---

## Что работает хорошо ✅

1. **BPM расчет** - правильная формула, валидация
2. **RMSSD расчет** - правильная формула, валидация
3. **ROI extraction** - правильный размер и позиция
4. **Adaptive baseline** - калибруется под пользователя
5. **Temporal history** - отслеживает стабильность
6. **UI feedback** - показывает качество в реальном времени

---

## Критические недостатки ❌

### 1. Нет цветовой проверки (КРИТИЧНО)
```dart
// ПРОБЛЕМА: R и B вычисляются но не используются
// РЕШЕНИЕ: Добавить в return:
return {
  'meanGreen': meanGreen,
  'meanRed': meanRed,      // ← Добавить
  'meanBlue': meanBlue,    // ← Добавить
  'variance': variance,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
};
```

### 2. Низкий FPS (КРИТИЧНО для RMSSD)
```
Текущий: ~10 FPS
Нужно: 30 FPS (Quick), 60 FPS (Accurate)
```

### 3. Нет Butterworth фильтра (ВАЖНО)
```
Текущий: Moving average
Нужно: Butterworth 4-го порядка, 0.8-4.0 Hz
```

### 4. Нет удаления артефактов (ВАЖНО)
```
Текущий: Нет обработки выбросов
Нужно: 3σ outlier removal + cubic spline
```

### 5. Нет параболической интерполяции (СРЕДНЕ)
```
Текущий: Целочисленные индексы пиков
Нужно: Sub-sample точность
```

---

## Ожидаемая точность POC

### Оптимистичный сценарий (идеальные условия)
- BPM correlation: 0.75-0.80 (цель: 0.85)
- RMSSD correlation: 0.60-0.70 (цель: 0.75)
- Success rate: 50-60% (цель: 60%)

### Реалистичный сценарий (обычные условия)
- BPM correlation: 0.70-0.75
- RMSSD correlation: 0.50-0.65
- Success rate: 40-50%

### Пессимистичный сценарий (сложные условия)
- BPM correlation: 0.60-0.70
- RMSSD correlation: 0.40-0.55
- Success rate: 30-40%

---

## Приоритеты для v1.1

### P0 (Критично для достижения целей)
1. ✅ **Добавить цветовые каналы в CameraService**
   - Вернуть meanRed, meanBlue
   - Использовать в QualityValidator
   
2. ✅ **Увеличить FPS до 30/60**
   - Оптимизировать обработку
   - Или native plugin

3. ✅ **Butterworth фильтр**
   - Заменить moving average
   - 0.8-4.0 Hz bandpass

### P1 (Важно для точности)
4. ✅ **Удаление артефактов**
   - 3σ outlier detection
   - Cubic spline interpolation

5. ✅ **Параболическая интерполяция пиков**
   - Sub-sample точность

### P2 (Улучшение UX)
6. ⚠️ **5-уровневая система качества**
   - Более детальная обратная связь
   
7. ⚠️ **Автокорреляция**
   - Проверка периодичности сигнала

---

## Выводы

### Что реализовано правильно
- ✅ Базовая архитектура
- ✅ Математика BPM/RMSSD
- ✅ ROI extraction
- ✅ Adaptive baseline
- ✅ UI/UX flow

### Что критично не хватает
- ❌ Цветовые каналы не используются
- ❌ FPS слишком низкий
- ❌ Фильтрация слишком простая
- ❌ Нет удаления артефактов

### Можно ли достичь целей?
**BPM (цель 0.85)**: Возможно 0.75-0.80 при идеальных условиях
**RMSSD (цель 0.75)**: Маловероятно, ожидается 0.60-0.70
**Success rate (цель 60%)**: Возможно 50-60% при хороших условиях

### Рекомендация
**Proceed with validation**, но с пониманием что:
1. Результаты будут ниже целевых
2. Нужна итерация для достижения целей
3. Критично исправить цветовые каналы перед тестированием

---

**Дата**: 2026-03-04  
**Статус**: POC готов, но с известными ограничениями
