import 'package:flutter/material.dart';
import '../shared/app_colors.dart';

class FlavorCard extends StatelessWidget {
  static const _borderRadius = BorderRadius.all(Radius.circular(12));
  static const _innerBorderRadius = BorderRadius.all(Radius.circular(8));

  final String flavorName;
  final Color color;
  final int value;
  final VoidCallback? onTap;
  final VoidCallback? onReset;

  const FlavorCard({
    super.key,
    required this.flavorName,
    required this.color,
    this.value = 0,
    this.onTap,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: _borderRadius,
      child: InkWell(
        borderRadius: _borderRadius,
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                flavorName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: AppColors.innerBoxBackground,
                  borderRadius: _innerBorderRadius,
                ),
                child: Center(
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (onReset != null)
                IconButton(
                  tooltip: 'Resetar',
                  onPressed: onReset,
                  icon: const Icon(Icons.restore, color: AppColors.textPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
