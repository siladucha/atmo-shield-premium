// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'baseline_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BaselineDataAdapter extends TypeAdapter<BaselineData> {
  @override
  final int typeId = 1;

  @override
  BaselineData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BaselineData(
      calculatedAt: fields[0] as DateTime,
      mean: fields[1] as double,
      standardDeviation: fields[2] as double,
      dayCount: fields[3] as int,
      confidence: fields[4] as double,
      platform: fields[5] as String,
      periodStart: fields[6] as DateTime,
      periodEnd: fields[7] as DateTime,
      sampleCount: fields[8] as int,
      median: fields[9] as double,
      min: fields[10] as double,
      max: fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BaselineData obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.calculatedAt)
      ..writeByte(1)
      ..write(obj.mean)
      ..writeByte(2)
      ..write(obj.standardDeviation)
      ..writeByte(3)
      ..write(obj.dayCount)
      ..writeByte(4)
      ..write(obj.confidence)
      ..writeByte(5)
      ..write(obj.platform)
      ..writeByte(6)
      ..write(obj.periodStart)
      ..writeByte(7)
      ..write(obj.periodEnd)
      ..writeByte(8)
      ..write(obj.sampleCount)
      ..writeByte(9)
      ..write(obj.median)
      ..writeByte(10)
      ..write(obj.min)
      ..writeByte(11)
      ..write(obj.max);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaselineDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
