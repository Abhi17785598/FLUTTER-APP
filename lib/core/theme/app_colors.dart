import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5B50E8);
  static const Color primaryLight = Color(0xFFEEEDFE);
  static const Color accentPurple = Color(0xFF5B50E8);
  static const Color priceColor = Color(0xFF5B50E8);
  
  static const Color background = Color(0xFFF4F4F8);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  
  static const Color verifiedBadge = Color(0xFF10B981);
  static const Color verifiedBadgeText = Color(0xFFFFFFFF);
  
  // Status Chip Colors
  static const Color statusAvailable = Color(0xFF22C55E);
  static const Color statusBooked = Color(0xFFF97316);
  static const Color statusSold = Color(0xFFEF4444);
  static const Color statusPending = Color(0xFFEAB308);
  static const Color statusNewLaunch = Color(0xFF3B82F6);
  
  // Additional Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF97316);
  static const Color error = Color(0xFFEF4444);
  static const Color statusTopBuilderText = Color(0xFF5B50E8);
  static const Color statusGatedCommunityBg = Color(0xFFEEF2FF);
  static const Color statusGatedCommunityText = Color(0xFF5B50E8);
  static const Color statusPremiumBg = Color(0xFF5B50E8);
  static const Color statusPremiumText = Color(0xFFFFFFFF);
  static const Color statusLoanAvailableText = Color(0xFF1ABC9C);

  // Gradient helpers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B50E8), Color(0xFF7C72F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3D35B8), Color(0xFF5B50E8), Color(0xFF7C72F0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium card shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0xFF5B50E8).withOpacity(0.10),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Glow effect for interactive elements
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0xFF5B50E8).withOpacity(0.35),
      blurRadius: 16,
      spreadRadius: -2,
    ),
  ];
  
  // Category icon backgrounds
  static const Color categoryBuyBg = Color(0xFFEEEDFE);
  static const Color categoryRentBg = Color(0xFFE6F1FB);
  static const Color categoryPlotBg = Color(0xFFEAF3DE);
  static const Color categoryCommercialBg = Color(0xFFFFF3E0);
  static const Color categoryPgBg = Color(0xFFFCE4EC);
  
  // Amenity icon backgrounds
  static const Color amenityIndigo = Color(0xFF6366F1);
  static const Color amenityBlue = Color(0xFF3B82F6);
  static const Color amenityOrange = Color(0xFFF97316);
  static const Color amenityGreen = Color(0xFF22C55E);
  static const Color amenityRed = Color(0xFFEF4444);

  static Color getStatusChipBg(String label) {
    switch (label) {
      case 'Ready to Move':
        return statusAvailable;
      case 'Under Construction':
        return statusPending;
      case 'Top Builder':
        return statusTopBuilderText;
      case 'Gated Community':
        return statusGatedCommunityBg;
      case 'Premium':
        return statusPremiumBg;
      case 'Loan Available':
        return primaryLight;
      default:
        return primaryLight;
    }
  }
  
  static Color getStatusChipText(String label) {
    switch (label) {
      case 'Ready to Move':
        return Colors.white;
      case 'Under Construction':
        return textPrimary;
      case 'Top Builder':
        return statusTopBuilderText;
      case 'Gated Community':
        return statusGatedCommunityText;
      case 'Premium':
        return statusPremiumText;
      case 'Loan Available':
        return statusLoanAvailableText;
      default:
        return textPrimary;
    }
  }
}
