/// EDUCATIONAL NOTE: Models Layer
/// In a clean architecture, the 'models' directory holds the core data structures of the application.
/// These classes are simple and hold data, but do not contain business logic or UI code.
/// This separation ensures our data definition is completely independent of how it is presented or fetched.

class SpeedData {
  final double currentSpeed;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double heading;

  SpeedData({
    required this.currentSpeed,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.heading,
  });
}
