import 'package:hive_ce/hive.dart';

part 'place.g.dart';

@HiveType(typeId: 1)
class Place extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String tripId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final String neighbourhood;

  @HiveField(5)
  final double latitude;

  @HiveField(6)
  final double longitude;

  @HiveField(7)
  final String? address;

  @HiveField(8)
  final String? nearestStation;

  @HiveField(9)
  final String? sourceUrl;

  @HiveField(10)
  final String? sourceType;

  @HiveField(11)
  final double? confidence;

  @HiveField(12)
  final String? notes;

  @HiveField(13)
  final Map<String, dynamic>? aiMetadata;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final String? imageUrl;

  @HiveField(16)
  final String? localImagePath;

  @HiveField(17)
  final String? customImageBase64;

  @HiveField(18)
  final bool visited;

  Place({
    required this.id,
    required this.tripId,
    required this.name,
    required this.category,
    required this.neighbourhood,
    required this.latitude,
    required this.longitude,
    this.address,
    this.nearestStation,
    this.sourceUrl,
    this.sourceType,
    this.confidence,
    this.notes,
    this.aiMetadata,
    required this.createdAt,
    this.imageUrl,
    this.localImagePath,
    this.customImageBase64,
    this.visited = false,
  });
}
