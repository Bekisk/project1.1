import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';

class SpendingDistributionDonutChart extends StatefulWidget {
  final List<CategorySpending> topCategories;
  final int totalExpenseCents;
  final bool isDark;

  const SpendingDistributionDonutChart({
    super.key,
    required this.topCategories,
    required this.totalExpenseCents,
    required this.isDark,
  });

  @override
  State<SpendingDistributionDonutChart> createState() =>
      _SpendingDistributionDonutChartState();
}

class _SpendingDistributionDonutChartState
    extends State<SpendingDistributionDonutChart> {
  int _touchedIndex = -1;

  static const List<Color> _palette = [
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF6366F1), // Indigo
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData =
        widget.topCategories.isNotEmpty && widget.totalExpenseCents > 0;

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
                      color: AppTheme.primaryNavy.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Category Distribution',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              if (hasData)
                Text(
                  '${widget.topCategories.length} Categories',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.donut_large_rounded,
                      size: 40,
                      color: widget.isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No expense distribution data available for this period',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Donut Chart Display
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 52,
                      sections: _generateSections(),
                    ),
                  ),
                  // Donut Center Total Label
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _touchedIndex >= 0 &&
                                _touchedIndex < widget.topCategories.length
                            ? widget.topCategories[_touchedIndex].category.name
                            : 'Total Outflow',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _touchedIndex >= 0 &&
                                _touchedIndex < widget.topCategories.length
                            ? '${(widget.topCategories[_touchedIndex].percentage * 100).toStringAsFixed(1)}%'
                            : CurrencyFormatter.formatCents(
                                widget.totalExpenseCents,
                              ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Legend Grid
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: widget.topCategories.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final color = _palette[idx % _palette.length];
                final isSelected = _touchedIndex == idx;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _touchedIndex = _touchedIndex == idx ? -1 : idx;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.category.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: widget.isDark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(item.percentage * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections() {
    return widget.topCategories.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;
      final isTouched = idx == _touchedIndex;
      final radius = isTouched ? 32.0 : 26.0;
      final color = _palette[idx % _palette.length];

      return PieChartSectionData(
        color: color,
        value: item.totalCents.toDouble(),
        title: '',
        radius: radius,
      );
    }).toList();
  }
}
