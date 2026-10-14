import 'dart:io';
import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imagePath;
  final String displayName;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const ProfileAvatar({
    super.key,
    this.imagePath,
    required this.displayName,
    this.radius = 24,
    this.onTap,
    this.showEditBadge = false,
  });

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = parts[0].characters.first;
      final second = parts[1].characters.first;
      return '$first$second'.toUpperCase();
    } else {
      return parts[0].characters.first.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initials = _getInitials(displayName);

    Widget avatarContent;
    final file = imagePath != null && imagePath!.isNotEmpty ? File(imagePath!) : null;

    if (file != null && file.existsSync()) {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: isDark ? const Color(0xFF0F5747) : const Color(0xFFD1EBE3),
        backgroundImage: FileImage(file),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: radius,
        backgroundColor: isDark ? const Color(0xFF0F5747) : const Color(0xFFD1EBE3),
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  fontSize: radius * 0.78,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.primaryAccent : const Color(0xFF0B4639),
                  letterSpacing: -0.5,
                ),
              )
            : Icon(
                Icons.person_rounded,
                size: radius * 1.1,
                color: isDark ? AppTheme.primaryAccent : const Color(0xFF0B4639),
              ),
      );
    }

    Widget child = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryAccent.withValues(alpha: 0.4),
          width: radius > 30 ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryAccent.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (showEditBadge) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF0D1F1A) : Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return child;
  }
}
