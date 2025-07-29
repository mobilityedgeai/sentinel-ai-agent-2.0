import 'package:flutter/material.dart';

class AppColors {
  // Cores principais baseadas no Life360
  static const Color primary = Color(0xFF6366F1); // Azul principal
  static const Color accent = Color(0xFF8B5CF6); // Cor de destaque
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF8B5CF6);
  
  // Cores de sucesso e segurança
  static const Color success = Color(0xFF10B981); // Verde
  static const Color successLight = Color(0xFF34D399);
  static const Color successDark = Color(0xFF059669);
  
  // Cores de alerta e perigo
  static const Color warning = Color(0xFFF59E0B); // Amarelo
  static const Color danger = Color(0xFFEF4444); // Vermelho
  static const Color dangerLight = Color(0xFFF87171);
  
  // Cores neutras
  static const Color background = Color(0xFFF3F4F6); // Cinza claro
  static const Color surface = Color(0xFFFFFFFF); // Branco
  static const Color surfaceVariant = Color(0xFFF9FAFB);
  
  // Cores de texto
  static const Color textPrimary = Color(0xFF111827); // Preto
  static const Color textSecondary = Color(0xFF6B7280); // Cinza médio
  static const Color textTertiary = Color(0xFF9CA3AF); // Cinza claro
  
  // Cores específicas para telemática
  static const Color hardBraking = Color(0xFFDC2626); // Vermelho escuro
  static const Color rapidAcceleration = Color(0xFFEA580C); // Laranja
  static const Color speeding = Color(0xFFCA8A04); // Amarelo escuro
  static const Color safetyGood = Color(0xFF16A34A); // Verde escuro
  static const Color safetyMedium = Color(0xFFEAB308); // Amarelo
  static const Color safetyPoor = Color(0xFFDC2626); // Vermelho
  
  // Cores para mapas
  static const Color mapPrimary = Color(0xFF3B82F6); // Azul mapa
  static const Color mapSecondary = Color(0xFF8B5CF6); // Roxo
  static const Color userLocation = Color(0xFF10B981); // Verde para localização do usuário
  
  // Gradientes
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient safetyGradient = LinearGradient(
    colors: [safetyGood, success],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

