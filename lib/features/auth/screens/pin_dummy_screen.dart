import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../shell/main_shell.dart';

class PinDummyScreen extends StatefulWidget {
  const PinDummyScreen({super.key, required this.email});
  final String email;

  @override
  State<PinDummyScreen> createState() => _PinDummyScreenState();
}

class _PinDummyScreenState extends State<PinDummyScreen> {
  String _pin = '';
  String _error = '';
  bool _isLoading = false;

  void _onKeyPress(String digit) {
    if (_pin.length >= 6 || _isLoading) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == 6) _verify();
  }

  void _onDelete() {
    if (_pin.isEmpty || _isLoading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Save dummy data to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'dummy_token_12345');
    await prefs.setString('user_name', 'Admin Dummy');
    await prefs.setString('user_email', widget.email);
    await prefs.setString('user_role', 'Administrator');
    await prefs.setString('user_branch', 'Pusat Dummy');
    await prefs.setString('user_id', 'KLK-CS-000');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          bottom: false,
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 14),
                          Text('Kembali', style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.white70,
                          )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Title
              Text('Masukkan PIN Demo', style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
              )),
              const SizedBox(height: 6),
              Text('Masukkan 6 digit angka bebas', style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withOpacity(0.6),
              )),

              const SizedBox(height: 24),

              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: filled ? 14 : 12,
                    height: filled ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Colors.white
                          : Colors.white.withOpacity(0.25),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Error message
              AnimatedOpacity(
                opacity: _error.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _error,
                  style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(),

              // Numpad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    ...'123456789'.split('').map((d) => _NumKey(label: d, onTap: () => _onKeyPress(d))),
                    const SizedBox(), // empty cell
                    _NumKey(label: '0', onTap: () => _onKeyPress('0')),
                    _NumKey(
                      icon: Icons.backspace_outlined,
                      onTap: _onDelete,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        alignment: Alignment.center,
        child: label != null
            ? Text(label!, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white,
              ))
            : Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
      ),
    );
  }
}
