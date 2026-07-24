import '../models/eds_point.dart';

class EdsDataRepository {
  static final List<EdsPoint> malatyaEdsPoints = [
    EdsPoint(
      id: 'eds_malatya_elazig_1',
      name: 'Malatya - Elazığ Karayolu',
      // Pütürge Kavşağı (Approximate)
      startLatitude: 38.3512,
      startLongitude: 38.3845,
      // Kömürhan Köprüsü (Approximate)
      endLatitude: 38.4408,
      endLongitude: 38.8189,
      isBidirectional: true,
      speedLimit: 82,
    ),
    EdsPoint(
      id: 'eds_malatya_sivas_1',
      name: 'Malatya - Sivas Karayolu',
      // Dilek Kavşağı (Approximate)
      startLatitude: 38.3845,
      startLongitude: 38.2712,
      // Yazıhan İlçe Çıkışı (Approximate)
      endLatitude: 38.5872,
      endLongitude: 38.1633,
      isBidirectional: true,
      speedLimit: 82,
    ),
  ];
}
