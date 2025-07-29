import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/trip_manager.dart';
import '../services/sensor_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TripManager _tripManager = TripManager();
  final SensorService _sensorService = SensorService();
  
  bool _autoTripDetection = true;
  bool _sensorMonitoring = false;
  bool _emergencyAlerts = true;
  bool _speedingAlerts = true;
  bool _hardBrakingAlerts = true;
  
  Map<String, dynamic>? _tripManagerStats;
  Map<String, dynamic>? _sensorStats;
  Map<String, dynamic>? _dataStats;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadStats();
  }

  void _loadSettings() {
    // Em uma implementação real, carregaria as configurações do SharedPreferences
    setState(() {
      _autoTripDetection = true;
      _sensorMonitoring = true; // Valor padrão
      _emergencyAlerts = true;
      _speedingAlerts = true;
      _hardBrakingAlerts = true;
    });
  }

  Future<void> _loadStats() async {
    try {
      final tripStats = _tripManager.getManagerStats();
      final sensorStats = <String, dynamic>{
        'totalSamples': 0,
        'isActive': true,
        'lastUpdate': DateTime.now().toString(),
      };
      
      setState(() {
        _tripManagerStats = tripStats;
        _sensorStats = sensorStats;
        _dataStats = {
          'totalTrips': 0,
          'totalEvents': 0,
          'totalDistance': 0.0,
        };
      });
    } catch (e) {
      print('Erro ao carregar estatísticas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetectionSection(),
            const SizedBox(height: 16),
            _buildAlertsSection(),
            const SizedBox(height: 16),
            _buildDebugSection(),
            const SizedBox(height: 16),
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detecção Automática',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Detecção Automática de Viagens'),
              subtitle: const Text('Usar Google Activity Recognition para detectar quando você está dirigindo'),
              value: _autoTripDetection,
              onChanged: (value) {
                setState(() {
                  _autoTripDetection = value;
                });
                // Implementar lógica de ativação/desativação
              },
            ),
            SwitchListTile(
              title: const Text('Monitoramento de Sensores'),
              subtitle: const Text('Usar sensores do dispositivo para análise de telemática'),
              value: _sensorMonitoring,
              onChanged: (value) async {
                // Métodos serão implementados futuramente
                setState(() {
                  _sensorMonitoring = value;
                });
                await _loadStats();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alertas e Notificações',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Alertas de Emergência'),
              subtitle: const Text('Notificar contatos em caso de acidente detectado'),
              value: _emergencyAlerts,
              onChanged: (value) {
                setState(() {
                  _emergencyAlerts = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Alertas de Velocidade'),
              subtitle: const Text('Notificar quando exceder o limite de velocidade'),
              value: _speedingAlerts,
              onChanged: (value) {
                setState(() {
                  _speedingAlerts = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Alertas de Frenagem Brusca'),
              subtitle: const Text('Notificar quando detectar frenagem brusca'),
              value: _hardBrakingAlerts,
              onChanged: (value) {
                setState(() {
                  _hardBrakingAlerts = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informações de Debug',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Status do Trip Manager'),
              subtitle: Text(_getTripManagerStatus()),
              trailing: const Icon(Icons.info_outline),
              onTap: () => _showTripManagerDetails(),
            ),
            ListTile(
              title: const Text('Status dos Sensores'),
              subtitle: Text(_getSensorStatus()),
              trailing: const Icon(Icons.sensors),
              onTap: () => _showSensorDetails(),
            ),
            ListTile(
              title: const Text('Estatísticas do Banco'),
              subtitle: Text(_getDataStatus()),
              trailing: const Icon(Icons.storage),
              onTap: () => _showDataDetails(),
            ),
            const Divider(),
            ListTile(
              title: const Text('Gerar Dados de Teste'),
              subtitle: const Text('Criar dados de exemplo para demonstração'),
              trailing: const Icon(Icons.add_circle),
              onTap: () {
                // Método será implementado futuramente
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
                );
              },
            ),
            ListTile(
              title: const Text('Simular Viagem'),
              subtitle: const Text('Iniciar simulação de viagem em tempo real'),
              trailing: const Icon(Icons.play_circle),
              onTap: () {
                // Método será implementado futuramente
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulação em desenvolvimento')),
                );
              },
            ),
            ListTile(
              title: const Text('Limpar Dados'),
              subtitle: const Text('Remover todos os dados do banco'),
              trailing: const Icon(Icons.delete, color: AppColors.danger),
              onTap: _confirmClearData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sobre o Sentinel AI',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Versão'),
              subtitle: const Text('1.0.0'),
              trailing: const Icon(Icons.info),
            ),
            ListTile(
              title: const Text('Desenvolvido por'),
              subtitle: const Text('Equipe Sentinel AI'),
              trailing: const Icon(Icons.people),
            ),
            ListTile(
              title: const Text('Tecnologias'),
              subtitle: const Text('Flutter, SQLite, Google Activity Recognition'),
              trailing: const Icon(Icons.code),
            ),
            const SizedBox(height: 8),
            Text(
              'O Sentinel AI é um aplicativo avançado de telemática móvel que utiliza inteligência artificial para monitorar e analisar padrões de condução, proporcionando maior segurança para você e sua família.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTripManagerStatus() {
    if (_tripManagerStats == null) return 'Carregando...';
    
    final isInitialized = _tripManagerStats!['isInitialized'] as bool;
    final isOnTrip = _tripManagerStats!['isOnTrip'] as bool;
    
    if (!isInitialized) return 'Não inicializado';
    if (isOnTrip) return 'Viagem ativa';
    return 'Aguardando viagem';
  }

  String _getSensorStatus() {
    if (_sensorStats == null) return 'Carregando...';
    
    final isMonitoring = _sensorStats!['isMonitoring'] as bool;
    final bufferSize = _sensorStats!['bufferSize'] as int;
    
    if (!isMonitoring) return 'Desativado';
    return 'Ativo ($bufferSize leituras)';
  }

  String _getDataStatus() {
    if (_dataStats == null) return 'Carregando...';
    
    final users = _dataStats!['users'] as int;
    final trips = _dataStats!['trips'] as int;
    final events = _dataStats!['events'] as int;
    
    return '$users usuários, $trips viagens, $events eventos';
  }

  void _showTripManagerDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status do Trip Manager'),
        content: SingleChildScrollView(
          child: Text(_tripManagerStats?.toString() ?? 'Dados não disponíveis'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showSensorDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status dos Sensores'),
        content: SingleChildScrollView(
          child: Text(_sensorStats?.toString() ?? 'Dados não disponíveis'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showDataDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estatísticas do Banco'),
        content: SingleChildScrollView(
          child: Text(_dataStats?.toString() ?? 'Dados não disponíveis'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Tem certeza que deseja remover todos os dados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
              await _loadStats();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dados removidos com sucesso!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    try {
      // Implementar limpeza real dos dados do banco SQLite
      print('Limpando dados reais do banco SQLite...');
    } catch (e) {
      print('Erro ao limpar dados: $e');
    }
  }
}

