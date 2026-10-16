import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';

class PlaceholderSectionScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String milestoneInfo;

  const PlaceholderSectionScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.milestoneInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FintechCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(
                      alpha: isDark ? 0.2 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accentAmber.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppTheme.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        milestoneInfo,
                        style: const TextStyle(
                          color: AppTheme.accentAmber,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
