import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/report_service.dart';
import '../../widgets/loading_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await ReportService().getSummary();
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const LoadingWidget(message: 'Cargando datos...')
          : _error != null
              ? ErrorDisplay(message: 'Error al cargar dashboard', onRetry: _loadData)
              : _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    final data = _data!;
    final totalShifts = data['totalShifts'] ?? 0;
    final balanced = data['balanced'] ?? 0;
    final unbalanced = data['unbalanced'] ?? 0;
    final entityTotals = (data['entityTotals'] as List?) ?? [];
    final discrepancyTrend = (data['discrepancyTrend'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary cards row
          Row(
            children: [
              _statCard('Total Turnos', '$totalShifts', Colors.blue, Icons.access_time),
              const SizedBox(width: 12),
              _statCard('Cuadrados', '$balanced', Colors.green, Icons.check_circle),
              const SizedBox(width: 12),
              _statCard('Descuadres', '$unbalanced', Colors.red, Icons.warning),
            ],
          ),
          const SizedBox(height: 24),

          // Entity bar chart
          if (entityTotals.isNotEmpty) ...[
            Text('Montos por Entidad',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: _buildEntityChart(entityTotals),
            ),
            const SizedBox(height: 24),
          ],

          // Discrepancy trend
          if (discrepancyTrend.isNotEmpty) ...[
            Text('Tendencia de Discrepancias',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: _buildTrendChart(discrepancyTrend),
            ),
            const SizedBox(height: 24),
          ],

          // Balance pie chart
          if (totalShifts > 0) ...[
            Text('Estado de Turnos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: balanced.toDouble(),
                      color: Colors.green,
                      title: 'Cuadrados\n$balanced',
                      titleStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: unbalanced.toDouble(),
                      color: Colors.red,
                      title: 'Descuadres\n$unbalanced',
                      titleStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      radius: 80,
                    ),
                  ],
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],

          if (totalShifts == 0)
            const EmptyState(
              icon: Icons.bar_chart,
              title: 'Sin datos',
              subtitle: 'Cierra turnos para ver estadísticas',
            ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(title,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntityChart(List entityTotals) {
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple,
      Colors.red, Colors.teal, Colors.indigo, Colors.pink,
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: entityTotals.fold<double>(
            0, (max, e) => (e['total'] as num).toDouble() > max ? (e['total'] as num).toDouble() : max) * 1.2,
        barGroups: entityTotals.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (e['total'] as num).toDouble(),
                color: colors[i % colors.length],
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < entityTotals.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      entityTotals[i]['name'].toString().substring(0,
                          entityTotals[i]['name'].toString().length > 5 ? 5 : entityTotals[i]['name'].toString().length),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  'S/ ${value.toInt()}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildTrendChart(List trend) {
    final spots = trend.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['discrepancy'] as num).toDouble(),
      );
    }).toList();

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
          // Zero line
          LineChartBarData(
            spots: spots.map((s) => FlSpot(s.x, 0)).toList(),
            color: Colors.grey[400]!,
            barWidth: 1,
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < trend.length && i % 2 == 0) {
                  final date = trend[i]['date'].toString();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(date.substring(5), style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text('S/ ${value.toInt()}',
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}
