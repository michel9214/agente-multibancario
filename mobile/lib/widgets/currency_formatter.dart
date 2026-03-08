import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Allows digits with optional decimal point and up to 2 decimal places.
/// Max integer part: [maxIntDigits] digits (default 3 → max 999.99).
class DecimalInputFormatter extends TextInputFormatter {
  final int maxIntDigits;
  final int maxDecimalDigits;

  DecimalInputFormatter({this.maxIntDigits = 3, this.maxDecimalDigits = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final regex = RegExp('^\\d{0,$maxIntDigits}\\.?\\d{0,$maxDecimalDigits}\$');
    if (regex.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

String formatCurrency(double amount) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return 'S/ ${formatter.format(amount)}';
}

String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy HH:mm', 'es_PE').format(date.toLocal());
}

String formatDateShort(DateTime date) {
  return DateFormat('dd/MM/yyyy', 'es_PE').format(date.toLocal());
}

String formatTime(DateTime date) {
  return DateFormat('HH:mm', 'es_PE').format(date.toLocal());
}
