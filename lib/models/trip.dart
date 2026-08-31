import 'package:hive_ce/hive.dart';

part 'trip.g.dart';

@HiveType(typeId: 0)
class Trip extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String destination;

  @HiveField(3)
  final DateTime? startDate;

  @HiveField(4)
  final DateTime? endDate;

  Trip({
    required this.id,
    required this.name,
    required this.destination,
    this.startDate,
    this.endDate,
  });
}
