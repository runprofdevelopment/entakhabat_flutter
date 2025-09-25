import 'package:flutter/material.dart';

class AnimationService extends ChangeNotifier {
  static final AnimationService _instance = AnimationService._internal();
  factory AnimationService() => _instance;
  AnimationService._internal();

  // Animation controllers for smooth transitions
  late AnimationController logoController;
  late AnimationController formController;
  
  // Logo animations
  late Animation<double> logoScaleAnimation;
  late Animation<double> logoPositionAnimation;
  
  // Form animations
  late Animation<double> formOpacityAnimation;
  late Animation<Offset> formSlideAnimation;

  void initializeAnimations(TickerProvider vsync) {
    // Logo animation controller
    logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: vsync,
    );
    
    // Form animation controller
    formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: vsync,
    );

    // Logo animations - starts from splash screen position
    logoScaleAnimation = Tween<double>(begin: 0.8, end: 0.4).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeInOut),
    );
    
    logoPositionAnimation = Tween<double>(begin: 0.0, end: -0.15).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeInOut),
    );

    // Form animations
    formOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: formController, curve: Curves.easeIn),
    );
    
    formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: formController, curve: Curves.easeOut));
  }

  void startLoginTransition() async {
    // Start logo animation immediately
    logoController.forward();
    
    // Wait for logo animation to complete, then show form
    await Future.delayed(const Duration(milliseconds: 500));
    formController.forward();
  }

  @override
  void dispose() {
    logoController.dispose();
    formController.dispose();
    super.dispose();
  }
} 