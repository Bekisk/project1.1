import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';

class InflowOutflowRatioBar extends StatelessWidget {
  final int totalIncomeCents;
  final int totalExpenseCents;
  final bool isDark;

  const InflowOutflowRatioBar({
    super.key,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalFlow = totalIncomeCents + totalExpenseCents;

    final double incomeRatio = totalFlow > 0
        ? (totalIncomeCents / totalFlow).clamp(0.0, 1.0)
        : 0.5;
    final double expenseRatio = totalFlow > 0
        ? (totalExpenseCents / totalFlow).clamp(0.0, 1.0)
        : 0.5;

    final int netCents = totalIncomeCents - totalExpenseCents;
    final bool isNetPositive = netCents >= 0;

    return FintechCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color:
                          (isNetPositive
                                  ? AppTheme.primaryGreen
                                  : AppTheme.expenseRed)
                              .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isNetPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isNetPositive
                          ? AppTheme.primaryGreen
                          : AppTheme.expenseRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Inflow vs. Outflow Cash Flow',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isNetPositive ? AppTheme.primaryGreen : Colors.redAccent)
                          .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNetPositive
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      size: 12,
                      color: isNetPositive
                          ? AppTheme.primaryGreen
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNetPositive ? 'Net Positive' : 'Net Negative',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isNetPositive
                            ? AppTheme.primaryGreen
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: totalFlow == 0
                  ? Container(color: isDark ? Colors.white10 : Colors.black12)
                  : Row(
                      children: [
                        Flexible(
                          flex: (incomeRatio * 1000).toInt(),
                          child: Container(color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          flex: (expenseRatio * 1000).toInt(),
                          child: Container(color: AppTheme.expenseRed),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Inflow vs Outflow Numerical Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Inflow Column
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Inflow (${(incomeRatio * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(totalIncomeCents),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Outflow Column
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.expenseRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Outflow (${(expenseRatio * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(totalExpenseCents),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Net Difference Indicator Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Surplus / Deficit:',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                Text(
                  '${isNetPositive ? "+" : ""}${CurrencyFormatter.formatCents(netCents)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isNetPositive
                        ? AppTheme.primaryGreen
                        : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
