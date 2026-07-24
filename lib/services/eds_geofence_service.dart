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

  /// Bounding box threshold in degrees.
  /// At 38°N latitude (Turkey): 0.006° latitude ≈ 670m, 0.006° longitude ≈ 530m.
  /// This is generous enough to cover the 500m trigger radius while being
  /// ~1000× cheaper than a haversine computation (simple subtraction vs sin/cos/sqrt).
  static const double _boundingBoxThreshold = 0.006;

  EdsGeofenceService() {
    reloadPoints();
  }

  Future<void> reloadPoints() async {
    final customPoints = await _storageService.loadCustomPoints();
    _activePoints = [...EdsDataRepository.malatyaEdsPoints, ...customPoints];
  }

  /// Cheap bounding-box check: returns true if two coordinates are within
  /// ~670m of each other. Used to skip expensive haversine computation
  /// for points that are obviously too far away.
  bool _isWithinBoundingBox(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return (lat1 - lat2).abs() < _boundingBoxThreshold &&
           (lng1 - lng2).abs() < _boundingBoxThreshold;
  }

  EdsPoint? checkAutomaticStart(SpeedData currentData) {
    if (currentData.heading < 0) return null;

    for (final point in _activePoints) {
      // --- Check start point ---
      // Cheap bounding box first, skip haversine if obviously too far
      if (_isWithinBoundingBox(
        currentData.latitude, currentData.longitude,
        point.startLatitude, point.startLongitude,
      )) {
        // Başlangıç noktasına olan mesafe (expensive haversine)
        final distanceToStart = Geolocator.distanceBetween(
          currentData.latitude, currentData.longitude,
          point.startLatitude, point.startLongitude,
        );

        if (distanceToStart <= triggerRadiusMeters) {
          final expectedHeading = Geolocator.bearingBetween(
            point.startLatitude, point.startLongitude,
            point.endLatitude, point.endLongitude,
          );
          
          if (_isHeadingMatching(currentData.heading, expectedHeading)) {
            return point;
          }
        }
      }

      // --- Check end point (bidirectional) ---
      // Çift yönlüyse, bitiş noktasını bir "başlangıç" gibi denetle
      if (point.isBidirectional) {
        if (_isWithinBoundingBox(
          currentData.latitude, currentData.longitude,
          point.endLatitude, point.endLongitude,
        )) {
          final distanceToEnd = Geolocator.distanceBetween(
            currentData.latitude, currentData.longitude,
            point.endLatitude, point.endLongitude,
          );

          if (distanceToEnd <= triggerRadiusMeters) {
            final expectedHeading = Geolocator.bearingBetween(
              point.endLatitude, point.endLongitude,
              point.startLatitude, point.startLongitude,
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

  /// Aracın aktif EDS koridorundan çıkıp çıkmadığını denetler.
  bool checkAutomaticStop(SpeedData currentData, EdsPoint activePoint, double distanceTraveledMeters) {
    // Yanlışlıkla girer girmez kapanmasını önlemek için en az 500m ilerlemiş olmalı
    if (distanceTraveledMeters < 500.0) return false;

    final distanceToStart = Geolocator.distanceBetween(
      currentData.latitude, currentData.longitude,
      activePoint.startLatitude, activePoint.startLongitude,
    );
    
    final distanceToEnd = Geolocator.distanceBetween(
      currentData.latitude, currentData.longitude,
      activePoint.endLatitude, activePoint.endLongitude,
    );

    // Herhangi bir uç noktaya (başlangıç veya bitiş) ulaşıldığında durdur.
    return distanceToStart <= endRadiusMeters || distanceToEnd <= endRadiusMeters;
  }

  bool _isHeadingMatching(double actual, double expected) {
    final nActual = actual % 360;
    var nExpected = expected % 360;
    if (nExpected < 0) nExpected += 360; // Bearing negatif dönebilir
    
    final diff = (nActual - nExpected).abs();
    final shortestDiff = math.min(diff, 360 - diff);
    
    return shortestDiff <= headingToleranceDegrees;
  }
}
