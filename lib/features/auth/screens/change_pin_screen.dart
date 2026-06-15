import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../shell/main_shell.dart';

class ChangePINScreen extends StatefulWidget {
  const ChangePINScreen({
    super.key,
    this.isMandatory = false,
    this.currentPin,
  });

  final bool isMandatory;
  final String? currentPin;

  @override
  State<ChangePINScreen> createState() => _ChangePINScreenState();
}

class _ChangePINScreenState extends State<ChangePINScreen> {
  late int _step; // 0=verify, 1=new, 2=confirm
  String _pin = '';
  String _oldPin = '';
  String _newPin = '';
  String _error = '';
  bool _isLoading = false;

  static const _titles = ['Masukkan PIN Lama', 'PIN Baru', 'Konfirmasi PIN Baru'];
  static const _subs = [
    'Verifikasi identitas dengan PIN lama',
    'Masukkan PIN baru yang kuat',
    'Ulangi PIN baru kamu',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isMandatory && widget.currentPin != null) {
      _oldPin = widget.currentPin!;
      _step = 1; // Skip old pin verification if mandatory and pin is known
    } else {
      _step = 0;
    }
  }

  void _onKey(String digit) {
    if (_pin.length >= 6 || _isLoading) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == 6) _verify();
  }

  void _onDel() {
    if (_pin.isEmpty || _isLoading) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_step == 0) {
      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('user_email') ?? '';
        
        // Verifikasi PIN lama dengan mencoba login diam-diam
        await AuthService.login(email, _pin);
        
        if (!mounted) return;
        setState(() {
          _oldPin = _pin;
          _step = 1;
          _pin = '';
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'PIN lama salah';
          _pin = '';
          _isLoading = false;
        });
      }
    } else if (_step == 1) {
      setState(() {
        _newPin = _pin;
        _step = 2;
        _pin = '';
      });
    } else {
      if (_pin != _newPin) {
        setState(() {
          _error = 'PIN tidak cocok';
          _pin = '';
        });
        return;
      }
      
      // Hit API
      setState(() => _isLoading = true);
      try {
        await AuthService.changePin(_oldPin, _newPin);
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PIN berhasil diubah!', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.statusDone,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));

        if (widget.isMandatory) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        } else {
          Navigator.pop(context);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _pin = '';
          _isLoading = false;
          // If error happens during confirm, reset to step 1 if mandatory, or step 0 if not
          _step = widget.isMandatory ? 1 : 0;
        });
      }
    }
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
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: widget.isMandatory 
                  ? const SizedBox(height: 24) // Empty space if mandatory (no back button)
                  : GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 14),
                        Text('Kembali', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(_titles[_step], style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
              )),
              const SizedBox(height: 6),
              Text(_subs[_step], style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withOpacity(0.6),
              )),
              const SizedBox(height: 32),
              
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.white)
              else
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
                        color: filled ? Colors.white : Colors.white.withOpacity(0.25),
                      ),
                    );
                  }),
                ),
                
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _error.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Text(_error, style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFFFF6B6B),
                )),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.count(
                  crossAxisCount: 3, shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                  children: [
                    ...'123456789'.split('').map((d) => _Key(d, () => _onKey(d))),
                    const SizedBox(),
                    _Key('0', () => _onKey('0')),
                    _Key(null, _onDel, icon: Icons.backspace_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.label, this.onTap, {this.icon});
  final String? label;
  final VoidCallback onTap;
  final IconData? icon;

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
            ? Text(label!, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white))
            : Icon(icon, color: Colors.white.withOpacity(0.8), size: 22),
      ),
    );
  }
}
