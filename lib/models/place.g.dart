// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceAdapter extends TypeAdapter<Place> {
  @override
  final typeId = 1;

  @override
  Place read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Place(
      id: fields[0] as String,
      tripId: fields[1] as String,
      name: fields[2] as String,
      category: fields[3] as String,
      neighbourhood: fields[4] as String,
      latitude: (fields[5] as num).toDouble(),
      longitude: (fields[6] as num).toDouble(),
      address: fields[7] as String?,
      nearestStation: fields[8] as String?,
      sourceUrl: fields[9] as String?,
      sourceType: fields[10] as String?,
      confidence: (fields[11] as num?)?.toDouble(),
      notes: fields[12] as String?,
      aiMetadata: (fields[13] as Map?)?.cast<String, dynamic>(),
      createdAt: fields[14] as DateTime,
      imageUrl: fields[15] as String?,
      localImagePath: fields[16] as String?,
      customImageBase64: fields[17] as String?,
      visited: fields[18] == null ? false : fields[18] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Place obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tripId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.neighbourhood)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.nearestStation)
      ..writeByte(9)
      ..write(obj.sourceUrl)
      ..writeByte(10)
      ..write(obj.sourceType)
      ..writeByte(11)
      ..write(obj.confidence)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.aiMetadata)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.imageUrl)
      ..writeByte(16)
      ..write(obj.localImagePath)
      ..writeByte(17)
      ..write(obj.customImageBase64)
      ..writeByte(18)
      ..write(obj.visited);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
