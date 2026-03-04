import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/native/healthkit_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthKitBridge', () {
    late HealthKitBridge bridge;
    late List<MethodCall> methodCalls;

    setUp(() {
      bridge = HealthKitBridge();
      methodCalls = [];

      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('healthkit_generator'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'isHealthKitAvailable':
              return true;
            case 'requestPermissions':
              return true;
            case 'writeBatch':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('healthkit_generator'),
        null,
      );
    });

    test('isHealthKitAvailable calls native method', () async {
      final result = await bridge.isHealthKitAvailable();

      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls[0].method, equals('isHealthKitAvailable'));
    });

    test('requestPermissions calls native method with correct arguments',
        () async {
      final writeTypes = ['heartRate', 'hrv', 'respiratoryRate'];
      final result = await bridge.requestPermissions(writeTypes);

      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls[0].method, equals('requestPermissions'));
      expect(methodCalls[0].arguments['writeTypes'], equals(writeTypes));
    });

    test('writeBatch calls native method with correct arguments', () async {
      final dataType = 'heartRate';
      final records = [
        {'timestamp': 1234567890000.0, 'value': 72.0},
        {'timestamp': 1234567900000.0, 'value': 75.0},
      ];

      final result = await bridge.writeBatch(dataType, records);

      expect(result, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls[0].method, equals('writeBatch'));
      expect(methodCalls[0].arguments['dataType'], equals(dataType));
      expect(methodCalls[0].arguments['records'], equals(records));
    });

    test('requestPermissions handles PlatformException gracefully', () async {
      // Override mock to throw exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('healthkit_generator'),
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'User denied permissions',
          );
        },
      );

      final result = await bridge.requestPermissions(['heartRate']);

      expect(result, isFalse);
    });

    test('writeBatch handles PlatformException gracefully', () async {
      // Override mock to throw exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('healthkit_generator'),
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'WRITE_ERROR',
            message: 'Failed to write data',
          );
        },
      );

      final result = await bridge.writeBatch('heartRate', [
        {'timestamp': 1234567890000.0, 'value': 72.0}
      ]);

      expect(result, isFalse);
    });

    test('handles null return values from native code', () async {
      // Override mock to return null
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('healthkit_generator'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      final availableResult = await bridge.isHealthKitAvailable();
      final permissionResult = await bridge.requestPermissions(['heartRate']);
      final writeResult = await bridge.writeBatch('heartRate', [
        {'timestamp': 1234567890000.0, 'value': 72.0}
      ]);

      expect(availableResult, isFalse);
      expect(permissionResult, isFalse);
      expect(writeResult, isFalse);
    });
  });
}
