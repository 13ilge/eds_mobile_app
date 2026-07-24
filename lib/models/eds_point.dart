class EdsPoint {
  final String id;
  final String name;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final bool isBidirectional;
  final int speedLimit;

  EdsPoint({
    required this.id,
    required this.name,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    this.isBidirectional = true,
    this.speedLimit = 82,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'isBidirectional': isBidirectional,
      'speedLimit': speedLimit,
    };
  }

  factory EdsPoint.fromJson(Map<String, dynamic> json) {
    return EdsPoint(
      id: json['id'],
      name: json['name'],
      startLatitude: json['startLatitude'],
      startLongitude: json['startLongitude'],
      endLatitude: json['endLatitude'],
      endLongitude: json['endLongitude'],
      isBidirectional: json['isBidirectional'] ?? true,
      speedLimit: json['speedLimit'] ?? 82,
    );
  }
}
