import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Serviço para converter coordenadas em endereços reais
class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Cache para evitar chamadas desnecessárias à API
  final Map<String, String> _addressCache = {};
  
  // Usar OpenStreetMap Nominatim (gratuito) como alternativa ao Google Maps
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/reverse';
  
  /// Converte coordenadas em endereço legível
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Criar chave para cache
      String cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
      
      // Verificar cache primeiro
      if (_addressCache.containsKey(cacheKey)) {
        return _addressCache[cacheKey]!;
      }
      
      // Fazer requisição para API de geocoding
      final url = Uri.parse('$_baseUrl?lat=$latitude&lon=$longitude&format=json&addressdetails=1&accept-language=pt-BR');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SentinelAI/1.0 (Flutter App)',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && data['display_name'] != null) {
          String address = _formatAddress(data);
          
          // Salvar no cache
          _addressCache[cacheKey] = address;
          
          // Limitar tamanho do cache
          if (_addressCache.length > 100) {
            _addressCache.remove(_addressCache.keys.first);
          }
          
          debugPrint('📍 Endereço obtido: $address');
          return address;
        }
      }
      
      // Fallback para coordenadas se não conseguir obter endereço
      return _formatCoordinates(latitude, longitude);
      
    } catch (e) {
      debugPrint('❌ Erro ao obter endereço: $e');
      return _formatCoordinates(latitude, longitude);
    }
  }

  /// Formata o endereço a partir da resposta da API
  String _formatAddress(Map<String, dynamic> data) {
    try {
      final address = data['address'] as Map<String, dynamic>?;
      
      if (address == null) {
        return data['display_name'] ?? 'Endereço não disponível';
      }
      
      List<String> parts = [];
      
      // Adicionar número e rua
      if (address['house_number'] != null && address['road'] != null) {
        parts.add('${address['road']}, ${address['house_number']}');
      } else if (address['road'] != null) {
        parts.add(address['road']);
      }
      
      // Adicionar bairro
      if (address['neighbourhood'] != null) {
        parts.add(address['neighbourhood']);
      } else if (address['suburb'] != null) {
        parts.add(address['suburb']);
      }
      
      // Adicionar cidade
      if (address['city'] != null) {
        parts.add(address['city']);
      } else if (address['town'] != null) {
        parts.add(address['town']);
      } else if (address['village'] != null) {
        parts.add(address['village']);
      }
      
      // Adicionar estado
      if (address['state'] != null) {
        parts.add(address['state']);
      }
      
      // Se não conseguiu formar endereço, usar display_name
      if (parts.isEmpty) {
        String displayName = data['display_name'] ?? '';
        // Pegar apenas as primeiras 3 partes do display_name
        List<String> displayParts = displayName.split(', ');
        if (displayParts.length > 3) {
          parts = displayParts.take(3).toList();
        } else {
          parts = displayParts;
        }
      }
      
      return parts.join(', ');
      
    } catch (e) {
      debugPrint('❌ Erro ao formatar endereço: $e');
      return data['display_name'] ?? 'Endereço não disponível';
    }
  }

  /// Formata coordenadas como fallback
  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  /// Obtém endereço simplificado (apenas cidade e estado)
  Future<String> getSimpleAddress(double latitude, double longitude) async {
    try {
      String fullAddress = await getAddressFromCoordinates(latitude, longitude);
      
      // Se é coordenada, retornar como está
      if (fullAddress.contains(',') && fullAddress.split(',').length == 2) {
        try {
          double.parse(fullAddress.split(',')[0].trim());
          return fullAddress; // É coordenada
        } catch (e) {
          // Não é coordenada, continuar processamento
        }
      }
      
      // Extrair cidade e estado do endereço completo
      List<String> parts = fullAddress.split(', ');
      if (parts.length >= 2) {
        // Pegar as últimas 2 partes (geralmente cidade e estado)
        return parts.skip(parts.length - 2).join(', ');
      }
      
      return fullAddress;
      
    } catch (e) {
      debugPrint('❌ Erro ao obter endereço simples: $e');
      return _formatCoordinates(latitude, longitude);
    }
  }

  /// Obtém apenas a cidade
  Future<String> getCityName(double latitude, double longitude) async {
    try {
      final url = Uri.parse('$_baseUrl?lat=$latitude&lon=$longitude&format=json&addressdetails=1&accept-language=pt-BR');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SentinelAI/1.0 (Flutter App)',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        
        if (address != null) {
          return address['city'] ?? 
                 address['town'] ?? 
                 address['village'] ?? 
                 'Cidade não identificada';
        }
      }
      
      return 'Cidade não identificada';
      
    } catch (e) {
      debugPrint('❌ Erro ao obter nome da cidade: $e');
      return 'Cidade não identificada';
    }
  }

  /// Limpa o cache de endereços
  void clearCache() {
    _addressCache.clear();
    debugPrint('🗑️ Cache de endereços limpo');
  }

  /// Obtém estatísticas do cache
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _addressCache.length,
      'maxCacheSize': 100,
    };
  }
}

