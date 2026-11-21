import 'package:flutter/material.dart';

enum PasswordStrengthRating { weak, moderate, strong, veryStrong }

class PasswordStrength {
  static PasswordStrengthRating calculate(String password) {
    if (password.length < 8) return PasswordStrengthRating.weak;

    int score = 0;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrengthRating.weak;
    if (score <= 4) return PasswordStrengthRating.moderate;
    if (score == 5) return PasswordStrengthRating.strong;
    return PasswordStrengthRating.veryStrong;
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final rating = PasswordStrength.calculate(password);
    Color color;
    String label;
    double progress;

    switch (rating) {
      case PasswordStrengthRating.weak:
        color = Colors.redAccent;
        label = 'Weak';
        progress = 0.25;
        break;
      case PasswordStrengthRating.moderate:
        color = Colors.orangeAccent;
        label = 'Moderate';
        progress = 0.50;
        break;
      case PasswordStrengthRating.strong:
        color = Colors.lightGreen;
        label = 'Strong';
        progress = 0.75;
        break;
      case PasswordStrengthRating.veryStrong:
        color = Colors.green;
        label = 'Very Strong';
        progress = 1.0;
        break;
    }

    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          color: color,
          backgroundColor: Colors.white12,
          minHeight: 4,
        ),
        const SizedBox(height: 4),
        Text(
          'Password Strength: $label',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
