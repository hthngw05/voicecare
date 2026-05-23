import 'package:flutter/material.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';

class SeniorAvatar extends StatelessWidget {
  final Senior senior;
  final double size;

  const SeniorAvatar({super.key, required this.senior, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: senior.status.soft,
        border: Border.all(color: senior.status.color, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        senior.avatarInitials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
