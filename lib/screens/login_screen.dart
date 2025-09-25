import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/animation_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  final AuthService _authService = Get.put(AuthService());
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _animationService.initializeAnimations(this);
    _animationService.startLoginTransition();


  }



  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;


      final result = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (result != null) {
        // Login successful, navigate to home screen (which will route based on accountType)
        Get.off(() => const HomeScreen());
      }
      // If login fails, error message is already shown by AuthService
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    RxBool isLoading = false.obs;
    RxString errorMessage = ''.obs;

    Get.dialog(
      Obx(() => AlertDialog(
        title: Text(
          'إعادة تعيين كلمة المرور',
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'أدخل بريدك الإلكتروني لإرسال رابط إعادة تعيين كلمة المرور',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال البريد الإلكتروني';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
                  ).hasMatch(value)) {
                    return 'البريد الإلكتروني غير صحيح';
                  }
                  return null;
                },
              ),
              if (errorMessage.value.isNotEmpty) ...[
                SizedBox(height: screenHeight * 0.01),
                Text(
                  errorMessage.value,
                  style: TextStyle(color: Colors.red, fontSize: screenWidth * 0.035),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading.value ? null : () => Get.back(),
            child: Text(
              'إلغاء',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: isLoading.value
                ? null
                : () async {
              if (formKey.currentState!.validate()) {
                      isLoading.value = true;
                      errorMessage.value = '';
                      try {
                        await _authService.resetPassword(emailController.text.trim());
                        isLoading.value = false;
                Get.back();
                        Get.dialog(
                          AlertDialog(
                            title: const Text('تم الإرسال'),
                            content: const Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني. تحقق من البريد الوارد أو الرسائل غير المرغوب فيها.'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('حسناً'),
                              ),
                            ],
                          ),
                        );
                      } on FirebaseAuthException catch (e) {
                        isLoading.value = false;
                        if (e.code == 'user-not-found') {
                          errorMessage.value = 'البريد الإلكتروني غير مسجل';
                        } else if (e.code == 'invalid-email') {
                          errorMessage.value = 'البريد الإلكتروني غير صحيح';
                        } else {
                          errorMessage.value = 'حدث خطأ في إرسال الرابط';
                        }
                      } catch (e) {
                        isLoading.value = false;
                        errorMessage.value = 'حدث خطأ غير متوقع';
                      }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(225, 34, 34, 1),
              foregroundColor: Colors.white,
            ),
            child: isLoading.value
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
              'إرسال',
              style: TextStyle(fontSize: screenWidth * 0.04),
            ),
          ),
        ],
      )),
      barrierDismissible: !isLoading.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final FocusNode emailFocus = FocusNode();
    final FocusNode passwordFocus = FocusNode();
    RxBool rememberMe = false.obs;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(225, 34, 34, 0.12),
              Color.fromARGB(255, 255, 255, 255),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: AnimatedBuilder(
                  animation: _animationService.logoController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        screenHeight *
                            _animationService.logoPositionAnimation.value /
                            10,
                      ),
                      child: Transform.scale(
                        scale: _animationService.logoScaleAnimation.value,
                        child: Center(
                          child: Image.asset(
                            'assets/splash_logo.png',
                            fit: BoxFit.fitWidth,
                            width: screenWidth,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                flex: 4,
                child: AnimatedBuilder(
                  animation: _animationService.formController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _animationService.formOpacityAnimation,
                      child: SlideTransition(
                        position: _animationService.formSlideAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.08,
                            vertical: screenHeight * 0.02,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    'مرحباً بك في',
                                    style: TextStyle(
                                      fontSize: screenWidth * 0.05,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Text(
                                  'إنتخابات',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.08,
                                    fontWeight: FontWeight.bold,
                                    color: const Color.fromRGBO(225, 34, 34, 1),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  'أدخل بريدك الإلكتروني وكلمة المرور',
                                  style: GoogleFonts.cairo(
                                    fontSize: screenWidth * 0.04,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.04),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      // Email Field
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: GoogleFonts.cairo(
                                            fontSize: screenWidth * 0.04,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'البريد الإلكتروني',
                                            hintStyle: GoogleFonts.cairo(
                                              color: Colors.grey[400],
                                              fontSize: screenWidth * 0.04,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.email,
                                              color: Colors.grey[400],
                                              size: screenWidth * 0.05,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal:
                                                      screenWidth * 0.04,
                                                  vertical:
                                                      screenHeight * 0.015,
                                                ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'يرجى إدخال البريد الإلكتروني';
                                            }
                                            if (!RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                            ).hasMatch(value)) {
                                              return 'البريد الإلكتروني غير صحيح';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.03),

                                      // Password Field
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: TextFormField(
                                          controller: _passwordController,
                                          obscureText: !_isPasswordVisible,
                                          style: GoogleFonts.cairo(
                                            fontSize: screenWidth * 0.04,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'كلمة المرور',
                                            hintStyle: GoogleFonts.cairo(
                                              color: Colors.grey[400],
                                              fontSize: screenWidth * 0.04,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.lock,
                                              color: Colors.grey[400],
                                              size: screenWidth * 0.05,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _isPasswordVisible
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                color: Colors.grey[400],
                                                size: screenWidth * 0.05,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal:
                                                      screenWidth * 0.04,
                                                  vertical:
                                                      screenHeight * 0.015,
                                                ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'يرجى إدخال كلمة المرور';
                                            }
                                            if (value.length < 6) {
                                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),

                                      // Forgot Password Link
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: () =>
                                              _showForgotPasswordDialog(),
                                          child: Text(
                                            'نسيت كلمة المرور؟',
                                            style: GoogleFonts.cairo(
                                              fontSize: screenWidth * 0.035,
                                              color: const Color.fromRGBO(
                                                225,
                                                34,
                                                34,
                                                1,
                                              ),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.04),
                                      Obx(
                                        () => SizedBox(
                                          width: double.infinity,
                                          height: screenHeight * 0.06,
                                          child: ElevatedButton(
                                            onPressed: _authService.isLoading
                                                ? null
                                                : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromRGBO(
                                                    225,
                                                    34,
                                                    34,
                                                    1,
                                                  ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              elevation: 3,
                                            ),
                                            child: _authService.isLoading
                                                ? SizedBox(
                                                    width: screenWidth * 0.05,
                                                    height: screenWidth * 0.05,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(Colors.white),
                                                    ),
                                                  )
                                                : Text(
                                                    'تسجيل الدخول',
                                                    style: GoogleFonts.cairo(
                                                      fontSize:
                                                          screenWidth * 0.045,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.03),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
                                              style: GoogleFonts.cairo(
                                                fontSize: screenWidth * 0.035,
                                                color: Colors.grey[500],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
