/// metricas_screen.dart
///
/// Propósito:
///   Pantalla de métricas en tiempo real de un servidor concreto. Muestra series
///   temporales de CPU, RAM, red y servicios opcionales (Apache2, MariaDB, SSH,
///   Swap) como gráficas de línea y barra que se actualizan cada 30 segundos
///   mediante polling gestionado por [MetricsProvider].
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de métricas (screens/metricas/).
///
/// Clases definidas en este fichero:
///   - [MetricasScreen]:         StatefulWidget raíz; gestiona el ciclo de polling.
///   - [_MetricasScreenState]:   Estado con inicialización, dispose y selector de rango.
///   - [_RangeSelector]:         Barra de selección de rango temporal.
///   - [_RefreshIndicatorDot]:   Punto LIVE animado que indica polling activo.
///   - [_MetricasContent]:       Decide qué secciones de gráficas mostrar.
///   - [_ChartSectionHeader]:    Cabecera visual de sección de gráficas.
///   - [_LineChartCard]:         Tarjeta de gráfica de línea para una métrica.
///   - [_DualLineChartCard]:     Tarjeta de dos series en la misma gráfica (RX/TX).
///   - [_LegendDot]:             Punto de leyenda de color para gráficas duales.
///   - [_WorkersBarCard]:        Barra proporcional de workers de Apache.
///
/// Flujo de ciclo de vida del polling:
///   1. [didChangeDependencies]: lee el [Servidor] del argumento de ruta y obtiene
///      [MetricsProvider] con `context.read`. El flag `_initialized` evita
///      re-ejecución en llamadas subsiguientes a `didChangeDependencies`.
///   2. [addPostFrameCallback]: inicia el polling una vez pintado el primer frame,
///      con rango por defecto de 60 minutos.
///   3. [dispose]: llama a [MetricsProvider.stopPolling] para cancelar el timer
///      al salir de la pantalla. Sin esto, el timer continuaría ejecutándose en
///      segundo plano aunque la pantalla no esté visible.
///
/// Por qué `didChangeDependencies` en lugar de `initState`:
///   `ModalRoute.of(context)` no está disponible en `initState` porque la ruta
///   aún no se ha registrado como dependencia del widget en ese punto del ciclo
///   de vida. `didChangeDependencies` se llama tras `initState` y cada vez que
///   una dependencia [InheritedWidget] cambia; el flag `_initialized` garantiza
///   que la lógica de arranque solo se ejecute una vez.
///
/// Renderizado condicional por servicios:
///   [_MetricasContent] examina todos los [MetricPoint] recibidos para detectar
///   qué servicios tiene activos el servidor (`enabled == true` en al menos un
///   punto). Solo se muestran las secciones de servicios detectados:
///   - Siempre visibles: CPU, RAM, Red.
///   - Opcionales: Swap (si presente), Apache2, MariaDB, SSH.
///
/// Biblioteca de gráficas:
///   Se usa `fl_chart` (paquete externo). El eje X de todas las gráficas es el
///   índice posicional del punto (0, 1, 2 ...), no el timestamp real. Los
///   timestamps se pasan como parámetro pero actualmente no se usan para etiquetar
///   el eje X (ver observaciones).
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a MetricsService / MetricsProvider).
///   - Lógica de agregación o transformación de métricas.
///   - Widgets de gráficas reutilizables fuera del contexto de métricas.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/metrics_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla de métricas en tiempo real de un servidor.
///
/// Responsabilidad:
///   Arrancar y detener el polling de métricas al entrar/salir de la pantalla,
///   exponer el selector de rango temporal y delegar la visualización a
///   [_MetricasContent] a través de un [Consumer].
///
/// Recepción del servidor:
///   Lee el objeto [Servidor] desde `ModalRoute.of(context)!.settings.arguments`.
///   El cast directo lanzará [TypeError] si la ruta se navega sin argumento.
///
/// Diseño — Consumer en lugar de context.watch en build:
///   El cuerpo usa `Consumer<MetricsProvider>` para que solo la zona de gráficas
///   se reconstruya con cada actualización de métricas (cada 30 s). El `Scaffold`
///   y el `AppBar` quedan fuera del Consumer y no se reconstruyen innecesariamente.
///
/// Rangos disponibles:
///   `[30, 60, 360, 1440]` minutos — `['30 min', '1 h', '6 h', '24 h']`.
///   Los dos arrays son paralelos (mismo índice = mismo rango); deben mantenerse
///   en sincronía manualmente si se añaden o eliminan rangos.
class MetricasScreen extends StatefulWidget {
  const MetricasScreen({super.key});

  @override
  State<MetricasScreen> createState() => _MetricasScreenState();
}

class _MetricasScreenState extends State<MetricasScreen> {
  /// Servidor cuyas métricas se están mostrando.
  /// Se lee del argumento de ruta en [didChangeDependencies].
  late Servidor _servidor;

  /// Referencia al provider de métricas. Se obtiene con `context.read` en
  /// [didChangeDependencies] y se reutiliza en [dispose] para detener el polling.
  late MetricsProvider _metricsProvider;

  /// Evita que [didChangeDependencies] ejecute la inicialización más de una vez.
  /// Sin este flag, cada cambio en un [InheritedWidget] ancestro relanzaría
  /// el polling desde cero.
  bool _initialized = false;

  /// Valores de rango temporal en minutos. Índice sincronizado con [_rangeLabels].
  final List<int> _ranges = [30, 60, 360, 1440];

  /// Etiquetas de los botones de rango. Índice sincronizado con [_ranges].
  final List<String> _rangeLabels = ['30 min', '1 h', '6 h', '24 h'];

  // ── CICLO DE VIDA: CONFIGURACIÓN DINÁMICA ───────────────────────────────────

  /// Este método de Flutter se ejecuta automáticamente inmediatamente después de 'initState',
  /// y también cada vez que un widget superior del que dependemos cambia sus datos.
  @override
  void didChangeDependencies() {
    super
        .didChangeDependencies(); // Buenas prácticas: invocar siempre al método padre.

    // CONTROL DE FLUJO: Si ya se inicializó la pantalla en el pasado, ignoramos
    // todo lo de adentro para no reiniciar el temporizador de métricas por error.
    if (!_initialized) {
      // 1. EXTRACTOR DE ARGUMENTOS:
      // Cuando viajas a esta pantalla usando el enrutador de Flutter (Navigator),
      // extraemos el objeto 'Servidor' que se pasó como parámetro en la ruta.
      _servidor = ModalRoute.of(context)!.settings.arguments as Servidor;

      // 2. CONEXIÓN CON EL PROVIDER:
      // Buscamos el 'MetricsProvider' en el árbol de widgets usando 'context.read'.
      // Usamos '.read' en lugar de '.watch' porque solo queremos una referencia directa
      // para ejecutar funciones (acciones), no queremos que esta pantalla entera se redibuje
      // cada vez que el Provider cambie internamente.
      _metricsProvider = context.read<MetricsProvider>();

      // Marcar como inicializado para cerrar con llave este bloque 'if' para siempre.
      _initialized = true;

      // 3. REGISTRO DEL DISPARO POST-RENDERIZADO (El Polling):
      // Flutter prohíbe arrancar peticiones que actualicen el estado MIENTRAS se está
      // dibujando la pantalla (fase de build).
      // 'addPostFrameCallback' le dice a Flutter: "En cuanto termines de pintar este primer
      // frame en la pantalla del usuario, ejecuta INMEDIATAMENTE este bloque de código".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Verificación de seguridad: Si el usuario entró y salió de la pantalla
        // ultra rápido antes de que se pintara el frame, cancelamos la operación.
        if (!mounted) return;

        // DISPARO INICIAL: Le pedimos al Provider que empiece a descargar datos en bucle
        // (polling) usando el ID del servidor actual y configurando el rango por defecto a 1 hora (60 min).
        _metricsProvider.startPolling(
          _servidor.serverId,
          rangeMinutes: 60, // Rango por defecto al entrar en la pantalla.
        );
      });
    }
  }

  /// Detiene el polling al destruir el widget.
  ///
  /// Sin esta llamada, el [Timer.periodic] de [MetricsProvider] continuaría
  /// ejecutándose aunque la pantalla ya no sea visible, consumiendo red y
  /// CPU innecesariamente.
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
      // Consumer limita los rebuilds de métricas al body, sin reconstruir el Scaffold.
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
                    // Carga inicial: aún no hay puntos y se está cargando.
                    ? const AppLoadingWidget(message: 'Cargando métricas…')
                    : provider.error != null && provider.points.isEmpty
                    // Error en la primera carga: no hay datos para mostrar.
                    // Si hay error pero YA hay puntos, el error es silencioso
                    // y se siguen mostrando los datos del último poll exitoso.
                    ? AppErrorWidget(
                        message: 'Error al cargar métricas:\n${provider.error}',
                        onRetry: () => provider.startPolling(
                          _servidor.serverId,
                          rangeMinutes: provider.rangeMinutes,
                        ),
                      )
                    : provider.points.isEmpty
                    // Sin datos y sin carga activa: servidor sin métricas.
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

// ── Selector de rango temporal ─────────────────────────────────────────────────

/// Barra de selección del rango temporal de las métricas.
///
/// Responsabilidad:
///   Mostrar los botones de rango disponibles (30 min, 1 h, 6 h, 24 h) y notificar
///   al llamador qué rango se ha seleccionado mediante [onChanged]. El estado del
///   rango activo vive en [MetricsProvider], no en este widget.
///
/// El botón activo ([selected]) se resalta con fondo azul y texto blanco en negrita.
/// Los botones inactivos tienen fondo gris oscuro y texto gris.
///
/// El punto animado [_RefreshIndicatorDot] en el extremo derecho indica visualmente
/// que el polling está activo mientras la pantalla está visible.
class _RangeSelector extends StatelessWidget {
  /// Valores de rango en minutos. Índice sincronizado con [labels].
  final List<int> ranges;

  /// Etiquetas mostradas en los botones. Índice sincronizado con [ranges].
  final List<String> labels;

  /// Valor del rango actualmente seleccionado (en minutos).
  final int selected;

  /// Callback invocado con el nuevo valor de rango al pulsar un botón.
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
          //const Spacer(),
          //const _RefreshIndicatorDot(),
        ],
      ),
    );
  }
}

// ── Punto LIVE animado ─────────────────────────────────────────────────────────

/// Indicador visual de polling activo: punto verde con animación de pulso.
///
/// Responsabilidad:
///   Mostrar un pequeño círculo verde que pulsa (fade in/out) junto a la etiqueta
///   "LIVE", indicando al usuario que las métricas se están actualizando.
///
/// Implementación — animación en ping-pong:
///   Usa [AnimationController] con `repeat(reverse: true)` para hacer que la
///   opacidad del círculo oscile entre 0.3 y 1.0 con periodo de 2 segundos.
///   `Color.fromRGBO` con el valor animado como canal alfa produce el efecto de
///   pulso sin necesidad de un [FadeTransition] adicional.
///
/// [SingleTickerProviderStateMixin] aporta el `vsync` requerido por
/// [AnimationController] para sincronizar la animación con el framerate del
/// sistema y evitar trabajo innecesario cuando la pantalla no es visible.
/*class _RefreshIndicatorDot extends StatefulWidget {
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
    )..repeat(reverse: true); // Ping-pong: va de 0.3 a 1.0 y vuelve.
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    // Liberar el controller para detener la animación y sus recursos.
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El canal alfa (_anim.value) oscila entre 0.3 y 1.0 produciendo el pulso.
          // RGB corresponde al verde 0xFF3FB950 de la paleta GitHub Dark.
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
}*/

// ── Contenido principal de métricas ───────────────────────────────────────────

/// Widget que organiza y renderiza todas las secciones de gráficas.
///
/// Responsabilidad:
///   Recibir la lista de [MetricPoint] del provider y decidir qué secciones
///   mostrar en función de los servicios detectados en los datos. Las secciones
///   de CPU, RAM y Red son siempre visibles; Swap, Apache2, MariaDB y SSH son
///   opcionales y se muestran solo si al menos un punto en el rango los tiene activos.
///
/// Detección de servicios:
///   Usa `points.any((p) => ...)` para examinar todos los puntos del rango antes
///   de decidir si mostrar una sección. Esto evita mostrar una sección de Apache,
///   por ejemplo, si el servidor tenía Apache activo hace 6 horas pero ya no.
///
/// Eje X de las gráficas:
///   Todos los widgets de gráfica usan el índice posicional del punto (0, 1, 2...)
///   como eje X. Los timestamps se pasan como parámetro a [_LineChartCard] y
///   [_DualLineChartCard] pero actualmente no se usan para etiquetar el eje.
class _MetricasContent extends StatelessWidget {
  /// Lista de puntos de métricas del rango seleccionado, en orden temporal.
  final List<MetricPoint> points;

  const _MetricasContent({required this.points});

  @override
  Widget build(BuildContext context) {
    // Detección de servicios opcionales: se activa la sección solo si hay al
    // menos un punto con ese servicio enabled en el rango actual.
    final hasApache = points.any((p) => p.services?.apache2?.enabled == true);
    final hasMariaDb = points.any((p) => p.services?.mariadb?.enabled == true);
    final hasSsh = points.any((p) => p.services?.ssh?.enabled == true);
    final hasSwap = points.any((p) => p.metrics?.swap?.present == true);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── CPU ──────────────────────────────────────────────────────────────
        const _ChartSectionHeader(title: 'CPU', icon: Icons.memory),
        _LineChartCard(
          label: 'Uso de CPU (%)',
          color: const Color(0xFF388BFD),
          points: points.map((p) => p.metrics?.cpu?.percent ?? 0.0).toList(),
          timestamps: points.map((p) => p.ts).toList(),
          maxY: 100, // CPU nunca supera el 100%.
          unit: '%',
        ),
        const SizedBox(height: 8),

        // ── Memoria RAM ───────────────────────────────────────────────────────
        const _ChartSectionHeader(title: 'Memoria RAM', icon: Icons.storage),
        _LineChartCard(
          label: 'Uso de RAM (%)',
          color: const Color(0xFFE3B341),
          points: points.map((p) => p.metrics?.mem?.percent ?? 0.0).toList(),
          timestamps: points.map((p) => p.ts).toList(),
          maxY: 100,
          unit: '%',
        ),

        // ── Swap (condicional) ────────────────────────────────────────────────
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

        // ── Red ───────────────────────────────────────────────────────────────
        const SizedBox(height: 8),
        const _ChartSectionHeader(title: 'Red', icon: Icons.network_check),
        /*_DualLineChartCard(
          label1: 'RX (bytes)',
          label2: 'TX (bytes)',
          color1: const Color(0xFF3FB950), // Verde: recepción
          color2: const Color(0xFFF78166), // Naranja/coral: transmisión
          points1: points
              .map((p) => (p.metrics?.net?.netRx ?? 0).toDouble())
              .toList(),
          points2: points
              .map((p) => (p.metrics?.net?.netTx ?? 0).toDouble())
              .toList(),
          timestamps: points.map((p) => p.ts).toList(),
        )*/
        Center(child: Text("Fuera de servicio.")),

        // ── Apache2 (condicional) ─────────────────────────────────────────────
        if (hasApache) ...[
          const SizedBox(height: 12),
          const _ChartSectionHeader(
            title: 'Apache2',
            icon: Icons.web,
            color: Color(0xFFD4551A), // Naranja Apache
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
          // Barra proporcional de workers ocupados vs. libres del último punto.
          //_WorkersBarCard(points: points),
          Center(child: Text("Workers: fuera de servicio.")),
        ],

        // ── MariaDB (condicional) ─────────────────────────────────────────────
        if (hasMariaDb) ...[
          const SizedBox(height: 12),
          const _ChartSectionHeader(
            title: 'MariaDB',
            icon: Icons.storage,
            color: Color(0xFF5074B4), // Azul MariaDB
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

        // ── SSH (condicional) ─────────────────────────────────────────────────
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

// ── Cabecera de sección de gráficas ───────────────────────────────────────────

/// Cabecera visual de una sección de gráficas con icono, título y divisor.
///
/// Responsabilidad:
///   Separar visualmente las secciones de gráficas (CPU, RAM, Apache, etc.) con
///   un icono de color, el título en negrita y un divisor horizontal que se
///   extiende hasta el borde del contenedor.
///
/// El [color] por defecto es el azul primario `0xFF1F6FEB`. Las secciones de
/// servicios de terceros pasan su propio color de marca (naranja para Apache,
/// azul para MariaDB, verde para SSH).
class _ChartSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  /// Color del icono, título y divisor. Por defecto azul primario de la app.
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
          // Divisor que ocupa el espacio restante de la fila.
          Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

// ── Gráfica de una serie ───────────────────────────────────────────────────────

/// Tarjeta de gráfica de línea para una única métrica temporal.
///
/// Responsabilidad:
///   Renderizar una [LineChart] de `fl_chart` con el historial de valores de una
///   métrica, mostrando el valor actual (último punto), el mínimo y el máximo del
///   rango, y un tooltip al tocar la gráfica.
///
/// Eje X:
///   Usa el índice posicional del punto (`FlSpot(i.toDouble(), value)`) como eje X.
///   El parámetro [timestamps] se pasa pero actualmente no se usa para etiquetar el eje.
///
/// Escala del eje Y:
///   - Si [maxY] se proporciona (CPU, RAM, Swap): eje fijo 0–100%.
///   - Si [maxY] es `null`: el techo es `max * 1.2 + 0.1`, dejando un 20% de
///     margen sobre el valor máximo. El `+ 0.1` evita que maxY sea 0 cuando
///     todos los valores son 0.
///
/// Estadísticas mostradas:
///   - Cabecera derecha: valor del último punto (valor actual).
///   - Pie de tarjeta: mínimo y máximo del rango visible.
class _LineChartCard extends StatelessWidget {
  /// Etiqueta descriptiva de la métrica (ej. "Uso de CPU (%)").
  final String label;

  /// Color de la línea, el área de relleno y el valor actual.
  final Color color;

  /// Valores de la métrica en orden temporal (un double por punto).
  final List<double> points;

  /// Timestamps correspondientes a cada punto. Actualmente no usados en el eje X.
  final List<DateTime> timestamps;

  /// Techo fijo del eje Y. Si es `null`, se calcula dinámicamente.
  final double? maxY;

  /// Sufijo de unidad para el tooltip y las estadísticas (ej. `'%'`, `' req/s'`).
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
    // CONTROL DE EXCEPCIÓN: Si no hay datos históricos que pintar, se retorna un widget
    // vacío sin dimensiones.
    if (points.isEmpty) return const SizedBox.shrink();

    // MAPEADO DE DATOS: `fl_chart` requiere objetos [FlSpot]. Como no pintamos el tiempo
    // real en el eje X, convertimos el índice posicional de la lista (0, 1, 2...) en la coordenada X.
    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i]),
    );

    // CÁLCULO DE ESTADÍSTICAS:
    // Se asume que el último elemento de la lista es el dato recolectado más reciente.
    final current = points.last;
    // ── EXPLICACIÓN DETALLADA DEL CÁLCULO DE MÍNIMOS Y MÁXIMOS ─────────────────
    //
    // ¿Cómo funciona .reduce()?
    // El método .reduce() fusiona todos los elementos de una lista en un único valor.
    // Recorre la lista pasando dos variables a la función anónima:
    //   - 'a' (Acumulador): Guarda el "ganador" de la comparación anterior.
    //   - 'b' (Elemento actual): El elemento que se está evaluando en el ciclo.
    //
    // El Operador Ternario (condición ? si_verdadero : si_falso):
    // Es un IF-ELSE compacto. 'a > b ? a : b' significa:
    // "¿Es 'a' mayor que 'b'? Si es SI, mantén 'a'. Si es NO, cambia a 'b'".
    //
    // Ejemplo de Simulación Visual con la lista [15.0, 42.0, 8.0]:
    //
    // Para MAX (Buscando el mayor):
    //   - Ronda 1: a = 15.0, b = 42.0 -> ¿15 > 42? NO. El acumulador 'a' pasa a ser 42.0
    //   - Ronda 2: a = 42.0, b =  8.0 -> ¿42 >  8? SÍ. El acumulador 'a' se queda en 42.0
    //   Resultado final guardado en max = 42.0
    //
    // Para MIN (Buscando el menor con 'a < b ? a : b'):
    //   - Ronda 1: a = 15.0, b = 42.0 -> ¿15 < 42? SÍ. El acumulador 'a' se queda en 15.0
    //   - Ronda 2: a = 15.0, b =  8.0 -> ¿15 <  8? NO. El acumulador 'a' pasa a ser 8.0
    //   Resultado final guardado en min = 8.0
    //
    // NOTA DE SEGURIDAD: .reduce() arroja un error ('StateError') si la lista está vacía.
    // Este cálculo es 100% seguro aquí gracias al "if (points.isEmpty)" de la línea superior.
    // ───────────────────────────────────────────────────────────────────────────
    final max = points.reduce((a, b) => a > b ? a : b);
    final min = points.reduce((a, b) => a < b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECCIÓN 1: CABECERA (Etiqueta y Valor Actual) ────────────────
            Row(
              children: [
                // Nombre de la métrica (Ej: "Uso de CPU")
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
                const Spacer(), // Empuja el valor actual completamente hacia la derecha
                // Valor actual más reciente destacado con el color de la métrica
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
            // ── SECCIÓN 2: CUERPO (La Gráfica de Líneas) ─────────────────────
            SizedBox(
              height:
                  100, // Altura fija y compacta ideal para vistas tipo Dashboard / Grid
              child: LineChart(
                LineChartData(
                  // Configuración de la Cuadrícula de Fondo
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine:
                        false, // Se ocultan las líneas verticales para limpiar el diseño
                    // Define el estilo exclusivamente para las líneas horizontales de guía,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: const Color(0xFF30363D), strokeWidth: 1),
                  ),
                  // Configuración de los Títulos de los Ejes
                  // Se desactivan por completo los cuatro ejes (izq, der, sup, inf).
                  // Al ser una gráfica miniatura, ocultar los números maximiza el espacio útil del dibujo.
                  titlesData: const FlTitlesData(
                    // Se ocultan todos los títulos de ejes para maximizar el espacio
                    // de la gráfica dentro de la tarjeta compacta.
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
                  // Se elimina el borde exterior del lienzo de la gráfica
                  borderData: FlBorderData(show: false),
                  // Escala del Eje Y
                  minY: 0, // El piso de la gráfica siempre arranca en 0
                  // LÓGICA DE TECHO VERTICAL:
                  // Si se provee [maxY] (ej: 100 para porcentaje), se respeta.
                  // Si es null, se multiplica el máximo por 1.2 (20% de margen de holgura superior)
                  // y se suma 0.1 para evitar fallos visuales si el valor máximo del arreglo llegase a ser 0.
                  maxY: maxY ?? (max * 1.2 + 0.1),
                  // Configuración de la Línea de Datos (Dataset)
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots, // Asignación de los puntos calculados
                      isCurved:
                          true, // Habilita la interpolación de curvas suavizadas (Spline) en vez de líneas rectas
                      color: color,
                      barWidth: 2, // Grosor estilizado de la línea
                      dotData: const FlDotData(show: false),
                      // Relleno cromático degradado/translúcido debajo de la línea curva
                      belowBarData: BarAreaData(
                        show: true,
                        // Opacidad muy baja (12%) para que el fondo no sature la vista ni tape la cuadrícula
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                  // Configuración de Interactividad (Gestos / Touch)
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      // Color de fondo del globo/tooltip flotante
                      getTooltipColor: (_) => const Color(0xFF21262D),
                      // Estructura y formato del texto dentro del tooltip al posicionarse sobre un punto
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)}$unit', // Muestra la coordenada Y formateada
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
            // ── SECCIÓN 3: PIE DE PÁGINA (Estadísticas de Extremos) ──────────
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

/*
// ── Gráfica dual RX/TX ─────────────────────────────────────────────────────────

/// Tarjeta de gráfica de línea con dos series superpuestas (tráfico RX y TX).
///
/// Responsabilidad:
///   Mostrar en un mismo [LineChart] las series de bytes recibidos ([points1])
///   y bytes transmitidos ([points2]) con colores diferenciados y una leyenda
///   de puntos con etiquetas. Los valores del último punto se muestran formateados
///   como B/KB/MB/GB.
///
/// Escala del eje Y:
///   El techo se calcula sobre el máximo de AMBAS series: `maxVal * 1.2 + 1`.
///   El `+1` evita que `maxY == 0` cuando no hay tráfico de red.
///
/// Parámetro [timestamps]:
///   Se declara y se pasa pero actualmente no se usa en la gráfica (el eje X
///   usa índices posicionales). Se mantiene por coherencia de interfaz con
///   [_LineChartCard].
class _DualLineChartCard extends StatelessWidget {
  /// Etiqueta de la primera serie (RX).
  final String label1;

  /// Etiqueta de la segunda serie (TX).
  final String label2;

  /// Color de la primera serie.
  final Color color1;

  /// Color de la segunda serie.
  final Color color2;

  /// Valores de la primera serie en orden temporal.
  final List<double> points1;

  /// Valores de la segunda serie en orden temporal.
  final List<double> points2;

  /// Timestamps de los puntos. Declarado por coherencia; actualmente no usado en el eje X.
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

  /// Convierte bytes a una representación legible usando prefijos binarios (base 1024).
  ///
  /// Umbrales: 1 GB = 1 073 741 824 B, 1 MB = 1 048 576 B, 1 KB = 1 024 B.
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
    // El techo del eje Y se calcula sobre el máximo combinado de ambas series.
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
                // Valor actual de cada serie formateado como B/KB/MB/GB.
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
                  // +1 evita maxY == 0 cuando no hay tráfico de red en todo el rango.
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
                        color: color1.withValues(alpha: 0.08),
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
                        color: color2.withValues(alpha: 0.08),
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

// ── Punto de leyenda ───────────────────────────────────────────────────────────

/// Indicador de leyenda compacto: círculo de color + etiqueta de texto.
///
/// Usado en [_DualLineChartCard] para identificar visualmente cada serie.
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
*/
/*
// ── Barra de workers Apache ────────────────────────────────────────────────────

/// Tarjeta de barra proporcional con el estado de los workers de Apache.
///
/// Responsabilidad:
///   Mostrar la proporción de workers ocupados (naranja) vs. libres (verde) del
///   punto más reciente con datos de Apache, usando `Expanded(flex: n)` para
///   que el ancho de cada segmento sea proporcional al recuento de workers.
///
/// Selección del punto más reciente con datos:
///   Usa `lastWhere((p) => p.services?.apache2 != null)` para encontrar el último
///   punto que incluye datos de Apache (no necesariamente el último punto global).
///   Si ningún punto tiene datos, el fallback a `points.last` puede devolver un
///   punto sin Apache, lo que dispara el guard `if (apache == null) return shrink`.
///
/// Guard de total cero:
///   Si `busy + idle == 0` (Apache sin workers, estado inusual), no se renderiza
///   la barra para evitar un `Expanded(flex: 0)` que causaría error en Flutter.
class _WorkersBarCard extends StatelessWidget {
  /// Lista completa de puntos de métricas del rango. Se busca el más reciente
  /// con datos de Apache.
  final List<MetricPoint> points;

  const _WorkersBarCard({required this.points});

  @override
  Widget build(BuildContext context) {
    // Busca el último punto que contiene datos de Apache.
    // El fallback a points.last puede no tener Apache; se comprueba abajo.
    final latest = points.lastWhere(
      (p) => p.services?.apache2 != null,
      orElse: () => points.last,
    );
    final apache = latest.services?.apache2;
    if (apache == null) return const SizedBox.shrink();

    final busy = apache.workers?.busy ?? 0;
    final idle = apache.workers?.idle ?? 0;
    final total = busy + idle;
    // Guard: Expanded(flex: 0) lanza AssertionError en Flutter.
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
            // La barra usa flex proporcional: busy/(busy+idle) de ancho para
            // el segmento naranja e idle/(busy+idle) para el verde.
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
*/
