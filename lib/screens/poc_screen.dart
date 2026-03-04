import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PoCScreen extends StatefulWidget {
  const PoCScreen({super.key});

  @override
  State<PoCScreen> createState() => _PoCScreenState();
}

class _PoCScreenState extends State<PoCScreen> {
  final Health _health = Health();
  List<HealthDataPoint> _healthData = [];
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  String _loadingMessage = '';
  String _status = 'Готов к запросу данных HealthKit';
  
  // Все типы данных которые мы хотим получить
  static const List<HealthDataType> _dataTypes = [
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.RESPIRATORY_RATE,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ATMO Shield PoC'),
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
            
            // Кнопки управления
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _requestPermissions,
              icon: const Icon(Icons.security),
              label: const Text('Запросить доступ к HealthKit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchAllHealthData,
              icon: const Icon(Icons.download),
              label: const Text('Загрузить ВСЕ данные Health'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _analyzeData,
              icon: const Icon(Icons.analytics),
              label: const Text('Анализировать тренды (ВАШ АЛГОРИТМ)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Данные
            Expanded(
              child: _isLoading
                  ? _buildLoadingScreen()
                  : _healthData.isEmpty
                      ? const Center(
                          child: Text(
                            'Нет данных.\nНажмите кнопки выше для получения данных HealthKit.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _healthData.length,
                          itemBuilder: (context, index) {
                            final data = _healthData[index];
                            return Card(
                              child: ListTile(
                                leading: _getIconForDataType(data.type),
                                title: Text(_getDisplayName(data.type)),
                                subtitle: Text(
                                  'Значение: ${_formatValue(data)}\n'
                                  'Время: ${_formatDate(data.dateFrom)}\n'
                                  'Источник: ${data.sourceName ?? "Неизвестно"}',
                                ),
                                trailing: _getStatusIcon(data),
                              ),
                            );
                          },
                        ),
            ),
            
            // Статистика внизу
            if (_healthData.isNotEmpty)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Статистика данных',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Всего записей: ${_healthData.length}'),
                      Text('Типов данных: ${_getUniqueDataTypes().length}'),
                      Text('Период: ${_getDataPeriod()}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
      _loadingMessage = 'Инициализация...';
      _status = 'Запрашиваем разрешения HealthKit...';
    });

    try {
      print('🔐 Запрашиваем разрешения HealthKit...');
      
      // Симуляция прогресса
      await _updateProgress(0.2, 'Проверяем доступность HealthKit...');
      
      // Проверяем платформу - Health плагин работает только на iOS/Android
      if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await _updateProgress(0.5, 'Активируем тестовый режим...');
        await Future.delayed(const Duration(milliseconds: 800));
        await _updateProgress(1.0, 'Готово!');
        
        setState(() {
          _status = '✅ Тестовый режим активен\n'
                   'Платформа: ${Platform.operatingSystem.toUpperCase()}\n'
                   'HealthKit недоступен, используем мок-данные';
        });
        print('✅ Тестовый режим - разрешения имитированы для ${Platform.operatingSystem}');
        return;
      }
      
      await _updateProgress(0.4, 'Запрашиваем разрешения...');
      
      final bool granted = await _health.requestAuthorization(_dataTypes);
      
      await _updateProgress(0.8, 'Обрабатываем ответ...');
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateProgress(1.0, 'Завершено!');
      
      if (granted) {
        setState(() {
          _status = '✅ Разрешения получены!\n'
                   'HealthKit подключен успешно\n'
                   'Можно загружать реальные данные';
        });
        print('✅ HealthKit разрешения получены');
      } else {
        setState(() {
          _status = '❌ Доступ к HealthKit отклонен\n'
                   'Откройте Настройки → Конфиденциальность → Здоровье\n'
                   'Разрешите доступ для ATMO Shield';
        });
        print('❌ HealthKit разрешения отклонены пользователем');
      }
    } catch (e) {
      String errorMessage = _getDetailedErrorMessage(e);
      setState(() {
        _status = errorMessage;
      });
      print('❌ Ошибка запроса разрешений: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _loadingProgress = 0.0;
        _loadingMessage = '';
      });
    }
  }

  Future<void> _fetchAllHealthData() async {
    setState(() {
      _isLoading = true;
      _status = 'Загружаем данные из HealthKit...';
    });

    try {
      print('📊 Загружаем данные из HealthKit...');
      
      // Для тестирования на неподдерживаемых платформах
      if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        await Future.delayed(const Duration(seconds: 2));
        _healthData = _generateMockHealthData();
        setState(() {
          _status = '✅ Загружены тестовые данные\n'
                   'Записей: ${_healthData.length}\n'
                   'Это демо-данные для тестирования UI';
        });
        print('✅ Загружены мок-данные: ${_healthData.length} записей');
        return;
      }
      
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      final List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: thirtyDaysAgo,
        endTime: now,
      );
      
      setState(() {
        _healthData = healthData;
        if (healthData.isEmpty) {
          _status = '⚠️ Данные не найдены\n'
                   'Возможные причины:\n'
                   '• Нет данных за последние 30 дней\n'
                   '• Не все разрешения предоставлены\n'
                   '• Данные не синхронизированы с HealthKit';
        } else {
          _status = '✅ Данные загружены успешно\n'
                   'Записей: ${healthData.length}\n'
                   'Период: последние 30 дней';
        }
      });
      
      print('✅ Загружено ${healthData.length} записей из HealthKit');
      
      // Выводим статистику по типам данных
      final Map<HealthDataType, int> typeCount = {};
      for (final point in healthData) {
        typeCount[point.type] = (typeCount[point.type] ?? 0) + 1;
      }
      
      print('📈 Статистика по типам данных:');
      typeCount.forEach((type, count) {
        print('  ${_getDisplayName(type)}: $count записей');
      });
      
    } catch (e) {
      String errorMessage = _getDetailedErrorMessage(e);
      setState(() {
        _status = errorMessage;
      });
      print('❌ Ошибка загрузки данных: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeData() async {
    if (_healthData.isEmpty) {
      setState(() {
        _status = '❌ Нет данных для анализа\n'
                 'Сначала загрузите данные кнопкой выше\n'
                 'Или проверьте разрешения HealthKit';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Анализируем данные вашим алгоритмом...';
    });

    try {
      print('🧠 Запускаем анализ данных...');
      
      // Имитируем ваш алгоритм анализа
      await Future.delayed(const Duration(seconds: 2));
      
      // Простой анализ HRV данных
      final hrvData = _healthData
          .where((d) => d.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN)
          .toList();
      
      final heartRateData = _healthData
          .where((d) => d.type == HealthDataType.HEART_RATE)
          .toList();
      
      final stepsData = _healthData
          .where((d) => d.type == HealthDataType.STEPS)
          .toList();
      
      String analysis = '🧠 АНАЛИЗ ЗАВЕРШЕН:\n\n';
      
      if (hrvData.isNotEmpty) {
        final avgHRV = hrvData
            .map((d) => (d.value as NumericHealthValue).numericValue)
            .reduce((a, b) => a + b) / hrvData.length;
        analysis += '❤️ HRV: ${avgHRV.toStringAsFixed(1)}ms (среднее за ${hrvData.length} измерений)\n';
        
        if (avgHRV > 30) {
          analysis += '✅ HRV в норме - низкий уровень стресса\n';
        } else if (avgHRV > 20) {
          analysis += '⚠️ HRV умеренно снижен - средний стресс\n';
        } else {
          analysis += '🔴 HRV значительно снижен - высокий стресс\n';
        }
      } else {
        analysis += '⚠️ HRV данные отсутствуют\n';
      }
      
      if (heartRateData.isNotEmpty) {
        final avgHR = heartRateData
            .map((d) => (d.value as NumericHealthValue).numericValue)
            .reduce((a, b) => a + b) / heartRateData.length;
        analysis += '💓 ЧСС: ${avgHR.toStringAsFixed(0)} уд/мин (среднее за ${heartRateData.length} измерений)\n';
        
        if (avgHR < 60) {
          analysis += '✅ Пульс в норме - хорошее восстановление\n';
        } else if (avgHR < 80) {
          analysis += '⚠️ Пульс умеренно повышен\n';
        } else {
          analysis += '🔴 Пульс повышен - возможен стресс\n';
        }
      } else {
        analysis += '⚠️ Данные пульса отсутствуют\n';
      }
      
      if (stepsData.isNotEmpty) {
        final totalSteps = stepsData
            .map((d) => (d.value as NumericHealthValue).numericValue)
            .reduce((a, b) => a + b);
        final avgStepsPerDay = totalSteps / 30; // за 30 дней
        analysis += '🚶 Шаги: ${totalSteps.toStringAsFixed(0)} всего, ${avgStepsPerDay.toStringAsFixed(0)}/день\n';
        
        if (avgStepsPerDay >= 10000) {
          analysis += '✅ Отличная активность!\n';
        } else if (avgStepsPerDay >= 7000) {
          analysis += '⚠️ Хорошая активность\n';
        } else {
          analysis += '🔴 Низкая активность - нужно больше движения\n';
        }
      } else {
        analysis += '⚠️ Данные о шагах отсутствуют\n';
      }
      
      analysis += '\n🎯 ПЕРСОНАЛЬНЫЕ РЕКОМЕНДАЦИИ:\n';
      
      if (hrvData.isNotEmpty) {
        final avgHRV = hrvData
            .map((d) => (d.value as NumericHealthValue).numericValue)
            .reduce((a, b) => a + b) / hrvData.length;
        
        if (avgHRV <= 20) {
          analysis += '🔴 ВЫСОКИЙ СТРЕСС:\n';
          analysis += '• Дыхательные упражнения 4-7-8 (3 раза в день)\n';
          analysis += '• Медитация 15-20 минут\n';
          analysis += '• Избегайте кофеина после 14:00\n';
          analysis += '• Ранний сон (до 22:00)\n';
        } else if (avgHRV <= 30) {
          analysis += '⚠️ УМЕРЕННЫЙ СТРЕСС:\n';
          analysis += '• Дыхательные упражнения 5-5 (2 раза в день)\n';
          analysis += '• Медитация 10-15 минут\n';
          analysis += '• Прогулка на свежем воздухе 30 мин\n';
        } else {
          analysis += '✅ НИЗКИЙ СТРЕСС:\n';
          analysis += '• Поддерживайте текущий режим\n';
          analysis += '• Легкие дыхательные упражнения\n';
          analysis += '• Регулярная физическая активность\n';
        }
      } else {
        analysis += '• Включите измерение HRV в Apple Watch\n';
        analysis += '• Используйте приложение "Дыхание"\n';
        analysis += '• Регулярные прогулки и медитация\n';
      }
      
      setState(() {
        _status = analysis;
      });
      
      print('✅ Анализ завершен успешно');
      
    } catch (e) {
      String errorMessage = _getDetailedErrorMessage(e);
      setState(() {
        _status = errorMessage;
      });
      print('❌ Ошибка анализа: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Icon _getIconForDataType(HealthDataType type) {
    switch (type) {
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        return const Icon(Icons.favorite, color: Colors.red);
      case HealthDataType.HEART_RATE:
        return const Icon(Icons.monitor_heart, color: Colors.pink);
      case HealthDataType.RESTING_HEART_RATE:
        return const Icon(Icons.hotel, color: Colors.blue);
      case HealthDataType.STEPS:
        return const Icon(Icons.directions_walk, color: Colors.green);
      case HealthDataType.SLEEP_ASLEEP:
        return const Icon(Icons.bedtime, color: Colors.indigo);
      case HealthDataType.BLOOD_OXYGEN:
        return const Icon(Icons.air, color: Colors.cyan);
      default:
        return const Icon(Icons.health_and_safety, color: Colors.grey);
    }
  }

  String _getDisplayName(HealthDataType type) {
    switch (type) {
      case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        return 'HRV (SDNN)';
      case HealthDataType.HEART_RATE:
        return 'Пульс';
      case HealthDataType.RESTING_HEART_RATE:
        return 'Пульс покоя';
      case HealthDataType.STEPS:
        return 'Шаги';
      case HealthDataType.SLEEP_ASLEEP:
        return 'Сон';
      case HealthDataType.BLOOD_OXYGEN:
        return 'Кислород крови';
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        return 'Активные калории';
      case HealthDataType.BASAL_ENERGY_BURNED:
        return 'Базовые калории';
      case HealthDataType.RESPIRATORY_RATE:
        return 'Дыхание';
      default:
        return type.name;
    }
  }

  String _formatValue(HealthDataPoint data) {
    if (data.value is NumericHealthValue) {
      final value = (data.value as NumericHealthValue).numericValue;
      switch (data.type) {
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          return '${value.toStringAsFixed(1)} мс';
        case HealthDataType.HEART_RATE:
        case HealthDataType.RESTING_HEART_RATE:
          return '${value.toStringAsFixed(0)} уд/мин';
        case HealthDataType.STEPS:
          return '${value.toStringAsFixed(0)} шагов';
        case HealthDataType.BLOOD_OXYGEN:
          return '${value.toStringAsFixed(1)}%';
        default:
          return value.toStringAsFixed(2);
      }
    }
    return data.value.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Icon _getStatusIcon(HealthDataPoint data) {
    // Простая логика для определения статуса
    if (data.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
      final value = (data.value as NumericHealthValue).numericValue;
      if (value > 30) {
        return const Icon(Icons.check_circle, color: Colors.green);
      } else {
        return const Icon(Icons.warning, color: Colors.orange);
      }
    }
    return const Icon(Icons.info, color: Colors.blue);
  }

  Set<HealthDataType> _getUniqueDataTypes() {
    return _healthData.map((d) => d.type).toSet();
  }

  String _getDataPeriod() {
    if (_healthData.isEmpty) return 'Нет данных';
    
    final dates = _healthData.map((d) => d.dateFrom).toList()..sort();
    final earliest = dates.first;
    final latest = dates.last;
    
    return '${_formatDate(earliest)} - ${_formatDate(latest)}';
  }

  Future<void> _updateProgress(double progress, String message) async {
    setState(() {
      _loadingProgress = progress;
      _loadingMessage = message;
    });
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Анимированный индикатор прогресса
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Фоновый круг
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade300),
                    ),
                  ),
                  // Прогресс
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _loadingProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  // Процент в центре
                  Text(
                    '${(_loadingProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Сообщение о прогрессе
            Text(
              _loadingMessage,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Линейный прогресс-бар
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade300,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _loadingProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Дополнительная информация
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 24),
                  SizedBox(height: 8),
                  Text(
                    'Подключаемся к HealthKit...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Это может занять несколько секунд',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDetailedErrorMessage(dynamic error) {
    String errorStr = error.toString();
    
    if (errorStr.contains('MissingPluginException')) {
      return '❌ Плагин недоступен\n'
             'Health плагин не поддерживается на ${Platform.operatingSystem}\n'
             'Поддерживаются только iOS и Android\n'
             'Используйте iPhone или Android для тестирования';
    }
    
    if (errorStr.contains('PlatformException')) {
      if (errorStr.contains('PERMISSION_DENIED')) {
        return '❌ Доступ запрещен\n'
               'Откройте Настройки → Конфиденциальность → Здоровье\n'
               'Найдите ATMO Shield и разрешите доступ\n'
               'Перезапустите приложение после изменения настроек';
      }
      
      if (errorStr.contains('HEALTH_NOT_AVAILABLE')) {
        return '❌ HealthKit недоступен\n'
               'Возможные причины:\n'
               '• Устройство не поддерживает HealthKit\n'
               '• HealthKit отключен в настройках\n'
               '• Требуется обновление iOS';
      }
    }
    
    if (errorStr.contains('TimeoutException')) {
      return '❌ Превышено время ожидания\n'
             'Проверьте подключение к интернету\n'
             'Попробуйте еще раз через несколько секунд';
    }
    
    if (errorStr.contains('SocketException')) {
      return '❌ Проблема с сетью\n'
             'Проверьте подключение к интернету\n'
             'Убедитесь что разрешен доступ к сети';
    }
    
    // Общая ошибка с техническими деталями
    return '❌ Техническая ошибка\n'
           'Тип: ${error.runtimeType}\n'
           'Детали: ${errorStr.length > 100 ? errorStr.substring(0, 100) + "..." : errorStr}\n'
           'Попробуйте перезапустить приложение';
  }

  List<HealthDataPoint> _generateMockHealthData() {
    final List<HealthDataPoint> mockData = [];
    final now = DateTime.now();
    
    // Генерируем мок-данные для демонстрации
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      
      // HRV данные
      mockData.add(HealthDataPoint(
        value: NumericHealthValue(numericValue: 25.0 + (i % 10) * 2.5),
        type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        unit: HealthDataUnit.MILLISECOND,
        dateFrom: date.subtract(const Duration(hours: 8)),
        dateTo: date.subtract(const Duration(hours: 8)),
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'mock-device',
        sourceId: 'mock-source',
        sourceName: 'Apple Watch (Демо)',
      ));
      
      // Пульс
      mockData.add(HealthDataPoint(
        value: NumericHealthValue(numericValue: 65.0 + (i % 15) * 1.5),
        type: HealthDataType.HEART_RATE,
        unit: HealthDataUnit.BEATS_PER_MINUTE,
        dateFrom: date.subtract(const Duration(hours: 10)),
        dateTo: date.subtract(const Duration(hours: 10)),
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'mock-device',
        sourceId: 'mock-source',
        sourceName: 'Apple Watch (Демо)',
      ));
      
      // Шаги
      mockData.add(HealthDataPoint(
        value: NumericHealthValue(numericValue: 8000.0 + (i % 20) * 200),
        type: HealthDataType.STEPS,
        unit: HealthDataUnit.COUNT,
        dateFrom: date.subtract(const Duration(hours: 24)),
        dateTo: date,
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'mock-device',
        sourceId: 'mock-source',
        sourceName: 'iPhone (Демо)',
      ));
    }
    
    return mockData;
  }
}