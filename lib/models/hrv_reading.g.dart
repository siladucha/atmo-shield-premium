// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hrv_reading.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HRVReadingAdapter extends TypeAdapter<HRVReading> {
  @override
  final int typeId = 0;

  @override
  HRVReading read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HRVReading(
      timestamp: fields[0] as DateTime,
      value: fields[1] as double,
      source: fields[2] as String,
      sampleCount: fields[3] as int,
      confidence: fields[4] as double,
      platform: fields[5] as String,
      normalized: fields[6] as bool,
      metadata: (fields[7] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, HRVReading obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.sampleCount)
      ..writeByte(4)
      ..write(obj.confidence)
      ..writeByte(5)
      ..write(obj.platform)
      ..writeByte(6)
      ..write(obj.normalized)
      ..writeByte(7)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HRVReadingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
