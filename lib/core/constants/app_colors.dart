import 'package:flutter/material.dart';

/// Pure RGB colors for LED control
/// These return exact color values without Material Design tinting
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();
  
  // Pure basic colors for LED control (0xAARRGGBB format)
  static const Color pureRed = Color(0xFFFF0000);      // #FF0000
  static const Color pureGreen = Color(0xFF00FF00);    // #00FF00
  static const Color pureBlue = Color(0xFF0000FF);     // #0000FF
  static const Color pureWhite = Color(0xFFFFFFFF);    // #FFFFFF
  static const Color pureYellow = Color(0xFFFFFF00);   // #FFFF00
  static const Color pureCyan = Color(0xFF00FFFF);     // #00FFFF
  static const Color pureMagenta = Color(0xFFFF00FF);  // #FF00FF
  static const Color pureBlack = Color(0xFF000000);    // #000000
  
  // LED-specific utility methods
  static int colorToRGB24(Color color) {
    return (color.red << 16) | (color.green << 8) | color.blue;
  }
  
  static String colorToHex(Color color) {
    return '#${colorToRGB24(color).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}