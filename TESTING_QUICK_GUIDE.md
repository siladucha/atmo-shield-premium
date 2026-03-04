# Быстрая Инструкция по Тестированию v1.2

## 🚀 Запуск

```bash
flutter run
```

---

## ✅ Тест 1: BPM Accuracy (2 минуты)

1. Запустить **Quick Mode** (30s)
2. Приложить палец к камере
3. Держать стабильно 30 секунд
4. **Проверить:**
   - ✅ BPM: 60-90 (не 125!)
   - ✅ Peaks: 20-30 (не 42!)
   - ✅ Quality: Good/Fair

**Ожидаемый результат:**
```
BPM: 75 ✅
Peaks detected: 25 ✅
Quality: Good ✅
```

---

## ✅ Тест 2: HRV Reliability (2 минуты)

1. Запустить **Accurate Mode** (60s)
2. Приложить палец к камере
3. Держать стабильно 60 секунд
4. **Проверить:**
   - ✅ HRV рассчитан (не null)
   - ✅ IBIs: 15-25 (не 6!)
   - ✅ RMSSD: 30-80 ms

**Ожидаемый результат:**
```
BPM: 75 ✅
HRV: 45 ms ✅
Valid IBIs: 19 ✅
Quality: Good ✅
```

---

## ✅ Тест 3: Сравнение с Apple Watch (5 минут)

1. Надеть Apple Watch
2. Запустить Breathe app на Watch
3. Одновременно запустить ATMO Shield
4. **Сравнить:**
   - BPM: разница ±10 ✅
   - HRV: разница ±20ms ✅

**Пример:**
```
Apple Watch: BPM 72, HRV 48 ms
ATMO Shield:  BPM 75, HRV 45 ms
Difference:   ±3 BPM, ±3 ms ✅ GOOD!
```

---

## 📊 Что Смотреть в Логах

```bash
# Открыть логи
cat test/lastlog.txt

# Искать:
Detected XX peaks          # Должно быть 20-30
Calculated BPM: XX         # Должно быть 60-90
Calculated RMSSD: XX ms    # Должно быть 30-80
from XX filtered IBIs      # Должно быть 15-25
```

---

## ⚠️ Если Что-то Не Так

### BPM все еще завышен (>100):
- Проверить логи: сколько пиков?
- Если >35 пиков → нужен band-pass фильтр

### HRV не рассчитывается:
- Проверить логи: сколько IBIs?
- Если <15 IBIs → плохой сигнал, повторить

### Quality всегда Poor:
- Проверить палец: полностью закрывает камеру?
- Проверить давление: не слишком сильно?

---

## 📝 Записать Результаты

```
Test 1 (Quick Mode):
- BPM: ___
- Peaks: ___
- Quality: ___

Test 2 (Accurate Mode):
- BPM: ___
- HRV: ___
- IBIs: ___
- Quality: ___

Test 3 (vs Apple Watch):
- ATMO BPM: ___
- Watch BPM: ___
- Difference: ___
- ATMO HRV: ___
- Watch HRV: ___
- Difference: ___
```

---

## 🎯 Критерии Успеха

- ✅ BPM в диапазоне 60-90
- ✅ Peaks в диапазоне 20-30
- ✅ HRV рассчитывается (не null)
- ✅ IBIs >= 15
- ✅ Разница с Apple Watch ±10 BPM, ±20ms HRV

**Если все ✅ → POC готов к Phase 2!**

---

**Время тестирования:** 10 минут
**Версия:** v1.2 (2026-03-04)
