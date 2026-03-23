import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shift_comparison.dart';
import '../../widgets/currency_formatter.dart';

// -- Palette --
const _kSlate = Color(0xFF1E293B);
const _kSlateLight = Color(0xFF334155);
const _kSurface = Color(0xFFF8FAFC);
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kGreenBg = Color(0xFFECFDF5);
const _kRed = Color(0xFFDC2626);
const _kRedBg = Color(0xFFFEF2F2);
const _kBlue = Color(0xFF2563EB);
const _kBlueBg = Color(0xFFEFF6FF);
const _kAmber = Color(0xFFD97706);

class ShiftComparisonDetailScreen extends StatelessWidget {
  final ShiftComparison comparison;

  const ShiftComparisonDetailScreen({super.key, required this.comparison});

  Color _diffColor(double diff) {
    if (diff.abs() < 0.01) return _kGreen;
    return diff > 0 ? _kBlue : _kRed;
  }

  Color _diffBg(double diff) {
    if (diff.abs() < 0.01) return _kGreenBg;
    return diff > 0 ? _kBlueBg : _kRedBg;
  }

  String _diffLabel(double diff) {
    if (diff.abs() < 0.01) return 'Sin diferencia';
    return diff > 0 ? 'Excedente' : 'Faltante';
  }

  String _formatDiff(double diff) {
    if (diff.abs() < 0.01) return 'S/ 0.00';
    final prefix = diff > 0 ? '+' : '';
    return '$prefix${formatCurrency(diff)}';
  }

  @override
  Widget build(BuildContext context) {
    final comp = comparison;
    // totalDiff now only includes entities (no cash)
    final color = _diffColor(comp.totalDiff);
    final bg = _diffBg(comp.totalDiff);

    // Entity-only totals
    final entityClosing =
        comp.entityComparisons.fold<double>(0, (s, e) => s + e.closingAmount);
    final entityOpening =
        comp.entityComparisons.fold<double>(0, (s, e) => s + e.openingAmount);

    return Scaffold(
      backgroundColor: _kSurface,
      body: CustomScrollView(
        slivers: [
          // -- Dark header with total entity diff --
          SliverAppBar(
            expandedHeight: 220,
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
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMPALME DE TURNOS',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _diffLabel(comp.totalDiff),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: comp.totalDiff.abs() < 0.01
                                  ? const Color(0xFF6EE7B7)
                                  : comp.totalDiff > 0
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFFFCA5A5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDiff(comp.totalDiff),
                          style: GoogleFonts.dmMono(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'en saldos de entidades',
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                children: [
                  // -- Operator cards --
                  Row(
                    children: [
                      Expanded(
                        child: _operatorCard(
                          label: 'CIERRE',
                          name: comp.closingShift.operatorName,
                          date: comp.closingShift.closedAt ??
                              comp.closingShift.startedAt,
                          accentColor: _kAmber,
                          icon: Icons.logout_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _operatorCard(
                          label: 'APERTURA',
                          name: comp.openingShift.operatorName,
                          date: comp.openingShift.startedAt,
                          accentColor: _kBlue,
                          icon: Icons.login_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // -- Cash section (informational, excluded from total) --
                  _sectionTitle('EFECTIVO EN CAJA'),
                  const SizedBox(height: 8),
                  _cashTile(comp),

                  const SizedBox(height: 20),

                  // -- Entities section --
                  _sectionTitle('SALDOS POR ENTIDAD'),
                  const SizedBox(height: 8),

                  ...comp.entityComparisons.map((e) => _entityTile(
                        name: e.entityName,
                        closingVal: e.closingAmount,
                        openingVal: e.openingAmount,
                        diff: e.diff,
                      )),

                  const SizedBox(height: 6),

                  // -- Total summary (entities only) --
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saldos cierre',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: _kMuted,
                                )),
                            Text(formatCurrency(entityClosing),
                                style: GoogleFonts.dmMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Saldos apertura',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: _kMuted,
                                )),
                            Text(formatCurrency(entityOpening),
                                style: GoogleFonts.dmMono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            color: color.withOpacity(0.2),
                            height: 1,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('DIFERENCIA',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                )),
                            Text(
                              _formatDiff(comp.totalDiff),
                              style: GoogleFonts.dmMono(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom + 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _kSlate,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kSlateLight,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // -- Cash tile: visually distinct, marked as not included --
  Widget _cashTile(ShiftComparison comp) {
    final cashColor = _diffColor(comp.cashDiff);
    final hasDiff = comp.cashDiff.abs() >= 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 18, color: _kAmber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Efectivo en Caja',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kSlate,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasDiff
                      ? cashColor.withOpacity(0.08)
                      : _kGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDiff(comp.cashDiff),
                  style: GoogleFonts.dmMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cashColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child:
                      _amountPill('Cierre', comp.closingShift.cash, _kAmber)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: Colors.grey[300]),
              const SizedBox(width: 8),
              Expanded(
                  child: _amountPill(
                      'Apertura', comp.openingShift.cash, _kBlue)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No incluido en el total de diferencia',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _kMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operatorCard({
    required String label,
    required String name,
    required DateTime date,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _kSlate,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            formatDate(date),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entityTile({
    required String name,
    required double closingVal,
    required double openingVal,
    required double diff,
  }) {
    final color = _diffColor(diff);
    final hasDiff = diff.abs() >= 0.01;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasDiff
            ? Border.all(color: color.withOpacity(0.2), width: 1)
            : null,
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
              Icon(Icons.account_balance_rounded,
                  size: 18, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kSlate,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasDiff ? color.withOpacity(0.08) : _kGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDiff(diff),
                  style: GoogleFonts.dmMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (hasDiff) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _amountPill('Cierre', closingVal, _kAmber)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.grey[300]),
                const SizedBox(width: 8),
                Expanded(
                    child: _amountPill('Apertura', openingVal, _kBlue)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountPill(String label, double value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatCurrency(value),
            style: GoogleFonts.dmMono(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kSlate,
            ),
          ),
        ],
      ),
    );
  }
}
