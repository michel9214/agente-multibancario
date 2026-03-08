import 'package:intl/intl.dart';

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
