//this is the traffic congestion predictor using the json trained model - Joshua

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class CorridorPrediction {
  final int id;
  final String name;
  final LatLng center;
  final List<LatLng> segmentPoints;
  final int level; // 0 = Free, 1 = Moderate, 2 = Heavy
  final double confidence;
  final int extraDelayMins;

  CorridorPrediction({
    required this.id,
    required this.name,
    required this.center,
    required this.segmentPoints,
    required this.level,
    required this.confidence,
    required this.extraDelayMins,
  });

  String get label => level == 2 ? 'Heavy Bottleneck' : (level == 1 ? 'Moderate Traffic' : 'Free Flow');
}

class CongestionPredictorService {
  Map<String, dynamic>? _weights;
  double currentRainMm = 0.0;

  // Key Iloilo LPTRP Corridor Nodes & Polyline Segments
  static final _corridors = [
    {
      'id': 0,
      'name': 'Ungka Terminal - Pavia Junction',
      'center': const LatLng(10.7495, 122.5432),
      'points': [const LatLng(10.7530, 122.5410), const LatLng(10.7495, 122.5432), const LatLng(10.7440, 122.5480)],
    },
    {
      'id': 1,
      'name': 'Jaro Plaza - El 98 Corridor',
      'center': const LatLng(10.7258, 122.5572),
      'points': [const LatLng(10.7310, 122.5550), const LatLng(10.7258, 122.5572), const LatLng(10.7210, 122.5605)],
    },
    {
      'id': 2,
      'name': 'WVSU Luna St. - La Paz Loop',
      'center': const LatLng(10.7138, 122.5635),
      'points': [const LatLng(10.7185, 122.5618), const LatLng(10.7138, 122.5635), const LatLng(10.7102, 122.5670)],
    },
    {
      'id': 3,
      'name': 'SM City - Diversion / Atria',
      'center': const LatLng(10.7145, 122.5512),
      'points': [const LatLng(10.7205, 122.5485), const LatLng(10.7145, 122.5512), const LatLng(10.7065, 122.5528)],
    },
    {
      'id': 4,
      'name': 'City Proper - JM Basa / Atrium',
      'center': const LatLng(10.6968, 122.5685),
      'points': [const LatLng(10.7030, 122.5665), const LatLng(10.6968, 122.5685), const LatLng(10.6925, 122.5715)],
    },
  ];

  Future<void> loadModel() async {
    if (_weights != null) return;
    final jsonStr = await rootBundle.loadString('assets/models/iloilo_traffic_weights.json');
    _weights = jsonDecode(jsonStr);
  }

  Future<double> fetchLiveIloiloRain() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=10.7202&longitude=122.5621&current=precipitation',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        currentRainMm = (data['current']['precipitation'] as num).toDouble();
      }
    } catch (_) {
      // Fallback to 0.0 mm if offline
    }
    return currentRainMm;
  }

  // Pure Dart Neural Network Forward Pass (ReLU + Softmax)
  List<double> _predictProbs(List<double> input) {
    List<double> dense(List<double> x, List<dynamic> w, List<dynamic> b, bool relu) {
      final out = List<double>.filled(b.length, 0.0);
      for (int j = 0; j < b.length; j++) {
        double sum = (b[j] as num).toDouble();
        for (int i = 0; i < x.length; i++) {
          sum += x[i] * (w[i][j] as num).toDouble();
        }
        out[j] = relu ? max(0.0, sum) : sum;
      }
      return out;
    }

    final h1 = dense(input, _weights!['w1'], _weights!['b1'], true);
    final h2 = dense(h1, _weights!['w2'], _weights!['b2'], true);
    final logits = dense(h2, _weights!['w3'], _weights!['b3'], false);

    final maxLogit = logits.reduce(max);
    final exps = logits.map((v) => exp(v - maxLogit)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  Future<List<CorridorPrediction>> predictAllCorridors({DateTime? targetTime}) async {
    await loadModel();
    await fetchLiveIloiloRain();

    final now = targetTime ?? DateTime.now();
    final hourNorm = now.hour / 23.0;
    final isWeekday = now.weekday <= 5 ? 1.0 : 0.0;
    final rainNorm = (currentRainMm / 15.0).clamp(0.0, 1.0);

    return _corridors.map((c) {
      final id = c['id'] as int;
      final probs = _predictProbs([hourNorm, isWeekday, rainNorm, id / 4.0]);

      int bestClass = 0;
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > probs[bestClass]) bestClass = i;
      }

      return CorridorPrediction(
        id: id,
        name: c['name'] as String,
        center: c['center'] as LatLng,
        segmentPoints: List<LatLng>.from(c['points'] as List),
        level: bestClass,
        confidence: probs[bestClass],
        extraDelayMins: bestClass == 2 ? 14 : (bestClass == 1 ? 6 : 0),
      );
    }).toList();
  }
}