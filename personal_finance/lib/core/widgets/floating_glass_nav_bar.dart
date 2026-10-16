import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';

/// Apple-inspired Liquid Glass Floating Capsule Navigation Bar
/// Featuring translucent emerald pill background, glowing mint selected icon container,
/// and smooth interactive feedback.
class FloatingGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navItems = [
      _NavItemData(
        icon: Icons.home_rounded,
        unselectedIcon: Icons.home_outlined,
        label: 'Home',
      ),
      _NavItemData(
        icon: Icons.bar_chart_rounded,
        unselectedIcon: Icons.bar_chart_outlined,
        label: 'Analytics',
      ),
      _NavItemData(
        icon: Icons.receipt_long_rounded,
        unselectedIcon: Icons.receipt_long_outlined,
        label: 'History',
      ),
      _NavItemData(
        icon: Icons.savings_rounded,
        unselectedIcon: Icons.savings_outlined,
        label: 'Goals',
      ),
      _NavItemData(
        icon: Icons.person_rounded,
        unselectedIcon: Icons.person_outline_rounded,
        label: 'Profile',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.secondaryBlack : null,
            gradient: isDark
                ? null
                : const LinearGradient(
                    colors: [Color(0xF0FFFFFF), Color(0xF0EBF7F3)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isDark ? AppTheme.borderPrimary : const Color(0xFFC7EADB),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = currentIndex == index;

              return GestureDetector(
                onTap: () => onTabSelected(index),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 44 : 38,
                      height: isSelected ? 44 : 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF202020)
                                  : AppTheme.primaryAccent.withValues(
                                      alpha: 0.18,
                                    ))
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: isDark
                                    ? AppTheme.borderTertiary
                                    : AppTheme.primaryAccent.withValues(
                                        alpha: 0.6,
                                      ),
                                width: 1.2,
                              )
                            : null,
                      ),
                      child: Icon(
                        isSelected ? item.icon : item.unselectedIcon,
                        size: 22,
                        color: isSelected
                            ? (isDark
                                  ? AppTheme.pureWhite
                                  : const Color(0xFF065F46))
                            : (isDark
                                  ? AppTheme.tertiaryGray
                                  : const Color(0xFF6B8B82)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData unselectedIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.unselectedIcon,
    required this.label,
  });
}
