import 'package:geolocator/geolocator.dart';
import '../models/eds_point.dart';
import '../models/speed_data.dart';
import 'dart:math' as math;
import 'eds_data_repository.dart';
import 'eds_storage_service.dart';

class EdsGeofenceService {
  final EdsStorageService _storageService = EdsStorageService();
  List<EdsPoint> _activePoints = [];

  static const double triggerRadiusMeters = 500.0;
  static const double endRadiusMeters = 100.0;
  static const double headingToleranceDegrees = 45.0;

  static const double _boundingBoxThreshold = 0.006;

  EdsGeofenceService() {
    reloadPoints();
  }

  Future<void> reloadPoints() async {
    final customPoints = await _storageService.loadCustomPoints();
    _activePoints = [...EdsDataRepository.malatyaEdsPoints, ...customPoints];
  }

  bool _isWithinBoundingBox(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return (lat1 - lat2).abs() < _boundingBoxThreshold &&
        (lng1 - lng2).abs() < _boundingBoxThreshold;
  }

  EdsPoint? checkAutomaticStart(SpeedData currentData) {
    if (currentData.heading < 0) return null;

    for (final point in _activePoints) {
      if (_isWithinBoundingBox(
        currentData.latitude,
        currentData.longitude,
        point.startLatitude,
        point.startLongitude,
      )) {
        final distanceToStart = Geolocator.distanceBetween(
          currentData.latitude,
          currentData.longitude,
          point.startLatitude,
          point.startLongitude,
        );

        if (distanceToStart <= triggerRadiusMeters) {
          final expectedHeading = Geolocator.bearingBetween(
            point.startLatitude,
            point.startLongitude,
            point.endLatitude,
            point.endLongitude,
          );

          if (_isHeadingMatching(currentData.heading, expectedHeading)) {
            return point;
          }
        }
      }

      if (point.isBidirectional) {
        if (_isWithinBoundingBox(
          currentData.latitude,
          currentData.longitude,
          point.endLatitude,
          point.endLongitude,
        )) {
          final distanceToEnd = Geolocator.distanceBetween(
            currentData.latitude,
            currentData.longitude,
            point.endLatitude,
            point.endLongitude,
          );

          if (distanceToEnd <= triggerRadiusMeters) {
            final expectedHeading = Geolocator.bearingBetween(
              point.endLatitude,
              point.endLongitude,
              point.startLatitude,
              point.startLongitude,
            );

            if (_isHeadingMatching(currentData.heading, expectedHeading)) {
              return point;
            }
          }
        }
      }
    }
    return null;
  }

  bool checkAutomaticStop(
    SpeedData currentData,
    EdsPoint activePoint,
    double distanceTraveledMeters,
  ) {
    if (distanceTraveledMeters < 500.0) return false;

    final distanceToStart = Geolocator.distanceBetween(
      currentData.latitude,
      currentData.longitude,
      activePoint.startLatitude,
      activePoint.startLongitude,
    );

    final distanceToEnd = Geolocator.distanceBetween(
      currentData.latitude,
      currentData.longitude,
      activePoint.endLatitude,
      activePoint.endLongitude,
    );

    return distanceToStart <= endRadiusMeters ||
        distanceToEnd <= endRadiusMeters;
  }

  bool _isHeadingMatching(double actual, double expected) {
    final nActual = actual % 360;
    var nExpected = expected % 360;
    if (nExpected < 0) nExpected += 360;
    final diff = (nActual - nExpected).abs();
    final shortestDiff = math.min(diff, 360 - diff);

    return shortestDiff <= headingToleranceDegrees;
  }
}
