/// shared_widgets.dart
///
/// Propósito:
///   Biblioteca de widgets de presentación reutilizables para toda la aplicación
///   Metrics Manager. Centraliza los componentes visuales genéricos de manera que
///   todas las pantallas compartan el mismo aspecto y comportamiento ante estados
///   comunes (carga, error, vacío) y elementos de UI frecuentes (badges, filas de
///   información, encabezados de sección, imágenes con fallback).
///
/// Capa arquitectónica:
///   Capa de presentación — sublayer de widgets compartidos (core/widgets/).
///   Estos widgets son completamente "tontos" (dumb/stateless): no acceden a
///   ningún provider, servicio ni modelo de dominio. Únicamente reciben datos
///   primitivos o callbacks por parámetro y los renderizan.
///
/// Responsabilidades principales:
///   - Proveer estados de feedback visual uniformes: carga, error, vacío.
///   - Ofrecer componentes de UI atómicos reutilizables: badge de estado,
///     fila de información icono+etiqueta+valor, encabezado de sección con divisor.
///   - Gestionar la carga asíncrona de imágenes remotas con placeholder y fallback,
///     tanto para miniaturas de servidores como para logos de servicios.
///
/// Qué NO debe contener este fichero:
///   - Lógica de negocio ni transformaciones de modelo.
///   - Llamadas a providers, servicios o repositorios.
///   - Navegación (Navigator/GoRouter).
///   - Gestión de estado (no hay StatefulWidgets aquí por diseño).
///   - Constantes de rutas, textos de error de dominio ni etiquetas específicas
///     de una sola pantalla.
///
/// Nota de diseño — tema visual:
///   Todos los widgets asumen un tema oscuro estilo GitHub Dark. Los colores están
///   definidos como literales hex (p. ej. `Color(0xFF8B949E)` para el gris
///   secundario, `Color(0xFF30363D)` para bordes y `Color(0xFF1F6FEB)` para el
///   acento azul). Si en el futuro se extiende el sistema de temas, estas
///   constantes deberían migrar a `ThemeData` o a un archivo de tokens de diseño.
///
/// Nota de compatibilidad — Flutter API:
///   Se usa `color.withValues(alpha: x)` en lugar del deprecated `withOpacity(x)`,
///   introducido en Flutter 3.x para mayor precisión en espacios de color.
library; // Asignar toda la documentación inicial a nivel de archivo completo y no solo al primer widget.

import 'package:flutter/material.dart';

// ── Loading ────────────────────────────────────────────────────────────────────

/// Widget de estado de carga genérico.
///
/// Muestra un [CircularProgressIndicator] centrado en pantalla. Opcionalmente
/// acepta un [message] descriptivo para informar al usuario sobre la operación
/// en curso (p. ej. "Cargando servidores…", "Autenticando…").
///
/// Se utiliza en todas las pantallas de la app mientras los providers están en
/// estado de carga asíncrona (petición HTTP a api-py pendiente de respuesta).
///
/// Diseño:
///   - [StatelessWidget] puro: no gestiona estado interno.
///   - El mensaje es opcional para mantener el widget reutilizable en contextos
///     donde el texto de carga no aporta información al usuario.
class AppLoadingWidget extends StatelessWidget {
  /// Texto informativo que se muestra debajo del indicador de progreso.
  /// Si es `null`, solo se renderiza el spinner.
  final String? message;
  const AppLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            // Aplica transparencia al mensaje para que tenga menor jerarquía
            // visual que el indicador de progreso.
            Text(
              message!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

/// Widget de estado de error genérico con soporte para reintento.
///
/// Muestra un icono de error, el mensaje de fallo recibido y, opcionalmente,
/// un botón "Reintentar" que invoca el callback [onRetry].
///
/// Uso típico en la app:
///   Cuando un provider expone un estado de error tras una petición fallida a
///   api-py (timeout, error HTTP 4xx/5xx, sin conexión), la pantalla muestra
///   este widget pasando el mensaje del error y un callback que vuelve a llamar
///   al método de carga del provider.
///
/// Diseño:
///   - El botón de reintento es opcional: hay pantallas donde no tiene sentido
///     reintentar (p. ej. errores de autorización 403 que requieren re-login).
///   - [onRetry] es un [VoidCallback], por lo que el widget no conoce ni le
///     importa qué operación se reintenta; esa responsabilidad recae en el
///     llamador.
class AppErrorWidget extends StatelessWidget {
  /// Mensaje de error a mostrar al usuario. Puede ser el mensaje HTTP recibido
  /// de api-py o un texto amigable generado por el provider.
  final String message;

  /// Callback opcional invocado cuando el usuario pulsa "Reintentar".
  /// Si es `null`, el botón de reintento no se renderiza.
  final VoidCallback? onRetry;

  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.redAccent.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

/// Widget de estado vacío genérico.
///
/// Se muestra cuando una lista o colección de datos no contiene elementos,
/// diferenciándolo del estado de error: aquí no hay fallo, simplemente no
/// hay datos que mostrar (p. ej. "No hay servidores en este grupo",
/// "No hay métricas registradas").
///
/// Acepta un [icon] personalizable para que cada pantalla pueda transmitir
/// contexto visual apropiado. El icono por defecto [Icons.inbox_outlined]
/// es suficientemente neutro para la mayoría de casos.
///
/// Diseño:
///   - Los colores (`Colors.white24`, `Colors.white38`) tienen baja opacidad
///     deliberadamente: el estado vacío no debe competir visualmente con el
///     contenido real de la pantalla; es un estado secundario.
class EmptyStateWidget extends StatelessWidget {
  /// Mensaje descriptivo del estado vacío. Debe ser específico del contexto
  /// del llamador (p. ej. "No tienes servidores registrados").
  final String message;

  /// Icono representativo del tipo de contenido vacío.
  /// Por defecto usa [Icons.inbox_outlined] como indicador genérico de vacío.
  final IconData icon;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────────

/// Píldora de estado coloreada para indicar el estado de una entidad.
///
/// Renderiza una etiqueta compacta con fondo semitransparente y borde del
/// color proporcionado, siguiendo el patrón visual de badges de GitHub.
///
/// Se usa principalmente en las tarjetas de servidores y grupos para mostrar
/// estados como "ONLINE", "OFFLINE", "DEGRADED", "MAINTENANCE", etc. El color
/// es responsabilidad del llamador, que debe mapearlo desde el valor del modelo
/// (p. ej. verde para ONLINE, rojo para OFFLINE).
///
/// Diseño de color:
///   - Fondo: `color` al 15% de opacidad — sutil, no distrae del contenido.
///   - Borde: `color` al 50% de opacidad — delimita la píldora sin ser agresivo.
///   - Texto: `color` al 100% — es el elemento de mayor jerarquía en el badge.
class StatusBadge extends StatelessWidget {
  /// Texto a mostrar dentro de la píldora (p. ej. "ONLINE", "OFFLINE").
  final String label;

  /// Color base del badge. Se aplica al texto, borde y fondo (con opacidades
  /// distintas). El llamador es responsable de elegir el color apropiado según
  /// el estado de negocio.
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

/// Fila de información con icono, etiqueta y valor.
///
/// Patrón de UI recurrente en las pantallas de detalle (servidor, grupo, servicio):
/// muestra un dato con su icono representativo, una etiqueta descriptiva en gris
/// secundario y el valor en blanco con mayor jerarquía visual.
///
/// Ejemplo de uso:
/// ```dart
/// InfoRow(
///   icon: Icons.memory,
///   label: 'CPU',
///   value: '45%',
/// )
/// ```
///
/// Diseño:
///   - [crossAxisAlignment] en `CrossAxisAlignment.start` para que valores
///     multilínea (p. ej. URLs largas) no descentren el icono.
///   - El [Expanded] en la columna de texto previene desbordamientos horizontales
///     en valores largos.
///   - El color `0xFF8B949E` es el gris secundario del tema GitHub Dark; se usa
///     consistentemente en etiquetas e iconos de menor jerarquía.
class InfoRow extends StatelessWidget {
  /// Icono representativo del dato (p. ej. [Icons.memory], [Icons.dns]).
  final IconData icon;

  /// Etiqueta descriptiva del dato, mostrada en gris secundario sobre el valor.
  final String label;

  /// Valor del dato, mostrado en blanco con mayor peso visual que [label].
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8B949E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

/// Encabezado de sección con título, icono opcional y línea divisora.
///
/// Separa visualmente bloques de contenido dentro de una pantalla de detalle.
/// Combina un icono de acento (azul primario `0xFF1F6FEB`), el título de la
/// sección en blanco y un [Divider] que se extiende hasta el borde derecho,
/// creando una separación clara sin usar bordes de tarjeta o padding excesivo.
///
/// Se usa en pantallas de detalle de servidor, grupo y servicio para separar
/// secciones como "Información general", "Servicios activos", "Métricas", etc.
///
/// Diseño:
///   - Padding superior de 20px y 10px inferior: el espacio superior es mayor
///     para que el encabezado respire respecto al contenido previo.
///   - El [Expanded] en el [Divider] garantiza que la línea ocupe todo el
///     espacio restante independientemente de la longitud del título.
class SectionHeader extends StatelessWidget {
  /// Título de la sección.
  final String title;

  /// Icono de acento mostrado a la izquierda del título.
  /// Si es `null`, el título aparece sin icono pero con la misma línea divisora.
  final IconData? icon;

  const SectionHeader({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: const Color(0xFF1F6FEB)),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xFF30363D))),
        ],
      ),
    );
  }
}

// ── Server image (FadeInImage wrapper) ────────────────────────────────────────

/// Imagen de servidor con carga progresiva y fallback robusto.
///
/// Encapsula [FadeInImage.assetNetwork] para mostrar la imagen de un servidor
/// con transición suave desde el placeholder. Maneja tres escenarios:
///
///   1. URL nula o vacía → muestra directamente el placeholder con icono DNS.
///   2. URL válida, carga exitosa → muestra la imagen con fade-in.
///   3. URL válida, error de red/formato → fallback al placeholder con icono DNS.
///
/// El asset `assets/no_image.png` actúa como placeholder durante la descarga.
/// Si la descarga falla (red inaccesible, URL rota, formato no soportado), el
/// [imageErrorBuilder] garantiza que nunca se muestre un widget de error nativo
/// de Flutter, preservando la experiencia visual.
///
/// Uso típico: miniaturas de servidores en listas y pantallas de detalle. La URL
/// de imagen proviene del campo correspondiente del modelo de servidor devuelto
/// por api-py.
///
/// Parámetros de tamaño:
///   - [width] y [height] por defecto 60×60px: adecuado para listas.
///   - [fit] por defecto [BoxFit.cover]: la imagen llena el área recortando
///     si es necesario, lo que mantiene el layout estable.
///
/// Limitación conocida:
///   No gestiona caché de imágenes de forma explícita; depende del caché HTTP
///   interno de Flutter/Dart (basado en cabeceras Cache-Control de la respuesta).
///   Si api-py no devuelve cabeceras de caché, las imágenes se redescargan en
///   cada reconstrucción.
class ServerImage extends StatelessWidget {
  /// URL absoluta de la imagen del servidor. Puede ser `null` si el servidor
  /// no tiene imagen configurada en api-py.
  final String? imageUrl;

  /// Ancho del widget en píxeles lógicos. Por defecto 60.
  final double width;

  /// Alto del widget en píxeles lógicos. Por defecto 60.
  final double height;

  /// Modo de ajuste de la imagen al área disponible. Por defecto [BoxFit.cover].
  final BoxFit fit;

  const ServerImage({
    super.key,
    required this.imageUrl,
    this.width = 60,
    this.height = 60,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostramos el placeholder directamente sin intentar
    // crear un FadeInImage (evita errores y ciclos de carga innecesarios).
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }
    return FadeInImage.assetNetwork(
      placeholder: 'assets/no_image.png',
      image: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      // Fallback ante cualquier error de carga de red o decodificación de imagen.
      // El tercer parámetro (_) es el StackTrace, ignorado intencionalmente.
      imageErrorBuilder: (context, error, _) => _placeholder(),
    );
  }

  /// Construye el placeholder visual para cuando no hay imagen disponible.
  ///
  /// Usa el color de fondo de tarjeta del tema oscuro (`0xFF21262D`) con un
  /// icono DNS (`Icons.dns_outlined`) en gris secundario (`0xFF8B949E`).
  /// Respeta las dimensiones [width] y [height] configuradas para mantener
  /// el layout de la pantalla llamadora.
  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF21262D),
      child: const Icon(Icons.dns_outlined, color: Color(0xFF8B949E)),
    );
  }
}

// ── Service logo (FadeInImage wrapper) ────────────────────────────────────────

/// Logo de servicio con carga progresiva y fallback a icono de ajustes.
///
/// Variante de [ServerImage] especializada para logos de servicios (p. ej.
/// Nginx, MySQL, Redis). Usa un área cuadrada definida por [size] y
/// [BoxFit.contain] en lugar de [BoxFit.cover], lo que preserva las
/// proporciones del logo sin recortarlo — crítico para logos con transparencia
/// o relaciones de aspecto no cuadradas.
///
/// A diferencia de [ServerImage], el fallback no es un [Container] con fondo
/// de color sino directamente un [Icon] (`Icons.settings_outlined`), más
/// apropiado para el tamaño compacto en el que se usan los logos de servicio.
///
/// La URL del logo proviene del campo correspondiente del modelo de servicio
/// devuelto por api-py y puede ser una URL externa (CDN de logos de tecnologías)
/// o una URL interna.
///
/// Limitación conocida:
///   Comparte la misma limitación de caché que [ServerImage]: sin cabeceras
///   Cache-Control explícitas en api-py, los logos se recargan en cada rebuild.
class ServiceLogo extends StatelessWidget {
  /// URL absoluta del logo del servicio. Puede ser `null` si el servicio no
  /// tiene logo configurado en api-py.
  final String? logoUrl;

  /// Tamaño del widget (ancho y alto iguales) en píxeles lógicos. Por defecto 32.
  final double size;

  const ServiceLogo({super.key, required this.logoUrl, this.size = 32});

  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostramos un icono de ajustes como representación genérica
    // de "servicio sin logo", sin intentar cargar nada de red.
    if (logoUrl == null || logoUrl!.isEmpty) {
      return Icon(
        Icons.settings_outlined,
        size: size,
        color: const Color(0xFF8B949E),
      );
    }
    return FadeInImage.assetNetwork(
      placeholder: 'assets/no_image.png',
      image: logoUrl!,
      width: size,
      height: size,
      // BoxFit.contain preserva las proporciones del logo, evitando distorsión
      // en logos con relación de aspecto no cuadrada (p. ej. logos horizontales).
      fit: BoxFit.contain,
      // Fallback al icono genérico de servicio ante cualquier error de carga.
      imageErrorBuilder: (context, error, _) => Icon(
        Icons.settings_outlined,
        size: size,
        color: const Color(0xFF8B949E),
      ),
    );
  }
}
