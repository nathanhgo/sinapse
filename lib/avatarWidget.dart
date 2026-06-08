import 'package:flutter/material.dart';
import 'profilePage.dart';

class AvatarWidget extends StatelessWidget {
  final String avatarKey;
  final double size;
  final Color? color;
  final Color backgroundColor;
  final List<BoxShadow>? boxShadow;

  const AvatarWidget({
    super.key,
    required this.avatarKey,
    required this.size,
    this.color,
    this.backgroundColor = Colors.white,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final double iconSize = size * 0.6;
    final iconColor = color ?? const Color(0xFF1565C0);

    Widget child;
    if (avatarKey.startsWith('http://') || avatarKey.startsWith('https://')) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarKey,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.person_rounded,
            size: iconSize,
            color: iconColor,
          ),
        ),
      );
    } else {
      child = Icon(
        ProfilePage.avatarIcons[avatarKey] ?? Icons.psychology,
        size: iconSize,
        color: iconColor,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: boxShadow,
      ),
      child: Center(child: child),
    );
  }
}
