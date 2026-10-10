import 'dart:math' as math;

class WindSample {
  final double east;
  final double north;
  WindSample(this.east, this.north);
}

class WindEstimator {
  static const int _maxSamples = 30;
  static const double _hoverSpeedThreshold = 1.5;
  static const double _minAltitude = 2.0;
  static const int _minSamplesForEstimate = 5;

  final List<WindSample> _samples = [];
  double _windSpeed = 0.0;
  double _windDirection = 0.0;

  double get windSpeed => _windSpeed;
  double get windDirection => _windDirection;

  static bool _isHoverMode(String mode) {
    final m = mode.toUpperCase();
    return m == 'LOITER' || m == 'POSHOLD' || m == 'GUIDED' || m == 'SMART_RTL';
  }

  void update(double groundSpeed, double heading, String mode, double altitude) {
    final canSample = _isHoverMode(mode) &&
        groundSpeed < _hoverSpeedThreshold &&
        altitude > _minAltitude;

    if (canSample) {
      final rad = heading * math.pi / 180.0;
      _samples.add(WindSample(
        groundSpeed * math.sin(rad),
        groundSpeed * math.cos(rad),
      ));
      if (_samples.length > _maxSamples) _samples.removeAt(0);
    }

    if (_samples.length >= _minSamplesForEstimate) {
      double sumE = 0, sumN = 0;
      for (final s in _samples) {
        sumE += s.east;
        sumN += s.north;
      }
      final avgE = sumE / _samples.length;
      final avgN = sumN / _samples.length;
      _windSpeed = math.sqrt(avgE * avgE + avgN * avgN);
      _windDirection = (math.atan2(avgE, avgN) * 180.0 / math.pi + 360) % 360;
    }
  }

  void reset() {
    _samples.clear();
    _windSpeed = 0.0;
    _windDirection = 0.0;
  }
}
