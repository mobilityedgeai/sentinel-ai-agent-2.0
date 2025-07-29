import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/database_service.dart';
import '../services/permission_manager.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class SettingsScreenReal extends StatefulWidget {
  @override
  _SettingsScreenRealState createState() => _SettingsScreenRealState();
}

class _SettingsScreenRealState extends State<SettingsScreenReal> {
  bool _locationEnabled = false;
  bool _notificationsEnabled = false;
  bool _autoTripDetection = true;
  bool _backgroundTracking = true;
  double _speedThreshold = 80.0;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final permissionManager = Provider.of<PermissionManager>(context, listen: false);
      
      final locationPermission = permissionManager.hasLocationPermission;
      final notificationPermission = permissionManager.hasNotificationPermission;
      
      if (mounted) {
        setState(() {
          _locationEnabled = locationPermission;
          _notificationsEnabled = notificationPermission;
        });
      }
    } catch (e) {
      print('Erro ao carregar configurações: $e');
    }
  }

  Future<void> _toggleLocationPermission(bool value) async {
    try {
      final permissionManager = Provider.of<PermissionManager>(context, listen: false);
      
      if (value) {
        final granted = await permissionManager.requestLocationPermission();
        if (granted) {
          setState(() {
            _locationEnabled = true;
          });
          _showSuccessMessage('Permissão de localização concedida');
        } else {
          _showErrorMessage('Permissão de localização negada');
        }
      } else {
        _showInfoDialog(
          'Desabilitar Localização',
          'Para desabilitar a localização, vá para as configurações do sistema e remova a permissão manualmente.',
        );
      }
    } catch (e) {
      _showErrorMessage('Erro ao alterar permissão de localização');
    }
  }

  Future<void> _toggleNotificationPermission(bool value) async {
    try {
      final permissionManager = Provider.of<PermissionManager>(context, listen: false);
      
      if (value) {
        final granted = await permissionManager.requestNotificationPermission();
        if (granted) {
          setState(() {
            _notificationsEnabled = true;
          });
          _showSuccessMessage('Permissão de notificação concedida');
        } else {
          _showErrorMessage('Permissão de notificação negada');
        }
      } else {
        _showInfoDialog(
          'Desabilitar Notificações',
          'Para desabilitar as notificações, vá para as configurações do sistema e remova a permissão manualmente.',
        );
      }
    } catch (e) {
      _showErrorMessage('Erro ao alterar permissão de notificação');
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await _showConfirmDialog(
      'Limpar Todos os Dados',
      'Esta ação irá remover todas as viagens, eventos e dados armazenados. Esta ação não pode ser desfeita.',
    );
    
    if (confirmed) {
      try {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        await databaseService.clearAllData();
        _showSuccessMessage('Todos os dados foram removidos');
      } catch (e) {
        _showErrorMessage('Erro ao limpar dados: $e');
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final result = await databaseService.exportData();
      
      if (result) {
        _showSuccessMessage('Dados exportados com sucesso');
      } else {
        _showErrorMessage('Erro ao exportar dados');
      }
    } catch (e) {
      _showErrorMessage('Erro ao exportar dados: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Configurações',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Seção de Permissões
          _buildSectionHeader('Permissões'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Localização'),
                  subtitle: Text('Necessário para rastreamento GPS'),
                  value: _locationEnabled,
                  onChanged: _toggleLocationPermission,
                  activeColor: AppColors.primary,
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text('Notificações'),
                  subtitle: Text('Alertas de eventos de condução'),
                  value: _notificationsEnabled,
                  onChanged: _toggleNotificationPermission,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Seção de Rastreamento
          _buildSectionHeader('Rastreamento'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Detecção Automática de Viagens'),
                  subtitle: Text('Iniciar/parar viagens automaticamente'),
                  value: _autoTripDetection,
                  onChanged: (value) {
                    setState(() {
                      _autoTripDetection = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Divider(height: 1),
                SwitchListTile(
                  title: Text('Rastreamento em Background'),
                  subtitle: Text('Continuar rastreando com app fechado'),
                  value: _backgroundTracking,
                  onChanged: (value) {
                    setState(() {
                      _backgroundTracking = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Seção de Alertas
          _buildSectionHeader('Alertas de Velocidade'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limite de Velocidade: ${_speedThreshold.toInt()} km/h',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Slider(
                    value: _speedThreshold,
                    min: 40,
                    max: 120,
                    divisions: 8,
                    label: '${_speedThreshold.toInt()} km/h',
                    onChanged: (value) {
                      setState(() {
                        _speedThreshold = value;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  Text(
                    'Receber alerta quando exceder este limite',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 24),
          
          // Seção de Dados
          _buildSectionHeader('Gerenciar Dados'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.file_download,
                    color: AppColors.primary,
                  ),
                  title: Text('Exportar Dados'),
                  subtitle: Text('Salvar viagens e eventos em arquivo'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _exportData,
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                  ),
                  title: Text('Limpar Todos os Dados'),
                  subtitle: Text('Remover todas as viagens e eventos'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: _clearAllData,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Seção Sobre
          _buildSectionHeader('Sobre'),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info,
                    color: AppColors.primary,
                  ),
                  title: Text('Versão do App'),
                  subtitle: Text('Sentinel AI v1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.privacy_tip,
                    color: AppColors.primary,
                  ),
                  title: Text('Política de Privacidade'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    _showInfoDialog(
                      'Política de Privacidade',
                      'O Sentinel AI armazena todos os dados localmente no seu dispositivo. '
                      'Nenhuma informação pessoal é enviada para servidores externos. '
                      'Você tem controle total sobre seus dados.',
                    );
                  },
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.help,
                    color: AppColors.primary,
                  ),
                  title: Text('Ajuda e Suporte'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () {
                    _showInfoDialog(
                      'Ajuda e Suporte',
                      'Para obter ajuda com o Sentinel AI:\n\n'
                      '• Verifique se todas as permissões estão concedidas\n'
                      '• Mantenha o GPS ativado para melhor precisão\n'
                      '• O app funciona melhor com internet ativa\n'
                      '• Reinicie o app se encontrar problemas',
                    );
                  },
                ),
              ],
            ),
          ),
          
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

