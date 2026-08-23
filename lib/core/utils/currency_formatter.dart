import 'package:flutter/services.dart';

class CurrencyFormatter {
  static String format(num value) {
    return 'Rp ${value.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  static String format(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    int selectionIndex = newValue.selection.end;
    String cleanString = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanString.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final int value = int.parse(cleanString);
    final String formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    int diff = formatted.length - newValue.text.length;
    selectionIndex += diff;
    if (selectionIndex > formatted.length) {
      selectionIndex = formatted.length;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
