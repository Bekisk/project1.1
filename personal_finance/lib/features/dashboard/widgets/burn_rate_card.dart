import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';

class BurnRateCard extends StatelessWidget {
  final DashboardSummary summary;
  final bool isDark;

  const BurnRateCard({super.key, required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runwayDays = summary.runwayDays;
    final totalBalance = summary.totalBalance;
    final daily30 = summary.dailySpend30Days;
    final daily7 = summary.dailySpend7Days;

    // Visual status styling
    final Color runwayColor;
    final String runwayLabel;
    final IconData runwayIcon;

    if (totalBalance <= 0) {
      runwayColor = AppTheme.expenseRed;
      runwayLabel = 'Balance Depleted';
      runwayIcon = Icons.warning_amber_rounded;
    } else if (daily30 == 0 && daily7 == 0) {
      runwayColor = AppTheme.primaryGreen;
      runwayLabel = 'Zero Recent Outflow';
      runwayIcon = Icons.shield_rounded;
    } else if (runwayDays < 14) {
      runwayColor = Colors.redAccent;
      runwayLabel = 'Critical Runway';
      runwayIcon = Icons.error_outline_rounded;
    } else if (runwayDays < 30) {
      runwayColor = AppTheme.accentAmber;
      runwayLabel = 'Caution';
      runwayIcon = Icons.hourglass_bottom_rounded;
    } else {
      runwayColor = AppTheme.primaryGreen;
      runwayLabel = 'Healthy Runway';
      runwayIcon = Icons.check_circle_outline_rounded;
    }

    return FintechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: runwayColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(runwayIcon, color: runwayColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Financial Health & Burn Rate',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: runwayColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  runwayLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: runwayColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Runway Headline
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESTIMATED CASH RUNWAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                if (daily30 == 0 && daily7 == 0)
                  Text(
                    'No recent daily expenses detected. Your current cash balance of ${CurrencyFormatter.formatCents(totalBalance)} is fully intact.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (totalBalance <= 0)
                  Text(
                    'Your available cash balance is zero or negative. Immediate liquidity deposit required.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      children: [
                        const TextSpan(
                          text: 'At your current spending rate, your balance will last ',
                        ),
                        TextSpan(
                          text: '$runwayDays days',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: runwayColor,
                            fontSize: 15,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 7-Day vs 30-Day Velocity Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  context,
                  title: '7-Day Daily Spend',
                  cents: daily7,
                  isDark: isDark,
                  subtitle: 'Short-term velocity',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricBlock(
                  context,
                  title: '30-Day Daily Spend',
                  cents: daily30,
                  isDark: isDark,
                  subtitle: 'Normalized baseline',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBlock(
    BuildContext context, {
    required String title,
    required int cents,
    required bool isDark,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${CurrencyFormatter.formatCents(cents)}/day',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9.5,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
