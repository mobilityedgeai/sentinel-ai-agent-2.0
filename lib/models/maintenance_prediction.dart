import 'component_health.dart';

/// Predição de manutenção
class MaintenancePrediction {
  final ComponentType componentType;
  final DateTime predictedDate;
  final double predictedKilometers;
  final double confidence;
  final double estimatedCost;
  final double urgency;

  MaintenancePrediction({
    required this.componentType,
    required this.predictedDate,
    required this.predictedKilometers,
    required this.confidence,
    required this.estimatedCost,
    required this.urgency,
  });

  String get componentName {
    switch (componentType) {
      case ComponentType.brakes:
        return 'Freios';
      case ComponentType.engine:
        return 'Motor';
      case ComponentType.tires:
        return 'Pneus';
      case ComponentType.suspension:
        return 'Suspensão';
      case ComponentType.transmission:
        return 'Transmissão';
      case ComponentType.battery:
        return 'Bateria';
      case ComponentType.airFilter:
        return 'Filtro de Ar';
      case ComponentType.oilFilter:
        return 'Filtro de Óleo';
    }
  }

  String get urgencyLevel {
    if (urgency >= 0.8) return 'Crítica';
    if (urgency >= 0.6) return 'Alta';
    if (urgency >= 0.4) return 'Média';
    return 'Baixa';
  }

  int get daysUntilMaintenance {
    return predictedDate.difference(DateTime.now()).inDays;
  }
}

/// Alerta de manutenção
class MaintenanceAlert {
  final ComponentType componentType;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;

  MaintenanceAlert({
    required this.componentType,
    required this.severity,
    required this.message,
    required this.timestamp,
  });

  String get componentName {
    switch (componentType) {
      case ComponentType.brakes:
        return 'Freios';
      case ComponentType.engine:
        return 'Motor';
      case ComponentType.tires:
        return 'Pneus';
      case ComponentType.suspension:
        return 'Suspensão';
      case ComponentType.transmission:
        return 'Transmissão';
      case ComponentType.battery:
        return 'Bateria';
      case ComponentType.airFilter:
        return 'Filtro de Ar';
      case ComponentType.oilFilter:
        return 'Filtro de Óleo';
    }
  }

  String get severityText {
    switch (severity) {
      case AlertSeverity.critical:
        return 'Crítico';
      case AlertSeverity.high:
        return 'Alto';
      case AlertSeverity.medium:
        return 'Médio';
      case AlertSeverity.low:
        return 'Baixo';
    }
  }
}

/// Severidade do alerta
enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

