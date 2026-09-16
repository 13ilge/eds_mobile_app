class SpeedData {
  final double currentSpeed;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  /// Direction of travel in degrees [0, 360), or `null` when the device
  /// cannot provide a reliable bearing (geolocator reports -1 on iOS /
  /// no magnetometer). `LocationService` maps negatives to `null`.
  final double? heading;

  SpeedData({
    required this.currentSpeed,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.heading,
  });
}
