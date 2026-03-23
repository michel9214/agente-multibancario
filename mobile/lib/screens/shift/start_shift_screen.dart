import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/entities_provider.dart';
import '../../providers/shift_provider.dart';
import '../../services/shift_service.dart';
import '../../models/shift.dart';
import '../../widgets/currency_formatter.dart';
import '../../widgets/photo_picker.dart';
import '../../models/banking_entity.dart';

const _kSlate = Color(0xFF1E293B);
const _kMuted = Color(0xFF64748B);
const _kGreen = Color(0xFF059669);
const _kRed = Color(0xFFDC2626);
const _kBlue = Color(0xFF2563EB);
const _kAmber = Color(0xFFD97706);
const _kTeal = Color(0xFF0D9488);

class StartShiftScreen extends ConsumerStatefulWidget {
  const StartShiftScreen({super.key});

  @override
  ConsumerState<StartShiftScreen> createState() => _StartShiftScreenState();
}

class _StartShiftScreenState extends ConsumerState<StartShiftScreen> {
  // null = not chosen yet, true = consecutive, false = new
  bool? _isConsecutive;
  Shift? _previousShift;
  bool _loadingPrevious = false;
  bool _noPreviousShift = false;

  int _step = 0;
  final _cashController = TextEditingController();
  final _sencilloController = TextEditingController();
  final Map<String, TextEditingController> _balanceControllers = {};
  final Map<String, String?> _photoUrls = {};
  // Track which entries came from previous shift (skip photo validation)
  final Set<String> _fromPreviousShift = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(activeEntitiesProvider));
  }

  @override
  void dispose() {
    _cashController.dispose();
    _sencilloController.dispose();
    for (final c in _balanceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPreviousShift() async {
    setState(() => _loadingPrevious = true);
    try {
      final shift = await ShiftService().getLastClosedShift();
      if (shift == null) {
        setState(() {
          _noPreviousShift = true;
          _loadingPrevious = false;
        });
        return;
      }
      setState(() {
        _previousShift = shift;
        _loadingPrevious = false;
      });
      _prefillFromPreviousShift(shift);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPrevious = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar turno anterior: $e')),
        );
      }
    }
  }

  void _prefillFromPreviousShift(Shift shift) {
    // Pre-fill ending cash as starting cash
    _cashController.text = (shift.endingCash ?? 0).toStringAsFixed(2);

    // Pre-fill closing balances as opening balances
    final closingEntries =
        shift.balanceEntries.where((b) => b.type == 'CLOSING').toList();
    for (final entry in closingEntries) {
      final entityId = entry.entityId;
      if (entityId != null) {
        _balanceControllers.putIfAbsent(
            entityId, () => TextEditingController());
        _balanceControllers[entityId]!.text =
            entry.amount.toStringAsFixed(2);
        if (entry.receiptPhotoUrl != null) {
          _photoUrls[entityId] = entry.receiptPhotoUrl;
        }
        _fromPreviousShift.add(entityId);
      }
    }
    setState(() {});
  }

  Future<void> _handlePickPhoto(String entityId) async {
    final url = await pickAndUploadPhoto(context);
    if (url != null) {
      setState(() {
        _photoUrls[entityId] = url;
        _fromPreviousShift.remove(entityId);
      });
    }
  }

  List<String> _getMissingPhotos(List<BankingEntity> entities) {
    final missing = <String>[];
    for (final entity in entities) {
      final amount =
          double.tryParse(_balanceControllers[entity.id]?.text ?? '') ?? 0;
      if (amount > 0 && _photoUrls[entity.id] == null) {
        missing.add(entity.name);
      }
    }
    return missing;
  }

  void _tryNextStep(List<BankingEntity> entities) {
    if (_step == 1) {
      final missingPhotos = _getMissingPhotos(entities);
      if (missingPhotos.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falta foto de: ${missingPhotos.join(", ")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    setState(() => _step++);
  }

  Future<void> _openShift(List<BankingEntity> entities) async {
    setState(() => _loading = true);
    try {
      final balances = <Map<String, dynamic>>[];
      for (final entity in entities) {
        final controller = _balanceControllers[entity.id];
        final amount = double.tryParse(controller?.text ?? '') ?? 0;
        if (amount > 0) {
          balances.add({
            'entityId': entity.id,
            'amount': amount,
            if (_photoUrls[entity.id] != null)
              'receiptPhotoUrl': _photoUrls[entity.id],
          });
        }
      }

      await ref.read(activeShiftProvider.notifier).openShift(
            startingCash: double.tryParse(_cashController.text) ?? 0,
            sencillo: double.tryParse(_sencilloController.text) ?? 0,
            openingBalances: balances,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno iniciado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show choice screen first
    if (_isConsecutive == null) {
      return _buildChoiceScreen();
    }

    final entitiesAsync = ref.watch(activeEntitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Iniciar Turno - Paso ${_step + 1}/3'),
      ),
      body: entitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entities) {
          for (final e in entities) {
            _balanceControllers.putIfAbsent(
                e.id, () => TextEditingController());
          }

          return Column(
            children: [
              // Consecutive badge
              if (_isConsecutive == true)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: _kBlue.withOpacity(0.05),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 16, color: _kBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Turno consecutivo - datos cargados del cierre anterior'
                              '${_previousShift?.operator != null ? " (${_previousShift!.operator!.fullName})" : ""}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: _kBlue),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: _step == 0
                    ? _buildCashStep()
                    : _step == 1
                        ? _buildBalancesStep(entities)
                        : _buildReviewStep(entities),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 12),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          child: const Text('Anterior'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_step < 2) {
                                  _tryNextStep(entities);
                                } else {
                                  _openShift(entities);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _step == 2
                              ? _kGreen
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_step == 2
                                ? 'Confirmar e Iniciar'
                                : 'Siguiente'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChoiceScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Turno')),
      body: _loadingPrevious
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_filled,
                      size: 64, color: _kBlue.withOpacity(0.6)),
                  const SizedBox(height: 24),
                  Text(
                    '¿Que tipo de turno deseas iniciar?',
                    style:
                        GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: _kSlate),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Consecutive shift
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _noPreviousShift
                          ? null
                          : () async {
                              await _loadPreviousShift();
                              if (_previousShift != null && mounted) {
                                setState(() => _isConsecutive = true);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        side: BorderSide(
                            color: _noPreviousShift
                                ? const Color(0xFFCBD5E1)
                                : _kBlue,
                            width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.repeat,
                              size: 36,
                              color: _noPreviousShift
                                  ? _kMuted
                                  : _kBlue),
                          const SizedBox(height: 12),
                          Text(
                            'Turno Consecutivo',
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _noPreviousShift
                                  ? _kMuted
                                  : _kBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _noPreviousShift
                                ? 'No hay turno anterior cerrado'
                                : 'Los datos de cierre del turno anterior\nseran los datos de apertura',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: _noPreviousShift
                                  ? _kMuted
                                  : _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New shift
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _isConsecutive = false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        side: const BorderSide(
                            color: _kGreen, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: 36, color: _kGreen),
                          const SizedBox(height: 12),
                          Text(
                            'Turno Nuevo',
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ingresar todos los datos\nde apertura manualmente',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: _kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCashStep() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Efectivo Inicial',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Ingresa el monto de efectivo con el que inicias el turno'),
          const SizedBox(height: 24),
          TextFormField(
            controller: _cashController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en soles',
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
            style:
                GoogleFonts.dmMono(fontSize: 24, fontWeight: FontWeight.w700, color: _kSlate),
          ),
          const SizedBox(height: 32),
          Text('Sencillo',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Monto en sencillo entregado por el dueno. Se devuelve integro al cerrar turno.',
            style: GoogleFonts.dmSans(color: _kMuted),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sencilloController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Sencillo (opcional)',
              prefixText: 'S/ ',
              hintText: '0.00',
            ),
            style:
                GoogleFonts.dmMono(fontSize: 20, fontWeight: FontWeight.w700, color: _kSlate),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancesStep(List<BankingEntity> entities) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
      itemCount: entities.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldos de Apertura',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Ingresa el saldo de cada entidad bancaria'),
              const SizedBox(height: 16),
            ],
          );
        }
        final entity = entities[i - 1];
        final color = _parseColor(entity.color);
        final hasPhoto = _photoUrls[entity.id] != null;
        final isFromPrevious = _fromPreviousShift.contains(entity.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                      child: Icon(Icons.account_balance,
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entity.name,
                          style:
                              GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: _kSlate)),
                    ),
                    if (isFromPrevious)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('anterior',
                            style: TextStyle(
                                fontSize: 10, color: _kBlue)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _balanceControllers[entity.id],
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Saldo',
                          prefixText: 'S/ ',
                          hintText: '0.00',
                          isDense: true,
                        ),
                        onChanged: (_) {
                          // If user modifies amount, remove "from previous" tag
                          if (isFromPrevious) {
                            setState(() =>
                                _fromPreviousShift.remove(entity.id));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: !hasPhoto
                            ? Border.all(color: _kRed, width: 2)
                            : null,
                      ),
                      child: IconButton(
                        onPressed: () => _handlePickPhoto(entity.id),
                        icon: Icon(
                          hasPhoto
                              ? Icons.check_circle
                              : Icons.camera_alt,
                          color: hasPhoto ? _kGreen : _kRed,
                        ),
                        tooltip: 'Foto obligatoria',
                      ),
                    ),
                    if (hasPhoto)
                      IconButton(
                        onPressed: () => showPhotoPreview(
                            context, _photoUrls[entity.id]!),
                        icon: const Icon(Icons.visibility,
                            color: _kBlue, size: 20),
                        tooltip: 'Ver foto',
                      ),
                  ],
                ),
                if (!hasPhoto)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Foto del comprobante obligatoria',
                      style:
                          GoogleFonts.dmSans(color: _kRed, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewStep(List<BankingEntity> entities) {
    final cash = double.tryParse(_cashController.text) ?? 0;
    final sencillo = double.tryParse(_sencilloController.text) ?? 0;
    double totalBalances = 0;
    final balanceItems = <MapEntry<String, double>>[];

    for (final entity in entities) {
      final amount =
          double.tryParse(_balanceControllers[entity.id]?.text ?? '') ?? 0;
      if (amount > 0) {
        balanceItems.add(MapEntry(entity.name, amount));
        totalBalances += amount;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de Apertura',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _reviewRow('Efectivo inicial', formatCurrency(cash)),
                  if (sencillo > 0)
                    _reviewRow('Sencillo', formatCurrency(sencillo),
                        color: _kAmber),
                  const Divider(),
                  ...balanceItems.map(
                      (e) => _reviewRow(e.key, formatCurrency(e.value))),
                  if (balanceItems.isNotEmpty) const Divider(),
                  _reviewRow(
                      'Total saldos', formatCurrency(totalBalances),
                      bold: true),
                  const Divider(),
                  _reviewRow(
                    'TOTAL GENERAL',
                    formatCurrency(cash + totalBalances),
                    bold: true,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  color: color ?? _kSlate)),
          Text(value,
              style: GoogleFonts.dmMono(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? _kSlate)),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return _kBlue;
    }
  }
}
