import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../models/location_data.dart';
import '../models/user.dart';
import 'user_avatar.dart';

class LocationCard extends StatelessWidget {
  final User user;
  final LocationData? location;
  final VoidCallback? onTap;

  const LocationCard({
    Key? key,
    required this.user,
    this.location,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(
                name: user.name,
                imageUrl: user.profileImageUrl,
                size: 48,
                isOnline: location != null && _isRecentLocation(location!),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    if (location != null) ...[
                      Text(
                        '${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(location!.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ] else
                      Text(
                        'Localização não disponível',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (location == null) {
      return const Icon(
        Icons.location_off,
        color: AppColors.textTertiary,
        size: 20,
      );
    }

    final isRecent = _isRecentLocation(location!);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isRecent ? AppColors.success.withOpacity(0.1) : AppColors.textTertiary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isRecent ? Icons.location_on : Icons.location_history,
        color: isRecent ? AppColors.success : AppColors.textTertiary,
        size: 16,
      ),
    );
  }

  bool _isRecentLocation(LocationData location) {
    final now = DateTime.now();
    final difference = now.difference(location.timestamp);
    return difference.inMinutes < 15; // Considera recente se foi há menos de 15 minutos
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inMinutes < 60) {
      return 'Há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Há ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }
}

