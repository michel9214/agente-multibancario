import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/balance_entry.dart';
import '../../models/movement.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';

const _kSlate = Color(0xFF1E293B);
const _kSlateLight = Color(0xFF334155);
const _kMuted = Color(0xFF64748B);
const _kSurface = Color(0xFFF8FAFC);
const _kGreen = Color(0xFF059669);
const _kRed = Color(0xFFDC2626);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);
const _kPurple = Color(0xFF7C3AED);

/// ─────────────────────────────────────────────
/// Opening / Closing section detail
/// ─────────────────────────────────────────────
class SectionDetailScreen extends StatelessWidget {
  final String title;
  final Color color;
  final String cashLabel;
  final double cashAmount;
  final double sencillo;
  final List<BalanceEntry> entries;
  final double totalBalance;
  final double totalGeneral;

  const SectionDetailScreen({
    super.key,
    required this.title,
    required this.color,
    required this.cashLabel,
    required this.cashAmount,
    this.sencillo = 0,
    required this.entries,
    required this.totalBalance,
    required this.totalGeneral,
  });

  @override
  Widget build(BuildContext context) {
    final accent = title == 'Apertura' ? _kBlue : _kAmber;

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Sticky header with total ──
          SliverAppBar(
            expandedHeight: sencillo > 0 ? 260 : 230,
            pinned: true,
            backgroundColor: _kSlate,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), _kSlate],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        // Cash line
                        _headerLine(cashLabel, formatCurrency(cashAmount)),
                        const SizedBox(height: 4),
                        // Saldos line
                        _headerLine('Saldos', formatCurrency(totalBalance)),
                        // Sencillo (subtle, where saldos pill used to be)
                        if (sencillo > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Sencillo: ',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: Colors.white38)),
                                Text(formatCurrency(sencillo),
                                    style: GoogleFonts.dmMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    )),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          formatCurrency(totalGeneral),
                          style: GoogleFonts.dmMono(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Total ${title.toLowerCase()}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Entity balance subtitle bar ──
          if (entries.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: accent.withOpacity(0.06),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${entries.length} entidad${entries.length > 1 ? 'es' : ''}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    Text(
                      'Saldos: ${formatCurrency(totalBalance)}',
                      style: GoogleFonts.dmMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Entity cards ──
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _EntityTile(entry: entries[index], accent: accent),
                childCount: entries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white54,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmMono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _EntityTile extends StatelessWidget {
  final BalanceEntry entry;
  final Color accent;

  const _EntityTile({required this.entry, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.account_balance_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.entity?.name ?? 'Entidad',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kSlate,
                  ),
                ),
              ),
              Text(
                formatCurrency(entry.amount),
                style: GoogleFonts.dmMono(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _kSlate,
                ),
              ),
            ],
          ),
          if (entry.receiptPhotoUrl != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => showPhotoPreview(context, entry.receiptPhotoUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.receiptPhotoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kMuted.withOpacity(0.3)),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                        child:
                            Icon(Icons.broken_image_rounded, color: _kMuted)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Toca para ampliar',
                  style: GoogleFonts.dmSans(
                      fontSize: 10, color: _kMuted)),
            ),
          ],
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
/// Movements section detail
/// ─────────────────────────────────────────────
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
    final totalIn = movements
        .where((m) => m.isIncoming)
        .fold<double>(0.0, (s, m) => s + m.amount);
    final totalOut = movements
        .where((m) => !m.isIncoming)
        .fold<double>(0.0, (s, m) => s + m.amount);

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Sticky header with net amount ──
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: _kSlate,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F172A), _kSlate],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOVIMIENTOS',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        // Entradas line
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Entradas',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white54,
                                )),
                            Text('+${formatCurrency(totalIn)}',
                                style: GoogleFonts.dmMono(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6EE7B7),
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Salidas line
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Salidas',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white54,
                                )),
                            Text('-${formatCurrency(totalOut)}',
                                style: GoogleFonts.dmMono(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFCA5A5),
                                )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          formatCurrency(netMovements),
                          style: GoogleFonts.dmMono(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'Neto de ${movements.length} movimiento${movements.length != 1 ? 's' : ''}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Movement cards ──
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 32),
            sliver: movements.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text('Sin movimientos',
                            style: GoogleFonts.dmSans(color: _kMuted)),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _MovementTile(movement: movements[index]),
                      childCount: movements.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

}

class _MovementTile extends StatelessWidget {
  final Movement movement;

  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final isIn = m.isIncoming;
    final color = isIn ? _kGreen : _kRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color.withOpacity(0.5), width: 3),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.typeLabel,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kSlate,
                        )),
                    if (m.description != null)
                      Text(m.description!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _kMuted,
                          )),
                  ],
                ),
              ),
              Text(
                '${isIn ? '+' : '-'} ${formatCurrency(m.amount)}',
                style: GoogleFonts.dmMono(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
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
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kMuted.withOpacity(0.3)),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                        child:
                            Icon(Icons.broken_image_rounded, color: _kMuted)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Toca para ampliar',
                  style:
                      GoogleFonts.dmSans(fontSize: 10, color: _kMuted)),
            ),
          ],
        ],
      ),
    );
  }
}
