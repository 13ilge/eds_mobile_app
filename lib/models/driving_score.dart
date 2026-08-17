class DrivingScore {
  final String id;
  final DateTime sessionDate;
  final int score;
  final double complianceRatio;
  final double speedAccuracy;
  final double smoothness;
  final int durationSeconds;
  final double distanceKm;
  final int averageSpeed;
  final int targetSpeed;
  final String? edsPointName;

  const DrivingScore({
    required this.id,
    required this.sessionDate,
    required this.score,
    required this.complianceRatio,
    required this.speedAccuracy,
    required this.smoothness,
    required this.durationSeconds,
    required this.distanceKm,
    required this.averageSpeed,
    required this.targetSpeed,
    this.edsPointName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionDate': sessionDate.toIso8601String(),
      'score': score,
      'complianceRatio': complianceRatio,
      'speedAccuracy': speedAccuracy,
      'smoothness': smoothness,
      'durationSeconds': durationSeconds,
      'distanceKm': distanceKm,
      'averageSpeed': averageSpeed,
      'targetSpeed': targetSpeed,
      'edsPointName': edsPointName,
    };
  }

  factory DrivingScore.fromJson(Map<String, dynamic> json) {
    return DrivingScore(
      id: json['id'] as String,
      sessionDate: DateTime.parse(json['sessionDate'] as String),
      score: json['score'] as int,
      complianceRatio: (json['complianceRatio'] as num).toDouble(),
      speedAccuracy: (json['speedAccuracy'] as num).toDouble(),
      smoothness: (json['smoothness'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      averageSpeed: json['averageSpeed'] as int,
      targetSpeed: json['targetSpeed'] as int,
      edsPointName: json['edsPointName'] as String?,
    );
  }
}
