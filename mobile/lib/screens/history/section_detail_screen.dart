import 'package:flutter/material.dart';
import '../../models/balance_entry.dart';
import '../../models/movement.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';

/// Detail screen for Opening/Closing sections
class SectionDetailScreen extends StatelessWidget {
  final String title;
  final Color color;
  final String cashLabel;
  final double cashAmount;
  final List<BalanceEntry> entries;
  final double totalBalance;
  final double totalGeneral;

  const SectionDetailScreen({
    super.key,
    required this.title,
    required this.color,
    required this.cashLabel,
    required this.cashAmount,
    required this.entries,
    required this.totalBalance,
    required this.totalGeneral,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cash
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(cashLabel,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(formatCurrency(cashAmount),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Entities
          if (entries.isNotEmpty) ...[
            Text('Entidades',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...entries.map((b) => _EntityCard(entry: b, color: color)),
            const SizedBox(height: 12),
          ],

          // Totals
          Card(
            color: color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _totalRow('Total saldos entidades',
                      formatCurrency(totalBalance)),
                  const Divider(),
                  _totalRow('TOTAL ${title.toUpperCase()}',
                      formatCurrency(totalGeneral),
                      bold: true, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: bold ? 15 : 14,
              )),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color,
                fontSize: bold ? 16 : 14,
              )),
        ],
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  final BalanceEntry entry;
  final Color color;

  const _EntityCard({required this.entry, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.2),
                  radius: 16,
                  child: Icon(Icons.account_balance, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(entry.entity?.name ?? 'Entidad',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(formatCurrency(entry.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            if (entry.receiptPhotoUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () =>
                    showPhotoPreview(context, entry.receiptPhotoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    entry.receiptPhotoUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Toca para ampliar',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail screen for Movements section
class MovementsSectionScreen extends StatelessWidget {
  final List<Movement> movements;
  final double netMovements;

  const MovementsSectionScreen({
    super.key,
    required this.movements,
    required this.netMovements,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Movimientos (${movements.length})')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...movements.map((m) => _MovementCard(movement: m)),
          const SizedBox(height: 12),
          Card(
            color: Colors.purple[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Movimientos netos',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[800])),
                  Text(formatCurrency(netMovements),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple[800])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  final Movement movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final isIn = m.isIncoming;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      isIn ? Colors.green[100] : Colors.red[100],
                  radius: 16,
                  child: Icon(
                    isIn ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIn ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.typeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (m.description != null)
                        Text(m.description!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(
                  '${isIn ? '+' : '-'} ${formatCurrency(m.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isIn ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (m.receiptPhotoUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showPhotoPreview(context, m.receiptPhotoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    m.receiptPhotoUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 150,
                        color: Colors.grey[200],
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      height: 80,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Toca para ampliar',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
