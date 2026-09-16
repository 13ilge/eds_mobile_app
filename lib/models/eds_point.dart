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

  bool hasSameCoordinates(EdsPoint other) {
    const epsilon = 0.00001; // tolerance for floating point drift
    return (startLatitude - other.startLatitude).abs() < epsilon &&
        (startLongitude - other.startLongitude).abs() < epsilon &&
        (endLatitude - other.endLatitude).abs() < epsilon &&
        (endLongitude - other.endLongitude).abs() < epsilon;
  }

  EdsPoint copyWith({
    String? id,
    String? name,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    bool? isBidirectional,
    int? speedLimit,
  }) {
    return EdsPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      isBidirectional: isBidirectional ?? this.isBidirectional,
      speedLimit: speedLimit ?? this.speedLimit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EdsPoint &&
        id == other.id &&
        name == other.name &&
        startLatitude == other.startLatitude &&
        startLongitude == other.startLongitude &&
        endLatitude == other.endLatitude &&
        endLongitude == other.endLongitude &&
        isBidirectional == other.isBidirectional &&
        speedLimit == other.speedLimit;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    isBidirectional,
    speedLimit,
  );
}
