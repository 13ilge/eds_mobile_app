import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/eds_point.dart';

class EdsStorageService {
  String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'custom_eds_points_$uid';
  }

  static final EdsStorageService _instance = EdsStorageService._internal();
  factory EdsStorageService() => _instance;
  EdsStorageService._internal();

  SharedPreferences? _prefs;

  List<EdsPoint>? _cachedPoints;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  void clearCache() {
    _cachedPoints = null;
  }

  Future<List<EdsPoint>> loadCustomPoints() async {
    if (_cachedPoints != null) {
      return List.from(_cachedPoints!);
    }

    final prefs = await _preferences;
    final String? jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null) {
      _cachedPoints = [];
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _cachedPoints = jsonList.map((json) => EdsPoint.fromJson(json)).toList();
      return List.from(_cachedPoints!);
    } catch (e) {
      debugPrint('Error decoding custom EDS points: $e');
      _cachedPoints = [];
      return [];
    }
  }

  Future<void> saveCustomPoint(EdsPoint point) async {
    final points = await loadCustomPoints();
    final index = points.indexWhere((p) => p.id == point.id);
    if (index >= 0) {
      points[index] = point; // Update
    } else {
      points.add(point); // Insert
    }
    _cachedPoints = List.from(points);
    await _persistPoints(points);
  }

  Future<void> deleteCustomPoint(String id) async {
    final points = await loadCustomPoints();
    points.removeWhere((point) => point.id == id);
    _cachedPoints = List.from(points);
    await _persistPoints(points);
  }

  Future<void> _persistPoints(List<EdsPoint> points) async {
    final prefs = await _preferences;
    final String jsonString = jsonEncode(points.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
