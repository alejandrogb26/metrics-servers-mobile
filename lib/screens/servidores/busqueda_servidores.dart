/// busqueda_servidores.dart
///
/// Propósito:
///   Implementa la búsqueda de servidores mediante el framework estándar de
///   Flutter [SearchDelegate]. Permite al usuario buscar por hostname, DNS o
///   Server ID sobre los servidores ya cargados en [ServidorProvider], mostrando
///   resultados en tiempo real según se escribe.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de servidores (screens/servidores/).
///
/// Clases definidas en este fichero:
///   - [ServidorSearchDelegate]: delegate de búsqueda; extiende
///     `SearchDelegate<Servidor?>`.
///
/// Integración con SearchDelegate:
///   Flutter expone la búsqueda mediante `showSearch(context, delegate)`. Al
///   llamarse, Flutter superpone un [AppBar] con campo de texto y delega el
///   renderizado de acciones, botón atrás y resultados a los métodos del delegate.
///   El tipo genérico `Servidor?` indica que `close(context, value)` puede
///   devolver un [Servidor] seleccionado o `null` si el usuario cierra sin elegir.
///
/// Flujo de búsqueda:
///   1. El usuario escribe en el campo → [buildSuggestions] se llama en cada
///      cambio de `query`. Delega a [_buildList], que invoca
///      [ServidorProvider.search] con la query recortada.
///   2. El usuario pulsa "buscar" en el teclado → [buildResults] se llama.
///      También delega a [_buildList], por lo que el comportamiento es idéntico.
///   3. El usuario toca un resultado → `close(context, servidor)` cierra el
///      overlay de búsqueda y se navega a [AppRoutes.detalleServidor].
///   4. El usuario pulsa atrás → `close(context, null)` cierra sin selección.
///
/// Limitación de búsqueda client-side:
///   [ServidorProvider.search] filtra únicamente los servidores ya cargados en
///   memoria. Si se han cargado 20 de 150 servidores, la búsqueda no cubre el
///   conjunto completo. No hay endpoint de búsqueda server-side actualmente.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas.
///   - Lógica de paginación (pertenece a [ServidorProvider]).
///   - Widgets reutilizables fuera del contexto de búsqueda.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';

/// Delegate de búsqueda de servidores para el sistema [SearchDelegate] de Flutter.
///
/// Responsabilidad:
///   Gestionar la UI de búsqueda (campo de texto, botón de limpiar, botón de
///   atrás) y mostrar los resultados de [ServidorProvider.search] en tiempo real.
///
/// Recibe [ServidorProvider] como dependencia explícita en el constructor.
/// El delegate no accede al árbol de providers mediante contexto porque
/// [SearchDelegate] no garantiza un [BuildContext] con acceso al árbol de
/// la aplicación principal en todos sus métodos.
///
/// Tipo de retorno `Servidor?`:
///   `close(context, s)` devuelve el [Servidor] seleccionado al llamador de
///   `showSearch`. En esta implementación el valor de retorno no se usa (la
///   navegación se hace directamente en `onTap`), pero el tipo documenta la
///   intención del delegate.
class ServidorSearchDelegate extends SearchDelegate<Servidor?> {
  /// Provider del que se obtiene [ServidorProvider.search] para la búsqueda.
  final ServidorProvider servidorProvider;

  ServidorSearchDelegate({required this.servidorProvider})
    // Placeholder del campo de búsqueda mostrado cuando no hay texto.
    : super(searchFieldLabel: 'Buscar por hostname, DNS o ID…');

  /// Personaliza el tema del AppBar de búsqueda para coincidir con GitHub Dark.
  ///
  /// Sin este override, Flutter usaría el tema global del AppBar, que podría
  /// tener colores distintos al fondo `0xFF161B22` del resto de la app.
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Color(0xFF8B949E)),
      ),
    );
  }

  /// Acciones del AppBar de búsqueda (zona derecha).
  ///
  /// Muestra el botón de limpiar (×) solo cuando hay texto en el campo.
  /// Asignar `query = ''` limpia el campo y dispara [buildSuggestions] con
  /// una query vacía, volviendo al estado de prompt inicial.
  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  /// Botón de retroceso del AppBar de búsqueda (zona izquierda).
  ///
  /// Cierra el overlay de búsqueda devolviendo `null` al llamador, indicando
  /// que el usuario no seleccionó ningún servidor.
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  /// Resultados al confirmar la búsqueda (tecla "buscar" del teclado).
  ///
  /// Delega a [_buildList]: el comportamiento es idéntico a [buildSuggestions]
  /// para ofrecer una experiencia de búsqueda en tiempo real sin distinción
  /// entre sugerencias y resultados confirmados.
  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  /// Sugerencias en tiempo real mientras el usuario escribe.
  ///
  /// Delega a [_buildList], lo que significa que los resultados se actualizan
  /// con cada pulsación de tecla sin necesidad de confirmar la búsqueda.
  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  /// Construye la lista de resultados o el estado de prompt/vacío según `query`.
  ///
  /// Tres estados posibles:
  /// 1. Query vacía o solo espacios: muestra prompt "Escribe para buscar".
  /// 2. Query con texto pero sin resultados: muestra estado vacío con el texto.
  /// 3. Query con resultados: muestra [ListView.builder] con un [ListTile] por servidor.
  ///
  /// Al pulsar un resultado:
  ///   - `close(context, s)`: cierra el overlay de búsqueda. Necesario para que
  ///     al volver de la pantalla de detalle no quede el overlay abierto.
  ///   - `Navigator.pushNamed(AppRoutes.detalleServidor, arguments: s)`: navega
  ///     al detalle del servidor seleccionado.
  Widget _buildList(BuildContext context) {
    if (query.trim().isEmpty) {
      return const EmptyStateWidget(
        message: 'Escribe para buscar servidores',
        icon: Icons.search,
      );
    }
    // Búsqueda client-side: solo cubre los servidores cargados en memoria.
    final results = servidorProvider.search(query.trim());
    if (results.isEmpty) {
      return EmptyStateWidget(
        message: 'No se encontraron resultados para "$query"',
        icon: Icons.dns_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final s = results[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ServerImage(imageUrl: s.imagenUrl, width: 44, height: 44),
          ),
          title: Text(
            s.hostname,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            s.dns,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
          onTap: () {
            // close antes de pushNamed: evita que el overlay de búsqueda quede
            // activo en el stack cuando el usuario vuelve del detalle.
            close(context, s);
            Navigator.pushNamed(
              context,
              AppRoutes.detalleServidor,
              arguments: s,
            );
          },
        );
      },
    );
  }
}
