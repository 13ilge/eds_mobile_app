import 'package:geolocator/geolocator.dart';

import '../models/speed_data.dart';

class LocationService {
  /// Checks and requests location permissions.
  /// Returns [true] if permission is granted, [false] otherwise.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled on the device hardware.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever. Automatically open app settings.
      await Geolocator.openAppSettings();
      return false;
    } 

    return true;
  }

  /// Streams the live GPS speed and coordinates.
  Stream<SpeedData> getLiveSpeedStream() {
    // Configure location settings optimized for driving UI responsiveness
    // High accuracy is crucial for speed, but updating every 2 meters saves battery.
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, 
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .map((Position position) {
      // Convert incoming raw GPS speed from meters/second to km/h
      // We ensure it never dips below 0 if GPS returns a negative anomaly.
      double speedKmh = (position.speed < 0 ? 0.0 : position.speed) * 3.6;
      
      return SpeedData(
        currentSpeed: speedKmh,
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
        heading: position.heading,
      );
    });
  }
}
