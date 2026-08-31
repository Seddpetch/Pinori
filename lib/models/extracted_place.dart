class ExtractedPlace {
  final String name;
  final String? city;
  final String? neighbourhood;
  final String? nearestStation;
  final String category;
  final String? address;
  final String? imageUrl;
  final double confidence;

  ExtractedPlace({
    required this.name,
    this.city,
    this.neighbourhood,
    this.nearestStation,
    required this.category,
    this.address,
    this.imageUrl,
    required this.confidence,
  });
}
