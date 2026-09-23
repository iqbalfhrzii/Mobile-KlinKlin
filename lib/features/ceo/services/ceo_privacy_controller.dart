import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized state controller for CEO financial privacy (eye toggle).
/// Masks monetary amounts across all CEO views with modern m-banking style (Rp ••••••••).
class CeoPrivacyController extends ChangeNotifier {
  static final CeoPrivacyController instance = CeoPrivacyController._internal();

  CeoPrivacyController._internal() {
    _loadState();
  }

  static const String prefKey = 'ceo_nominal_privacy_masked';
  static const String maskedPlaceholder = 'Rp ••••••••';
  static const String maskedShortPlaceholder = '••••••••';

  bool _isMasked = false;
  bool _isCeo = false;
  bool _isInitialized = false;

  /// Granular privacy overrides per item key (e.g. 'omzet_periode_ini', 'total_omzet_gabungan')
  final Map<String, bool> _itemOverrides = {};

  bool get isMasked => _isMasked;
  bool get isCeo => _isCeo;
  bool get isInitialized => _isInitialized;

  /// Whether any monitored nominal is currently visible (unmasked)
  bool get isAnyVisible {
    if (!_isMasked) {
      return true;
    }
    return _itemOverrides.values.any((masked) => !masked);
  }

  /// Checks if a specific item is masked.
  /// If there is an individual override, uses that; otherwise falls back to global [_isMasked].
  bool isItemMasked(String key) {
    return _itemOverrides[key] ?? _isMasked;
  }

  /// Toggles privacy for a single item (e.g. 'omzet_periode_ini')
  void toggleItem(String key) {
    final current = isItemMasked(key);
    _itemOverrides[key] = !current;
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  /// Loads persisted privacy state and user role from SharedPreferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMasked = prefs.getBool(prefKey) ?? false;
      final role = (prefs.getString('user_role') ?? '').toLowerCase().trim();
      _isCeo = role.contains('ceo') || role.contains('owner') || role.contains('direktur');
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading CEO privacy state: $e');
    }
  }

  /// Refreshes the cached role status if needed (e.g. after login)
  Future<void> checkRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = (prefs.getString('user_role') ?? '').toLowerCase().trim();
      _isCeo = role.contains('ceo') || role.contains('owner') || role.contains('direktur');
      notifyListeners();
    } catch (_) {}
  }

  /// Toggles master privacy mode:
  /// If anything is visible, masking it will cover everything.
  /// If everything is already masked, it unmasks everything.
  /// Clears individual item overrides so all cards synchronize with master.
  Future<void> toggle() async {
    if (isAnyVisible) {
      _isMasked = true;
    } else {
      _isMasked = false;
    }
    _itemOverrides.clear();
    HapticFeedback.lightImpact();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, _isMasked);
    } catch (e) {
      debugPrint('Error saving CEO privacy state: $e');
    }
  }

  /// Sets privacy mode explicitly
  Future<void> setMasked(bool value) async {
    if (_isMasked == value && _itemOverrides.isEmpty) return;
    _isMasked = value;
    _itemOverrides.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, _isMasked);
    } catch (e) {
      debugPrint('Error saving CEO privacy state: $e');
    }
  }

  /// Formats nominal based on masked state.
  /// If [itemKey] is provided, checks specific item privacy state.
  /// If masked, returns 'Rp ••••••••' (or '••••••••' if [includeSymbol] is false).
  /// If unmasked, returns properly formatted Indonesian Rupiah (e.g. 'Rp 547.541.048').
  String formatCurrency(
    dynamic value, {
    String? itemKey,
    String symbol = 'Rp ',
    int decimalDigits = 0,
    bool includeSymbol = true,
  }) {
    final masked = itemKey != null ? isItemMasked(itemKey) : _isMasked;
    if (masked) {
      return includeSymbol ? '$symbol••••••••' : maskedShortPlaceholder;
    }
    return formatRawCurrency(
      value,
      symbol: symbol,
      decimalDigits: decimalDigits,
      includeSymbol: includeSymbol,
    );
  }

  /// Pure currency formatter without masking (used when unmasked or for non-private calculations)
  static String formatRawCurrency(
    dynamic value, {
    String symbol = 'Rp ',
    int decimalDigits = 0,
    bool includeSymbol = true,
  }) {
    if (value == null) return includeSymbol ? '${symbol}0' : '0';
    num numValue = 0;
    if (value is num) {
      numValue = value;
    } else if (value is String) {
      final clean = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      numValue = num.tryParse(clean) ?? 0;
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: includeSymbol ? symbol : '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(numValue).trim();
  }
}
