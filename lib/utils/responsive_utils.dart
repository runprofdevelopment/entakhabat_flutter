import 'package:flutter/material.dart';

class ResponsiveUtils {
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getFontSize(BuildContext context, double percentage) {
    return screenWidth(context) * percentage;
  }

  static double getHeight(BuildContext context, double percentage) {
    return screenHeight(context) * percentage;
  }

  static double getWidth(BuildContext context, double percentage) {
    return screenWidth(context) * percentage;
  }

  static EdgeInsets getPadding(BuildContext context, {
    double horizontal = 0.05,
    double vertical = 0.02,
  }) {
    return EdgeInsets.symmetric(
      horizontal: screenWidth(context) * horizontal,
      vertical: screenHeight(context) * vertical,
    );
  }

  static EdgeInsets getMargin(BuildContext context, {
    double horizontal = 0.05,
    double vertical = 0.02,
  }) {
    return EdgeInsets.symmetric(
      horizontal: screenWidth(context) * horizontal,
      vertical: screenHeight(context) * vertical,
    );
  }

  static double getIconSize(BuildContext context, double percentage) {
    return screenWidth(context) * percentage;
  }

  static double getButtonSize(BuildContext context, double percentage) {
    return screenWidth(context) * percentage;
  }

  static double getImageSize(BuildContext context, double percentage) {
    return screenWidth(context) * percentage;
  }

  // Responsive breakpoints
  static bool isMobile(BuildContext context) {
    return screenWidth(context) < 600;
  }

  static bool isTablet(BuildContext context) {
    return screenWidth(context) >= 600 && screenWidth(context) < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return screenWidth(context) >= 1200;
  }

  // Responsive text styles
  static TextStyle getResponsiveTextStyle(
    BuildContext context, {
    double fontSizePercentage = 0.04,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontSize: getFontSize(context, fontSizePercentage),
      fontWeight: fontWeight,
      color: color,
    );
  }

  // Responsive container
  static Widget responsiveContainer(
    BuildContext context, {
    required Widget child,
    double? widthPercentage,
    double? heightPercentage,
    EdgeInsets? padding,
    EdgeInsets? margin,
    BoxDecoration? decoration,
  }) {
    return Container(
      width: widthPercentage != null ? getWidth(context, widthPercentage) : null,
      height: heightPercentage != null ? getHeight(context, heightPercentage) : null,
      padding: padding ?? getPadding(context),
      margin: margin ?? getMargin(context),
      decoration: decoration,
      child: child,
    );
  }

  // Responsive spacing
  static Widget responsiveSpacing(BuildContext context, {
    double heightPercentage = 0.02,
    double widthPercentage = 0.0,
  }) {
    return SizedBox(
      height: getHeight(context, heightPercentage),
      width: getWidth(context, widthPercentage),
    );
  }
} 