import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift.dart';
import '../../models/banking_entity.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';

const _kSlate = Color(0xFF1E293B);
const _kMuted = Color(0xFF64748B);
const _kPurple = Color(0xFF7C3AED);

class PendingDeliveriesScreen extends ConsumerStatefulWidget {
  const PendingDeliveriesScreen({super.key});

  @override
  ConsumerState<PendingDeliveriesScreen> createState() =>
      _PendingDeliveriesScreenState();
}

class _PendingDeliveriesScreenState
    extends ConsumerState<PendingDeliveriesScreen> {
  final List<_DeliveryEntry> _entries = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing pending deliveries
    final shift = ref.read(activeShiftProvider).valueOrNull;
    if (shift != null) {
      for (final pd in shift.pendingDeliveries) {
        _entries.add(_DeliveryEntry(
          entityId: pd.entityId,
          amountController: TextEditingController(
            text: pd.amount % 1 == 0
                ? pd.amount.toStringAsFixed(0)
                : pd.amount.toStringAsFixed(2),
          ),
          descriptionController:
              TextEditingController(text: pd.description ?? ''),
          photoUrl: pd.receiptPhotoUrl,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.amountController.dispose();
      e.descriptionController.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _entries.add(_DeliveryEntry(
        entityId: null,
        amountController: TextEditingController(),
        descriptionController: TextEditingController(),
      ));
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries[index].amountController.dispose();
      _entries[index].descriptionController.dispose();
      _entries.removeAt(index);
    });
  }

  Future<void> _save() async {
    final shift = ref.read(activeShiftProvider).valueOrNull;
    if (shift == null) return;

    final deliveries = <Map<String, dynamic>>[];
    for (final e in _entries) {
      final amount = double.tryParse(e.amountController.text) ?? 0;
      if (amount > 0 && e.entityId != null) {
        deliveries.add({
          'entityId': e.entityId,
          'amount': amount,
          'description': e.descriptionController.text.trim().isNotEmpty
              ? e.descriptionController.text.trim()
              : null,
          'receiptPhotoUrl': e.photoUrl,
        });
      }
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(activeShiftProvider.notifier)
          .updatePendingDeliveries(shift.id, deliveries);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entregas pendientes actualizadas'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = ref.watch(activeShiftProvider).valueOrNull;
    if (shift == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Entregas Pendientes')),
        body: const Center(child: Text('No hay turno activo')),
      );
    }

    // Get opening entities for the dropdown
    final openingEntities = shift.balanceEntries
        .where((b) => b.type == 'OPENING' && b.entity != null)
        .map((b) => b.entity!)
        .toList();

    final total = _entries.fold<double>(
        0.0, (sum, e) => sum + (double.tryParse(e.amountController.text) ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Entregas Pendientes')),
      body: Column(
        children: [
          // Total bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: _kPurple.withOpacity(0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total entregas',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      color: _kPurple,
                      fontSize: 14,
                    )),
                Text(formatCurrency(total),
                    style: GoogleFonts.dmMono(
                      fontWeight: FontWeight.w700,
                      color: _kPurple,
                      fontSize: 16,
                    )),
              ],
            ),
          ),
          // List
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Sin entregas pendientes',
                            style: GoogleFonts.dmSans(color: _kMuted)),
                        const SizedBox(height: 4),
                        Text(
                          'Agrega entregas que aún no fueron recogidas',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: _kMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 12, 16,
                        MediaQuery.of(context).padding.bottom + 32),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return _buildEntryCard(
                          index, _entries[index], openingEntities);
                    },
                  ),
          ),
          // Bottom buttons
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Agregar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(int index, _DeliveryEntry entry,
      List<BankingEntity> openingEntities) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _kPurple.withOpacity(0.4), width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete
          Row(
            children: [
              Text('Entrega ${index + 1}',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _kPurple,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeEntry(index),
                child: Icon(Icons.close_rounded, size: 20, color: _kMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Entity dropdown
          DropdownButtonFormField<String>(
            value: entry.entityId,
            decoration: const InputDecoration(
              labelText: 'Entidad',
              prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: openingEntities
                .map((e) => DropdownMenuItem<String>(
                      value: e.id,
                      child: Text(e.name,
                          style: GoogleFonts.dmSans(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => entry.entityId = v),
          ),
          const SizedBox(height: 10),
          // Amount
          TextFormField(
            controller: entry.amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixIcon: Icon(Icons.attach_money_rounded, size: 20),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          // Description
          TextFormField(
            controller: entry.descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción (nombre del enviante)',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Photo
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final url = await pickAndUploadPhoto(context);
                  if (url != null) {
                    setState(() => entry.photoUrl = url);
                  }
                },
                icon: Icon(
                  entry.photoUrl != null
                      ? Icons.check_circle_rounded
                      : Icons.camera_alt_rounded,
                  size: 16,
                  color: entry.photoUrl != null
                      ? const Color(0xFF059669)
                      : null,
                ),
                label: Text(entry.photoUrl != null
                    ? 'Evidencia cargada'
                    : 'Agregar evidencia'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: entry.photoUrl != null
                      ? const Color(0xFF059669)
                      : _kMuted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              if (entry.photoUrl != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showPhotoPreview(context, entry.photoUrl!),
                  child: const Icon(Icons.visibility_rounded,
                      color: Color(0xFF2563EB), size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DeliveryEntry {
  String? entityId;
  final TextEditingController amountController;
  final TextEditingController descriptionController;
  String? photoUrl;

  _DeliveryEntry({
    required this.entityId,
    required this.amountController,
    required this.descriptionController,
    this.photoUrl,
  });
}
