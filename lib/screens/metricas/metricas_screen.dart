import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/metrics_provider.dart';
import 'package:provider/provider.dart';

class MetricasScreen extends StatefulWidget {
  const MetricasScreen({super.key});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  late Servidor _servidor;
  late MetricsProvider _metricsProvider;
  bool _initialized = false;

  final List<int> _ranges = [30, 60, 360, 1440];
  final List<String> _rangeLabels = ['30 min', '1 h', '6 h', '24 h'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _servidor = ModalRoute.of(context)!.settings.arguments as Servidor;
      _metricsProvider = context.read<MetricsProvider>();
      _initialized = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _metricsProvider.startPolling(
          _servidor.serverId,
          rangeMinutes: 60,
        );
      });
    }
  }

  @override
  void dispose() {
    _metricsProvider.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_servidor.hostname, style: const TextStyle(fontSize: 16)),
            const Text(
              'Métricas en tiempo real',
              style: TextStyle(fontSize: 11, color: Color(0xFF8B949E)),
            ),
          ],
        ),
      ),
      body: Consumer<MetricsProvider>(
        builder: (_, provider, _) {
          return Column(
            children: [
              _RangeSelector(
                ranges: _ranges,
                labels: _rangeLabels,
                selected: provider.rangeMinutes,
                onChanged: provider.changeRange,
              ),
              Expanded(
                child: provider.points.isEmpty && provider.loading
                    ? const AppLoadingWidget(message: 'Cargando métricas…')
                    : provider.error != null && provider.points.isEmpty
                        ? AppErrorWidget(
                            message: 'Error al cargar métricas:\n${provider.error}',
                            onRetry: () => provider.startPolling(
                              _servidor.serverId,
                              rangeMinutes: provider.rangeMinutes,
                            ),
                          )
                        : provider.points.isEmpty
                            ? const EmptyStateWidget(
                                message: 'Sin métricas disponibles',
                                icon: Icons.area_chart_outlined,
                              )
                            : _MetricasContent(points: provider.points),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Selector de rango ──────────────────────────────────────────────────────────
class _RangeSelector extends StatelessWidget {
  final List<int> ranges;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  const _RangeSelector({
    required this.ranges,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Rango:',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
          ),
          const SizedBox(width: 10),
          ...List.generate(ranges.length, (i) {
            final isSelected = ranges[i] == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(ranges[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1F6FEB)
                        : const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1F6FEB)
                          : const Color(0xFF30363D),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8B949E),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          const _RefreshIndicatorDot(),
        ],
      ),
    );
  }
}

class _RefreshIndicatorDot extends StatefulWidget {
  const _RefreshIndicatorDot();
  @override
  State<_RefreshIndicatorDot> createState() => _RefreshIndicatorDotState();
}

class _RefreshIndicatorDotState extends State<_RefreshIndicatorDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: Color.fromRGBO(63, 185, 80, _anim.value),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(color: Color(0xFF3FB950), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Contenido principal de métricas ────────────────────────────────────────────
class _MetricasContent extends StatelessWidget {
  final List<MetricPoint> points;
  const _MetricasContent({required this.points});

  @override
  Widget build(BuildContext context) {
    final hasApache = points.any((p) => p.services?.apache2?.enabled == true);
    final hasMariaDb = points.any((p) => p.services?.mariadb?.enabled == true);
    final hasSsh = points.any((p) => p.services?.ssh?.enabled == true);
    final hasSwap = points.any((p) => p.metrics?.swap?.present == true);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Sistema ──────────────────────────────────────────────────────────
        const _ChartSectionHeader(title: 'CPU', icon: Icons.memory),
        _LineChartCard(
          label: 'Uso de CPU (%)',
          color: const Color(0xFF388BFD),
          points: points.map((p) => p.metrics?.cpu?.percent ?? 0.0).toList(),
          timestamps: points.map((p) => p.ts).toList(),
          maxY: 100,
          unit: '%',
        ),
        const SizedBox(height: 8),
        const _ChartSectionHeader(title: 'Memoria RAM', icon: Icons.storage),
        _LineChartCard(
          label: 'Uso de RAM (%)',
          color: const Color(0xFFE3B341),
          points: points.map((p) => p.metrics?.mem?.percent ?? 0.0).toList(),
          timestamps: points.map((p) => p.ts).toList(),
          maxY: 100,
          unit: '%',
        ),
        if (hasSwap) ...[
          const SizedBox(height: 8),
          const _ChartSectionHeader(title: 'Swap', icon: Icons.swap_horiz),
          _LineChartCard(
            label: 'Uso de Swap (%)',
            color: const Color(0xFFDA3633),
            points: points.map((p) => p.metrics?.swap?.percent ?? 0.0).toList(),
            timestamps: points.map((p) => p.ts).toList(),
            maxY: 100,
            unit: '%',
          ),
        ],
        const SizedBox(height: 8),
        const _ChartSectionHeader(title: 'Red', icon: Icons.network_check),
        _DualLineChartCard(
          label1: 'RX (bytes)',
          label2: 'TX (bytes)',
          color1: const Color(0xFF3FB950),
          color2: const Color(0xFFF78166),
          points1: points
              .map((p) => (p.metrics?.net?.netRx ?? 0).toDouble())
              .toList(),
          points2: points
              .map((p) => (p.metrics?.net?.netTx ?? 0).toDouble())
              .toList(),
          timestamps: points.map((p) => p.ts).toList(),
        ),

        // ── Apache ────────────────────────────────────────────────────────────
        if (hasApache) ...[
          const SizedBox(height: 12),
          const _ChartSectionHeader(
            title: 'Apache2',
            icon: Icons.web,
            color: Color(0xFFD4551A),
          ),
          _LineChartCard(
            label: 'Peticiones / segundo',
            color: const Color(0xFFD4551A),
            points: points
                .map((p) => p.services?.apache2?.reqPerSec ?? 0.0)
                .toList(),
            timestamps: points.map((p) => p.ts).toList(),
            unit: ' req/s',
          ),
          const SizedBox(height: 8),
          _WorkersBarCard(points: points),
        ],

        // ── MariaDB ───────────────────────────────────────────────────────────
        if (hasMariaDb) ...[
          const SizedBox(height: 12),
          const _ChartSectionHeader(
            title: 'MariaDB',
            icon: Icons.storage,
            color: Color(0xFF5074B4),
          ),
          _LineChartCard(
            label: 'Conexiones activas',
            color: const Color(0xFF5074B4),
            points: points
                .map(
                  (p) =>
                      (p.services?.mariadb?.threads?.connected ?? 0).toDouble(),
                )
                .toList(),
            timestamps: points.map((p) => p.ts).toList(),
            unit: '',
          ),
          const SizedBox(height: 8),
          _LineChartCard(
            label: 'Queries lentas',
            color: const Color(0xFFDA3633),
            points: points
                .map((p) => p.services?.mariadb?.queries?.slowQueries ?? 0.0)
                .toList(),
            timestamps: points.map((p) => p.ts).toList(),
            unit: '',
          ),
        ],

        // ── SSH ───────────────────────────────────────────────────────────────
        if (hasSsh) ...[
          const SizedBox(height: 12),
          const _ChartSectionHeader(
            title: 'SSH',
            icon: Icons.terminal,
            color: Color(0xFF3FB950),
          ),
          _LineChartCard(
            label: 'Sesiones SSH estimadas',
            color: const Color(0xFF3FB950),
            points: points
                .map(
                  (p) => (p.services?.ssh?.sessionsEstimated ?? 0).toDouble(),
                )
                .toList(),
            timestamps: points.map((p) => p.ts).toList(),
            unit: ' sesiones',
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _ChartSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _ChartSectionHeader({
    required this.title,
    required this.icon,
    this.color = const Color(0xFF1F6FEB),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.3))),
        ],
      ),
    );
  }
}

// ── Single line chart ─────────────────────────────────────────────────────────
class _LineChartCard extends StatelessWidget {
  final String label;
  final Color color;
  final List<double> points;
  final List<DateTime> timestamps;
  final double? maxY;
  final String unit;

  const _LineChartCard({
    required this.label,
    required this.color,
    required this.points,
    required this.timestamps,
    this.maxY,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i]),
    );

    final current = points.last;
    final max = points.reduce((a, b) => a > b ? a : b);
    final min = points.reduce((a, b) => a < b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${current.toStringAsFixed(1)}$unit',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: const Color(0xFF30363D), strokeWidth: 1),
                  ),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY ?? (max * 1.2 + 0.1),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.12),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF21262D),
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)}$unit',
                              TextStyle(color: color, fontSize: 12),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mín: ${min.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 10,
                  ),
                ),
                Text(
                  'Máx: ${max.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dual line chart (RX / TX) ─────────────────────────────────────────────────
class _DualLineChartCard extends StatelessWidget {
  final String label1;
  final String label2;
  final Color color1;
  final Color color2;
  final List<double> points1;
  final List<double> points2;
  final List<DateTime> timestamps;

  const _DualLineChartCard({
    required this.label1,
    required this.label2,
    required this.color1,
    required this.color2,
    required this.points1,
    required this.points2,
    required this.timestamps,
  });

  String _formatBytes(double bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${bytes.toStringAsFixed(0)} B';
  }

  @override
  Widget build(BuildContext context) {
    if (points1.isEmpty) return const SizedBox.shrink();

    final spots1 = List.generate(
      points1.length,
      (i) => FlSpot(i.toDouble(), points1[i]),
    );
    final spots2 = List.generate(
      points2.length,
      (i) => FlSpot(i.toDouble(), points2[i]),
    );
    final allVals = [...points1, ...points2];
    final maxVal = allVals.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LegendDot(color: color1, label: label1),
                const SizedBox(width: 12),
                _LegendDot(color: color2, label: label2),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatBytes(points1.last),
                      style: TextStyle(
                        color: color1,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatBytes(points2.last),
                      style: TextStyle(
                        color: color2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFF30363D), strokeWidth: 1),
                  ),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxVal * 1.2 + 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots1,
                      isCurved: true,
                      color: color1,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color1.withOpacity(0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: spots2,
                      isCurved: true,
                      color: color2,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color2.withOpacity(0.08),
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
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
        ),
      ],
    );
  }
}

// ── Apache workers bar chart ───────────────────────────────────────────────────
class _WorkersBarCard extends StatelessWidget {
  final List<MetricPoint> points;
  const _WorkersBarCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final latest = points.lastWhere(
      (p) => p.services?.apache2 != null,
      orElse: () => points.last,
    );
    final apache = latest.services?.apache2;
    if (apache == null) return const SizedBox.shrink();

    final busy = apache.workers?.busy ?? 0;
    final idle = apache.workers?.idle ?? 0;
    final total = busy + idle;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workers Apache',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: busy.toInt(),
                  child: Container(
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4551A),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Ocupados: ${busy.toInt()}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                Expanded(
                  flex: idle.toInt(),
                  child: Container(
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3FB950),
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Libres: ${idle.toInt()}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
