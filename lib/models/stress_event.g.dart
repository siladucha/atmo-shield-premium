// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stress_event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StressEventAdapter extends TypeAdapter<StressEvent> {
  @override
  final int typeId = 4;

  @override
  StressEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StressEvent(
      detectedAt: fields[0] as DateTime,
      zScore: fields[1] as double,
      severity: fields[2] as StressSeverity,
      pattern: fields[3] as StressPattern,
      recommendedProtocol: fields[4] as String?,
      notificationSent: fields[5] as bool,
      interventionStarted: fields[6] as DateTime?,
      interventionCompleted: fields[7] as bool,
      postInterventionHRV: fields[8] as double?,
      userFeedback: fields[9] as String?,
      context: (fields[10] as Map?)?.cast<String, dynamic>(),
      confidence: fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, StressEvent obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.detectedAt)
      ..writeByte(1)
      ..write(obj.zScore)
      ..writeByte(2)
      ..write(obj.severity)
      ..writeByte(3)
      ..write(obj.pattern)
      ..writeByte(4)
      ..write(obj.recommendedProtocol)
      ..writeByte(5)
      ..write(obj.notificationSent)
      ..writeByte(6)
      ..write(obj.interventionStarted)
      ..writeByte(7)
      ..write(obj.interventionCompleted)
      ..writeByte(8)
      ..write(obj.postInterventionHRV)
      ..writeByte(9)
      ..write(obj.userFeedback)
      ..writeByte(10)
      ..write(obj.context)
      ..writeByte(11)
      ..write(obj.confidence);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StressEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StressSeverityAdapter extends TypeAdapter<StressSeverity> {
  @override
  final int typeId = 2;

  @override
  StressSeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StressSeverity.normal;
      case 1:
        return StressSeverity.low;
      case 2:
        return StressSeverity.medium;
      case 3:
        return StressSeverity.high;
      case 4:
        return StressSeverity.critical;
      default:
        return StressSeverity.normal;
    }
  }

  @override
  void write(BinaryWriter writer, StressSeverity obj) {
    switch (obj) {
      case StressSeverity.normal:
        writer.writeByte(0);
        break;
      case StressSeverity.low:
        writer.writeByte(1);
        break;
      case StressSeverity.medium:
        writer.writeByte(2);
        break;
      case StressSeverity.high:
        writer.writeByte(3);
        break;
      case StressSeverity.critical:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StressSeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StressPatternAdapter extends TypeAdapter<StressPattern> {
  @override
  final int typeId = 3;

  @override
  StressPattern read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StressPattern.sympatheticOverdrive;
      case 1:
        return StressPattern.neuralRigidity;
      case 2:
        return StressPattern.energyDepletion;
      case 3:
        return StressPattern.acuteStress;
      default:
        return StressPattern.sympatheticOverdrive;
    }
  }

  @override
  void write(BinaryWriter writer, StressPattern obj) {
    switch (obj) {
      case StressPattern.sympatheticOverdrive:
        writer.writeByte(0);
        break;
      case StressPattern.neuralRigidity:
        writer.writeByte(1);
        break;
      case StressPattern.energyDepletion:
        writer.writeByte(2);
        break;
      case StressPattern.acuteStress:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StressPatternAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
