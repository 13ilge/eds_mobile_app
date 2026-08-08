import 'package:geolocator/geolocator.dart';

import '../models/speed_data.dart';

class LocationService {
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

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
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Stream<SpeedData> getLiveSpeedStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (Position position) {
        double speedKmh = (position.speed < 0 ? 0.0 : position.speed) * 3.6;

        return SpeedData(
          currentSpeed: speedKmh,
          timestamp: position.timestamp,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
        );
      },
    );
  }
}
