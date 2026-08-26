import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shell/main_shell.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/fcm_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../cleaner/shell/cleaner_main_shell.dart';
import '../../finance/shell/finance_main_shell.dart';
import '../../hrd/shell/hrd_main_shell.dart';
import '../../operasional/shell/operasional_main_shell.dart';
import '../../designer/shell/designer_main_shell.dart';
import '../../marketing/shell/marketing_main_shell.dart';
import '../../ceo/shell/ceo_main_shell.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.email});
  final String email;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _error = '';
  bool _isLoading = false;

  void _onKeyPress(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _error = '';
      });
      if (_pin.length == 6) {
        _submitPin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = '';
      });
    }
  }

  Future<void> _submitPin() async {
    setState(() => _isLoading = true);
    try {
      final res = await AuthService.login(widget.email, _pin);
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final rawRole = prefs.getString('user_role') ?? '';
        final roleName = rawRole.toLowerCase().trim();
        
        debugPrint('DEBUG LOGIN ROLENAME: $roleName');
        
        final isCleaner = roleName.contains('cleaner');
        final isFinance = roleName.contains('finance') || roleName.contains('keuangan');
        final isHrd = roleName == 'hrd' || roleName.contains('hrd');
        final isOperasional = roleName.contains('operasional');
        final isDesigner = roleName.contains('designer') || roleName.contains('desain');
        final isMarketing = roleName.contains('marketing');
        final isCeo = roleName.contains('ceo') || roleName.contains('owner');

        debugPrint('DEBUG LOGIN isMarketing: $isMarketing, isCeo: $isCeo');

        // Send FCM token to backend for all roles
        FcmService.instance.updateTokenToServer();

        if (res['wajib_ganti_pin'] == true) {
          if (isCleaner) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => CleanerMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else if (isFinance) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => FinanceMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else if (isHrd) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => HrdMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else if (isOperasional) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => OperasionalMainShell()),
              (route) => false,
            );
          } else if (isDesigner) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => DesignerMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else if (isMarketing) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MarketingMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else if (isCeo) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => CeoMainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainShell(
                requirePinChange: true,
                currentPin: _pin,
              )),
              (route) => false,
            );
          }
        } else {
          if (isCleaner) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CleanerMainShell()),
              (route) => false,
            );
          } else if (isFinance) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const FinanceMainShell()),
              (route) => false,
            );
          } else if (isHrd) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HrdMainShell()),
              (route) => false,
            );
          } else if (isOperasional) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const OperasionalMainShell()),
              (route) => false,
            );
          } else if (isDesigner) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const DesignerMainShell()),
              (route) => false,
            );
          } else if (isMarketing) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MarketingMainShell()),
              (route) => false,
            );
          } else if (isCeo) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CeoMainShell()),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _pin = '';
          _isLoading = false;
        });
      }
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
              Text('Masukkan PIN', style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
              )),
              const SizedBox(height: 6),
              Text('6 digit PIN untuk masuk', style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.6),
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
                          : Colors.white.withValues(alpha: 0.25),
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
                  childAspectRatio: 1.6,
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

              const SizedBox(height: 32),
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
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: label != null
            ? Text(label!, style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white,
              ))
            : Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 22),
      ),
    );
  }
}
