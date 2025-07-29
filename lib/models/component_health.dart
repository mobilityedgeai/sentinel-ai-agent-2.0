/// Tipos de componentes do veículo
enum ComponentType {
  brakes,
  engine,
  tires,
  suspension,
  transmission,
  battery,
  airFilter,
  oilFilter,
}

/// Níveis de criticidade
enum CriticalityLevel {
  low,
  medium,
  high,
  critical,
}

/// Saúde de um componente do veículo
class ComponentHealth {
  final ComponentType type;
  final double healthScore; // 0-100
  final double wearLevel; // 0-1
  final double lastMaintenanceKm;
  final DateTime lastMaintenanceDate;
  final double nextMaintenanceKm;
  final DateTime nextMaintenanceDate;
  final double estimatedLifeRemaining; // 0-1
  final CriticalityLevel criticalityLevel;

  ComponentHealth({
    required this.type,
    required this.healthScore,
    required this.wearLevel,
    required this.lastMaintenanceKm,
    required this.lastMaintenanceDate,
    required this.nextMaintenanceKm,
    required this.nextMaintenanceDate,
    required this.estimatedLifeRemaining,
    required this.criticalityLevel,
  });

  String get componentName {
    switch (type) {
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

  String get criticalityText {
    switch (criticalityLevel) {
      case CriticalityLevel.low:
        return 'Baixa';
      case CriticalityLevel.medium:
        return 'Média';
      case CriticalityLevel.high:
        return 'Alta';
      case CriticalityLevel.critical:
        return 'Crítica';
    }
  }

  double get maintenanceProgress {
    // Progresso até a próxima manutenção (0-1)
    return wearLevel;
  }

  bool get needsMaintenance {
    return healthScore < 50 || criticalityLevel == CriticalityLevel.critical;
  }

  int get daysUntilMaintenance {
    return nextMaintenanceDate.difference(DateTime.now()).inDays;
  }

  ComponentHealth copyWith({
    ComponentType? type,
    double? healthScore,
    double? wearLevel,
    double? lastMaintenanceKm,
    DateTime? lastMaintenanceDate,
    double? nextMaintenanceKm,
    DateTime? nextMaintenanceDate,
    double? estimatedLifeRemaining,
    CriticalityLevel? criticalityLevel,
  }) {
    return ComponentHealth(
      type: type ?? this.type,
      healthScore: healthScore ?? this.healthScore,
      wearLevel: wearLevel ?? this.wearLevel,
      lastMaintenanceKm: lastMaintenanceKm ?? this.lastMaintenanceKm,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceKm: nextMaintenanceKm ?? this.nextMaintenanceKm,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      estimatedLifeRemaining: estimatedLifeRemaining ?? this.estimatedLifeRemaining,
      criticalityLevel: criticalityLevel ?? this.criticalityLevel,
    );
  }
}

