import 'dart:async';
import 'package:flutter/material.dart';
import '../models/eds_point.dart';
import 'metric_card.dart';

class DashboardTimerMetric extends StatefulWidget {
  final bool isActive;
  final EdsPoint? activeEdsPoint;
  final double totalDistance;
  final double currentDistanceMeters;
  final DateTime? trackingStartTime;
  final int targetSpeed;

  const DashboardTimerMetric({
    super.key,
    required this.isActive,
    this.activeEdsPoint,
    required this.totalDistance,
    required this.currentDistanceMeters,
    this.trackingStartTime,
    required this.targetSpeed,
  });

  @override
  State<DashboardTimerMetric> createState() => _DashboardTimerMetricState();
}

class _DashboardTimerMetricState extends State<DashboardTimerMetric> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(DashboardTimerMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive || widget.trackingStartTime != oldWidget.trackingStartTime) {
      if (widget.isActive) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.isActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double currentDistanceKm = widget.isActive ? (widget.currentDistanceMeters / 1000.0) : 0.0;

    String brLabel = 'MAX HEDEF HIZ';
    String brValue = widget.isActive ? widget.targetSpeed.toString() : '0';
    String brUnit = 'km/s';

    if (widget.isActive) {
      if (widget.activeEdsPoint != null) {
        final double limit = widget.activeEdsPoint!.speedLimit.toDouble();
        final double minTimeHours = widget.totalDistance / limit;
        
        double elapsedHours = 0;
        if (widget.trackingStartTime != null) {
          elapsedHours = DateTime.now().difference(widget.trackingStartTime!).inSeconds / 3600.0;
        }

        final double remainingDistance = widget.totalDistance - currentDistanceKm;
        final double remainingTime = minTimeHours - elapsedHours;

        if (remainingDistance <= 0 || remainingTime <= 0) {
          brLabel = 'GÜVENLİ HIZ';
          brValue = limit.toInt().toString();
        } else {
          final double safeSpeed = remainingDistance / remainingTime;
          brLabel = 'KALAN GÜVENLİ HIZ';
          brValue = safeSpeed > 130 ? '130+' : safeSpeed.toInt().toString();
        }
      } else {
        brLabel = 'SÜRÜŞ SÜRESİ';
        brUnit = '';
        if (widget.trackingStartTime != null) {
          final duration = DateTime.now().difference(widget.trackingStartTime!);
          final minutes = duration.inMinutes.toString().padLeft(2, '0');
          final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
          brValue = '$minutes:$seconds';
        } else {
          brValue = '00:00';
        }
      }
    }

    return MetricCard(
      label: brLabel,
      valueText: brValue,
      unit: brUnit,
    );
  }
}
