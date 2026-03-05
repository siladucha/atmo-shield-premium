# ATMO Shield Integration Guide

## Интеграция Shield PoC в основной ATMO репозиторий

### 1. Файлы для копирования в основной ATMO:

#### Flutter код:
```
lib/features/shield/
├── screens/
│   └── poc_screen.dart              # Готовый PoC экран
├── services/
│   ├── health_data_service.dart     # HealthKit интеграция
│   ├── shield_service.dart          # Основная логика Shield
│   └── notification_service.dart    # Уведомления
├── models/
│   ├── hrv_reading.dart            # Модель HRV данных
│   ├── stress_event.dart           # Модель стресс-событий
│   └── baseline_data.dart          # Модель базовых показателей
└── widgets/
    ├── shield_status_card.dart     # UI компоненты
    ├── recent_events_list.dart
    └── quick_actions_panel.dart
```

#### iOS конфигурация:
```
ios/Runner/Info.plist - добавить HealthKit permissions
```

#### Зависимости:
```yaml
# Добавить в pubspec.yaml основного ATMO:
dependencies:
  health: ^10.2.0
  permission_handler: ^11.3.0
  hive: ^2.2.3
  fl_chart: ^0.68.0
```

### 2. Изменения в основном ATMO:

#### Навигация (lib/main.dart):
```dart
// Добавить маршрут Shield
'/shield': (context) => ShieldPremiumScreen(),

// Обновить BottomNavigationBar
BottomNavigationBarItem(
  icon: Stack(
    children: [
      Icon(Icons.shield),
      if (!PremiumService().hasShieldAccess())
        Positioned(right: 0, child: Icon(Icons.lock, size: 12)),
    ],
  ), 
  label: 'Shield'
),
```

#### Премиум-система:
```dart
// lib/core/premium/premium_service.dart
class PremiumService {
  static const String SHIELD_FEATURE = 'atmo_shield_premium';
  
  bool hasShieldAccess() {
    return _purchaseService.hasPurchased(SHIELD_FEATURE);
  }
  
  Future<bool> purchaseShield() async {
    return await _purchaseService.purchase(SHIELD_FEATURE, 9.99);
  }
}
```

#### Shield экран-обертка:
```dart
// lib/features/shield/shield_premium_screen.dart
class ShieldPremiumScreen extends StatelessWidget {
  Widget build(BuildContext context) {
    if (!PremiumService().hasShieldAccess()) {
      return ShieldUpgradeScreen(); // Экран покупки
    }
    return PoCScreen(); // Готовый PoC экран
  }
}
```

### 3. Пользовательский опыт:

**Существующие пользователи v1.4.1:**
1. Обновляются до v1.5.0
2. Видят новую вкладку "Shield" 
3. При нажатии видят предложение купить Shield Premium за $9.99
4. После покупки получают полный доступ к Shield функциям

**Новые пользователи:**
1. Скачивают ATMO v1.5.0
2. Получают базовые функции бесплатно
3. Могут купить Shield Premium как дополнение

### 4. Тестирование:

- Регрессионное тестирование существующих функций ATMO
- Тестирование Shield функциональности
- Тестирование премиум-системы и покупок
- TestFlight бета-тестирование

### 5. Релиз:

- Обновление App Store описания
- Добавление скриншотов Shield функций
- Маркетинг Shield Premium возможностей