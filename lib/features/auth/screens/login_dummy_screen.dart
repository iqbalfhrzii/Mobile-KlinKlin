import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'pin_dummy_screen.dart';

class LoginDummyScreen extends StatefulWidget {
  const LoginDummyScreen({super.key});

  @override
  State<LoginDummyScreen> createState() => _LoginDummyScreenState();
}

class _LoginDummyScreenState extends State<LoginDummyScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@klinklin.com');
  String? _errorMsg;

  void _onLanjut() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Email tidak boleh kosong');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMsg = 'Format email tidak valid');
      return;
    }

    // Tutup keyboard sebelum navigate
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PinDummyScreen(email: email)),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF002B5C), Color(0xFF004F91), Color(0xFF0072CE)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative circles
              Positioned(top: -80, right: -80, child: _circle(224, 0.05)),
              Positioned(top: 128, left: -64, child: _circle(160, 0.04)),
              Positioned(bottom: 160, right: -40, child: _circle(128, 0.04)),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    // Logo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('K', style: GoogleFonts.inter(
                            fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary,
                          )),
                          Text('linKlin', style: GoogleFonts.inter(
                            fontSize: 24, fontWeight: FontWeight.w400, color: AppColors.primary,
                          )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text('Selamat Datang,', style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.white.withOpacity(0.7),
                    )),
                    const SizedBox(height: 4),
                    Text('Masuk ke Akun\nAnda (Demo)', style: GoogleFonts.inter(
                      fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,
                      height: 1.2,
                    )),
                    const SizedBox(height: 40),

                    // Email input
                    Text('Email', style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.5,
                    )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                      onChanged: (_) => setState(() => _errorMsg = null),
                      decoration: InputDecoration(
                        hintText: 'Masukkan email kamu',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.4), fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white, width: 1.5),
                        ),
                        prefixIcon: Icon(Icons.email_outlined,
                          color: Colors.white.withOpacity(0.5), size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 14),
                          const SizedBox(width: 6),
                          Text(_errorMsg!, style: GoogleFonts.inter(
                            fontSize: 12, color: const Color(0xFFFF6B6B),
                          )),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Lanjut button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onLanjut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text('Lanjut', style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary,
                        )),
                      ),
                    ),

                    const Spacer(),
                    Center(
                      child: Text(
                        '© 2026 KlinKlin · Customer Service App (Demo)',
                        style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}
