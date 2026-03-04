import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'dart:io';

void main() {
  runApp(const SimpleHealthTestApp());
}

class SimpleHealthTestApp extends StatelessWidget {
  const SimpleHealthTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple HealthKit Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SimpleHealthTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SimpleHealthTestScreen extends StatefulWidget {
  const SimpleHealthTestScreen({super.key});

  @override
  State<SimpleHealthTestScreen> createState() => _SimpleHealthTestScreenState();
}

class _SimpleHealthTestScreenState extends State<SimpleHealthTestScreen> {
  final Health _health = Health();
  String _status = 'Готов к тестированию HealthKit';
  bool _isLoading = false;

  // Минимальный набор типов данных для тестирования
  static const List<HealthDataType> _testDataTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.STEPS,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple HealthKit Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.health_and_safety, size: 48, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Информация о платформе
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Платформа: ${Platform.operatingSystem}'),
                    Text('Версия: ${Platform.operatingSystemVersion}'),
                    Text('HealthKit доступен: ${!kIsWeb && (Platform.isIOS || Platform.isAndroid)}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Кнопка тестирования
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testHealthKitPermissions,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.security),
              label: Text(_isLoading ? 'Тестируем...' : 'Тест HealthKit разрешений'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Инструкции
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Инструкции для тестирования:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Нажмите кнопку "Тест HealthKit разрешений"'),
                    const Text('2. Должен появиться системный диалог разрешений'),
                    const Text('3. Разрешите доступ к данным здоровья'),
                    const Text('4. Проверьте результат в статусе выше'),
                    const SizedBox(height: 8),
                    const Text(
                      'Если диалог не появляется:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const Text('• Проверьте Info.plist настройки'),
                    const Text('• Убедитесь что тестируете на реальном iOS устройстве'),
                    const Text('• Проверьте что HealthKit доступен на устройстве'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testHealthKitPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Тестируем HealthKit разрешения...';
    });

    try {
      print('🔐 Начинаем тест HealthKit разрешений...');
      
      // Проверяем платформу
      if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
        setState(() {
          _status = '❌ HealthKit недоступен на этой платформе\n'
                   'Платформа: ${Platform.operatingSystem}\n'
                   'Поддерживаются только iOS и Android';
        });
        print('❌ Неподдерживаемая платформа: ${Platform.operatingSystem}');
        return;
      }
      
      print('✅ Платформа поддерживается: ${Platform.operatingSystem}');
      
      // Проверяем доступность Health
      setState(() {
        _status = 'Проверяем доступность Health API...';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Запрашиваем разрешения
      setState(() {
        _status = 'Запрашиваем разрешения HealthKit...\n'
                 'Должен появиться системный диалог!';
      });
      
      print('🔐 Вызываем requestAuthorization...');
      
      final bool granted = await _health.requestAuthorization(_testDataTypes);
      
      print('🔐 requestAuthorization завершен, результат: $granted');
      
      if (granted) {
        setState(() {
          _status = '✅ УСПЕХ! Разрешения получены!\n'
                   'HealthKit подключен корректно\n'
                   'Системный диалог сработал\n'
                   'Можно переходить к загрузке данных';
        });
        print('✅ HealthKit разрешения успешно получены');
      } else {
        setState(() {
          _status = '❌ Разрешения отклонены пользователем\n'
                   'Системный диалог появился, но пользователь отказал\n'
                   'Откройте Настройки → Конфиденциальность → Здоровье\n'
                   'Найдите приложение и разрешите доступ';
        });
        print('❌ HealthKit разрешения отклонены пользователем');
      }
      
    } catch (e) {
      String errorMessage = _getDetailedErrorMessage(e);
      setState(() {
        _status = errorMessage;
      });
      print('❌ Ошибка при тестировании HealthKit: $e');
      print('❌ Тип ошибки: ${e.runtimeType}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getDetailedErrorMessage(dynamic error) {
    String errorStr = error.toString();
    
    print('🔍 Анализируем ошибку: $errorStr');
    print('🔍 Тип ошибки: ${error.runtimeType}');
    
    if (errorStr.contains('MissingPluginException')) {
      return '❌ КРИТИЧЕСКАЯ ОШИБКА: Плагин недоступен\n'
             'Health плагин не найден или не настроен\n'
             'Платформа: ${Platform.operatingSystem}\n'
             'Проверьте pubspec.yaml и pod install';
    }
    
    if (errorStr.contains('PlatformException')) {
      if (errorStr.contains('PERMISSION_DENIED')) {
        return '❌ Доступ запрещен системой\n'
               'Возможные причины:\n'
               '• HealthKit отключен в настройках устройства\n'
               '• Неправильные настройки Info.plist\n'
               '• Устройство не поддерживает HealthKit';
      }
      
      if (errorStr.contains('HEALTH_NOT_AVAILABLE')) {
        return '❌ HealthKit недоступен на устройстве\n'
               'Возможные причины:\n'
               '• Тестируете на симуляторе (нужно реальное устройство)\n'
               '• HealthKit отключен в настройках\n'
               '• Старая версия iOS';
      }
      
      return '❌ Ошибка платформы\n'
             'PlatformException: $errorStr\n'
             'Проверьте настройки iOS и Info.plist';
    }
    
    if (errorStr.contains('TimeoutException')) {
      return '❌ Превышено время ожидания\n'
             'Системный диалог не появился или завис\n'
             'Попробуйте перезапустить приложение';
    }
    
    // Общая ошибка с техническими деталями
    return '❌ Неизвестная ошибка\n'
           'Тип: ${error.runtimeType}\n'
           'Сообщение: ${errorStr.length > 150 ? errorStr.substring(0, 150) + "..." : errorStr}\n'
           'Обратитесь к разработчику с этой информацией';
  }
}