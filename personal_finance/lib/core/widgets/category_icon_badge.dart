import 'package:flutter/material.dart';

/// Helper mapping database category icons & colors to refined Material Icons
class CategoryIconBadge extends StatelessWidget {
  final String iconKey;
  final String? colorKey;
  final double size;
  final double iconSize;

  const CategoryIconBadge({
    super.key,
    required this.iconKey,
    this.colorKey,
    this.size = 40,
    this.iconSize = 20,
  });

  static IconData getIcon(String key) {
    switch (key) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'store':
        return Icons.store_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  static Color getColor(String? key, {bool isDark = false}) {
    if (key == null) return const Color(0xFF10B981);
    try {
      final hex = key.replaceAll('#', '');
      return Color(int.parse(hex));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = getColor(colorKey, isDark: isDark);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Center(
        child: Icon(
          getIcon(iconKey),
          color: color,
          size: iconSize,
        ),
      ),
    );
  }
}
