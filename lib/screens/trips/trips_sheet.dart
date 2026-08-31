class Trip {
  final String id;
  final String name;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;

  Trip({
    required this.id,
    required this.name,
    required this.destination,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'destination': destination,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      name: json['name'],
      destination: json['destination'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
    );
  }
}
