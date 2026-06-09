/// home_screen.dart
///
/// Propósito:
///   Pantalla principal de la aplicación, visible tras una autenticación exitosa.
///   Actúa como hub de navegación: muestra el saludo al usuario, la tarjeta de
///   sesión y las tiles de acceso rápido a las secciones autorizadas. También
///   contiene el drawer lateral ([_AppDrawer]) con la navegación global y el
///   cierre de sesión.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de inicio (screens/home/).
///
/// Clases definidas en este fichero:
///   - [HomeScreen]:       StatelessWidget raíz; hub de navegación y guarda de sesión.
///   - [_AppDrawer]:       Drawer lateral con navegación y acciones de sesión.
///   - [_DrawerItem]:      Item individual del drawer (privado).
///   - [_QuickAccessTile]: Tarjeta de acceso rápido en el cuerpo (privada).
///   - [_NoAccessCard]:    Aviso cuando el usuario no tiene permisos de servidor.
///
/// Guarda de sesión — `context.watch` + `addPostFrameCallback`:
///   [HomeScreen] observa [AuthProvider] con `context.watch`, lo que provoca un
///   rebuild automático cuando la sesión cambia (p. ej. invalidación por 401 o
///   logout explícito). Si tras el rebuild `session == null`, la pantalla debe
///   redirigir al login. Flutter prohíbe llamar a `Navigator` durante la fase de
///   `build`, por lo que la navegación se difiere con
///   `WidgetsBinding.instance.addPostFrameCallback`, que la ejecuta justo después
///   de que el frame se pinte. Se usa `pushNamedAndRemoveUntil` con el predicado
///   `(route) => false` para eliminar todo el stack de navegación: el usuario no
///   puede volver atrás al home después de ser desconectado.
///
/// Renderizado condicional por permisos:
///   Las tiles de acceso rápido y los ítems del drawer se muestran u ocultan según
///   [AuthProvider.canViewAnyServer] y [AuthProvider.canViewUserManagement].
///   - Si [canViewAnyServer] es `false`, las tiles de servidores y servicios se
///     sustituyen por [_NoAccessCard] (aviso naranja).
///   - Si [canViewUserManagement] es `false`, la tile de gestión de grupos no
///     aparece en el body ni en el drawer.
///
/// Flujo de logout:
///   Desde el drawer, el logout sigue este orden deliberado:
///   1. Cierra el drawer (`Navigator.pop`).
///   2. Invalida [ServidorProvider] (limpia la lista de servidores y paginación).
///   3. Invalida [GrupoProvider] (limpia grupos y catálogo de permisos).
///   4. Llama a `auth.logout()` (petición HTTP + limpia la sesión + notifica).
///   Los providers se invalidan ANTES de que `auth.logout()` notifique a los
///   listeners. Así, cuando [HomeScreen] recibe el rebuild con `session == null`,
///   los providers ya están en estado limpio.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas.
///   - Lógica de presentación de detalle (pertenece a DetalleServidorScreen, etc.).
///   - Comprobación de permisos específica de sección (pertenece a cada screen).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/home/home_user_card.dart';
import 'package:provider/provider.dart';

/// Pantalla principal del panel de monitorización.
///
/// Responsabilidad:
///   Servir de hub de navegación tras el login. Muestra el saludo personalizado,
///   la tarjeta de sesión del usuario ([HomeUserCard]) y las tiles de acceso
///   rápido filtradas por permisos del usuario autenticado.
///
/// Diseño — StatelessWidget con `context.watch`:
///   Aunque la pantalla no tiene estado propio, sí necesita reaccionar cuando
///   la sesión se invalida (401 o logout). Por eso usa `context.watch<AuthProvider>`
///   en lugar de `context.read`, de forma que un cambio en [AuthProvider] provoque
///   un rebuild y la guarda de sesión (`session == null`) pueda detectarlo y
///   redirigir al login.
///
/// Tile "Buscar servidor":
///   Navega a la misma ruta que "Listado de servidores" ([AppRoutes.listaServidores])
///   pero pasa `arguments: true` (booleano). Este argumento especial indica a
///   [ListaServidoresScreen] que debe abrir la pantalla con el campo de búsqueda
///   enfocado y activado, omitiendo la vista de lista normal.
///
/// Relación con otros módulos:
///   - [AuthProvider]:   fuente de la sesión activa y de los métodos de permiso.
///   - [HomeUserCard]:   tarjeta de resumen del usuario; recibe [Session] directamente.
///   - [AppRoutes]:      constantes de ruta para la navegación.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Obtiene la instancia de [AuthProvider] registrada en el árbol de widgets.
    ///
    /// Se utiliza [context.watch] en lugar de [context.read] porque esta pantalla
    /// necesita volver a construirse automáticamente cuando cambie el estado de
    /// autenticación.
    ///
    /// Esto es importante para detectar cambios de sesión mientras el usuario ya
    /// está dentro de la aplicación. Por ejemplo:
    ///
    /// - el usuario pulsa "cerrar sesión";
    /// - el token caduca;
    /// - una petición al backend devuelve un error 401;
    /// - el proveedor decide invalidar la sesión por cualquier otro motivo.
    ///
    /// Cada vez que [AuthProvider] notifique cambios, Flutter volverá a ejecutar
    /// este método [build]. Gracias a eso, la comprobación de [session] se hará
    /// de nuevo y la pantalla podrá reaccionar si la sesión ha pasado a ser
    /// `null`.
    final auth = context.watch<AuthProvider>();
    final session = auth.session;

    /// Guarda de sesión de la pantalla.
    ///
    /// Esta condición actúa como una protección de acceso. Su objetivo es evitar
    /// que un usuario sin sesión permanezca en una pantalla que requiere estar
    /// autenticado.
    ///
    /// La condición se cumple cuando [session] es `null`, lo que puede ocurrir
    /// por un cierre de sesión explícito o por una invalidación automática de la
    /// sesión.
    if (session == null) {
      /// Programa una acción para ejecutarse justo después de que Flutter termine
      /// de construir y pintar el frame actual.
      ///
      /// No se llama a [Navigator.pushNamedAndRemoveUntil] directamente aquí
      /// porque este código está dentro del método [build].
      ///
      /// El método [build] debe limitarse a describir qué interfaz se quiere
      /// mostrar en función del estado actual. Si durante esa construcción se
      /// intenta modificar la navegación, Flutter puede lanzar errores porque se
      /// estaría cambiando el árbol de widgets mientras todavía se está
      /// construyendo.
      ///
      /// [addPostFrameCallback] evita ese problema aplazando la navegación hasta
      /// el siguiente momento seguro: cuando el frame actual ya ha terminado.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        /// Comprueba que el [BuildContext] siga siendo válido antes de usarlo.
        ///
        /// Entre el momento en que se registra este callback y el momento en que
        /// se ejecuta, el widget podría haber sido eliminado del árbol. Por
        /// ejemplo, porque el usuario navegó a otra pantalla o porque Flutter
        /// reconstruyó una parte de la interfaz.
        ///
        /// Si [context.mounted] es `false`, significa que este [BuildContext] ya
        /// no pertenece a un widget montado. En ese caso no es seguro usarlo para
        /// navegar, mostrar diálogos, acceder a providers o realizar cualquier
        /// operación dependiente del contexto.
        ///
        /// Por eso se hace `return` y se cancela la navegación.
        if (!context.mounted) return;

        /// Redirige al usuario a la pantalla de login.
        ///
        /// Se utiliza [Navigator.pushNamedAndRemoveUntil] porque no basta con
        /// hacer una navegación normal al login. Si se usara únicamente
        /// `pushNamed`, la pantalla actual quedaría debajo en el stack de
        /// navegación y el usuario podría volver a ella pulsando "atrás".
        ///
        /// En una aplicación con autenticación, eso no sería deseable: una vez
        /// que la sesión deja de ser válida, el usuario no debería poder volver a
        /// pantallas privadas mediante el historial de navegación.
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,

          /// Predicado que decide qué rutas anteriores se conservan en el stack.
          ///
          /// [pushNamedAndRemoveUntil] recorre las rutas anteriores y mantiene
          /// solo aquellas para las que este predicado devuelve `true`.
          ///
          /// Como aquí siempre se devuelve `false`, no se conserva ninguna ruta
          /// anterior. Es decir, se elimina todo el historial de navegación y se
          /// deja únicamente la pantalla de login.
          ///
          /// Esto impide que el usuario pueda pulsar el botón de volver y acceder
          /// de nuevo a [HomeScreen] u otras pantallas protegidas después de haber
          /// perdido la sesión.
          (route) => false,
        );
      });

      /// Devuelve una pantalla vacía mientras se ejecuta la redirección.
      ///
      /// Aunque la sesión sea `null`, este método [build] debe devolver siempre
      /// un widget. Como la navegación se ha aplazado con [addPostFrameCallback],
      /// todavía hay un frame intermedio antes de que el usuario sea enviado al
      /// login.
      ///
      /// Durante ese frame no se debería mostrar el contenido real de
      /// [HomeScreen], porque el usuario ya no tiene una sesión válida.
      ///
      /// Por eso se devuelve un [Scaffold] con un [SizedBox.shrink], que ocupa el
      /// mínimo espacio posible y no muestra contenido visible.
      ///
      /// En la práctica, esta pantalla vacía suele mostrarse durante un instante
      /// imperceptible para el usuario, justo antes de la redirección.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              color: Color(0xFF1F6FEB),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Server Monitor',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      drawer: _AppDrawer(auth: auth),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo personalizado: solo el primer nombre del displayName completo.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(
                'Bienvenido, ${session.displayName.split(' ').first}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Panel de monitorización de servidores',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            // Tarjeta con el resumen de la sesión activa: nombre, rol, grupos.
            HomeUserCard(session: session),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Acceso rápido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ── Tiles de servidor (solo si el usuario tiene acceso) ──
                  if (auth.canViewAnyServer()) ...[
                    _QuickAccessTile(
                      icon: Icons.dns_outlined,
                      label: 'Listado de servidores',
                      subtitle: 'Ver todos los servidores monitorizados',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.listaServidores,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Argumento `true`: indica a ListaServidoresScreen que abra
                    // directamente con la barra de búsqueda enfocada y activa.
                    _QuickAccessTile(
                      icon: Icons.search,
                      label: 'Buscar servidor',
                      subtitle: 'Búsqueda por hostname, DNS o ID',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.listaServidores,
                        arguments: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _QuickAccessTile(
                      icon: Icons.settings_outlined,
                      label: 'Listado de servicios',
                      subtitle: 'Servicios monitorizados y sus servidores',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.listaServicios,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    // Usuario sin acceso a ninguna sección de servidores:
                    // se sustituyen las tiles por el aviso de sin permisos.
                    _NoAccessCard(),
                  // ── Tile de gestión (solo para administradores) ──────────
                  if (auth.canViewUserManagement()) ...[
                    _QuickAccessTile(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Gestión de grupos',
                      subtitle: 'Grupos, permisos y ámbitos',
                      // Verde: diferencia visualmente la sección de administración
                      // de las tiles de monitorización (azul).
                      color: const Color(0xFF3FB950),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.grupos),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Drawer lateral ─────────────────────────────────────────────────────────────

/// Drawer lateral de navegación global y gestión de sesión.
///
/// Responsabilidad:
///   Ofrecer acceso rápido a las mismas secciones que el cuerpo de [HomeScreen]
///   (también filtrado por permisos) y proporcionar las acciones de sesión:
///   cerrar sesión y salir de la aplicación.
///
/// Recepción de AuthProvider como parámetro:
///   Recibe [auth] directamente de [HomeScreen] en lugar de leerlo del contexto.
///   Esto evita crear una segunda suscripción a [AuthProvider] dentro del drawer
///   y centraliza la escucha en [HomeScreen], que ya lo observa con `context.watch`.
///
/// Flujo de logout:
///   La acción "Cerrar sesión" ejecuta tres operaciones en orden:
///   1. `Navigator.pop(context)`: cierra el drawer antes de any otra acción.
///      Si se omitiese, el drawer intentaría renderizarse sobre un contexto
///      en proceso de desmontaje.
///   2. `ServidorProvider.invalidate()` + `GrupoProvider.invalidate()`:
///      limpia el estado cacheado de ambos providers antes de que `auth.logout()`
///      notifique a los listeners. Así, si algún widget escucha esos providers,
///      no verá datos obsoletos de la sesión anterior.
///   3. `auth.logout()`: inicia el proceso de cierre de sesión (petición HTTP,
///      limpieza de token y notificación a listeners). Este es el paso que dispara
///      el rebuild de [HomeScreen] con `session == null`, que redirige al login.
///
/// `SystemNavigator.pop()`:
///   Envía la señal de "atrás" al sistema operativo, lo que cierra la app en
///   Android. En iOS esta llamada no tiene efecto (el SO no permite que las apps
///   se cierren programáticamente) y se comporta como un no-op.
class _AppDrawer extends StatelessWidget {
  /// Provider de autenticación, recibido desde [HomeScreen] para reutilizar
  /// su suscripción sin crear una nueva dentro del drawer.
  final AuthProvider auth;

  const _AppDrawer({required this.auth});

  @override
  Widget build(BuildContext context) {
    final session = auth.session;

    // Guard defensivo: si la sesión es null mientras el drawer está visible
    // (posible durante la transición de cierre de sesión), devuelve un drawer vacío.
    if (session == null) {
      return const Drawer(child: SafeArea(child: SizedBox.shrink()));
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Cabecera del drawer con identidad del usuario ──────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF0D1117),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.monitor_heart_outlined,
                    color: Color(0xFF1F6FEB),
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '@${session.username}',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF30363D)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  // ── Ítems de servidor (misma guarda de permisos que el body) ──
                  if (auth.canViewAnyServer()) ...[
                    _DrawerItem(
                      icon: Icons.dns_outlined,
                      label: 'Listado de servidores',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.listaServidores);
                      },
                    ),
                    // Argumento `true`: activa la búsqueda directa al abrir la pantalla.
                    _DrawerItem(
                      icon: Icons.search,
                      label: 'Buscar servidor',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          AppRoutes.listaServidores,
                          arguments: true,
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Listado de servicios',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.listaServicios);
                      },
                    ),
                  ],
                  if (auth.canViewUserManagement()) ...[
                    const Divider(color: Color(0xFF30363D)),
                    _DrawerItem(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Gestión de grupos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.grupos);
                      },
                    ),
                  ],
                  const Divider(color: Color(0xFF30363D)),
                  // ── Acciones de sesión ───────────────────────────────────
                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    color: Colors.redAccent,
                    onTap: () {
                      // Orden deliberado: primero cerrar el drawer, después
                      // limpiar los providers, por último disparar el logout.
                      // Ver comentario en la documentación de la clase.
                      Navigator.pop(context);
                      context.read<ServidorProvider>().invalidate();
                      context.read<GrupoProvider>().invalidate();
                      auth.logout();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.exit_to_app,
                    label: 'Salir de la aplicación',
                    color: Colors.redAccent,
                    // SystemNavigator.pop() cierra la app en Android.
                    // En iOS no tiene efecto (comportamiento no-op del SO).
                    onTap: () => SystemNavigator.pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ítem del drawer ────────────────────────────────────────────────────────────

/// Ítem individual del drawer lateral basado en [ListTile].
///
/// Responsabilidad:
///   Wrapper de presentación alrededor de [ListTile] con estilo homogéneo para
///   todos los ítems del drawer. Acepta un color opcional para diferenciar
///   acciones destructivas (cerrar sesión, salir) del resto.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Color del icono y del texto. Si no se proporciona, se usa blanco.
  /// Los ítems de acción destructiva usan [Colors.redAccent].
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 14)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Tile de acceso rápido ──────────────────────────────────────────────────────

/// Tarjeta de acceso rápido con icono, título, subtítulo y flecha de navegación.
///
/// Responsabilidad:
///   Presentar una acción de navegación de forma visual: icono con fondo
///   semitransparente del color indicado, label en blanco, subtítulo descriptivo
///   en gris y flecha derecha. Al pulsar, ejecuta el callback [onTap].
///
/// Color:
///   Controla el color del icono y el fondo del contenedor. Por defecto es azul
///   GitHub (`0xFF1F6FEB`), el color primario de la app. La tile "Gestión de grupos"
///   usa verde (`0xFF3FB950`) para diferenciar visualmente la sección de administración
///   de las tiles de monitorización.
///
/// El fondo del icono se renderiza con `withValues(alpha: 0.12)` del color base,
/// manteniendo la coherencia visual con el resto de iconos con fondo de la app.
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  /// Color del icono y del fondo semitransparente. Por defecto azul primario.
  final Color color;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.color = const Color(0xFF1F6FEB),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de sin acceso ──────────────────────────────────────────────────────

/// Aviso mostrado cuando el usuario no tiene permisos para ver ningún servidor.
///
/// Responsabilidad:
///   Sustituir las tiles de servidor en el cuerpo de [HomeScreen] cuando
///   [AuthProvider.canViewAnyServer] devuelve `false`. Informa al usuario de que
///   su cuenta no tiene permisos asignados para ninguna sección de servidores,
///   evitando que el cuerpo quede vacío sin explicación.
///
/// Solo se muestra en el cuerpo de [HomeScreen]; el drawer omite todos los
/// ítems de servidor sin mostrar aviso equivalente (el drawer puede quedar sin
/// ítems de navegación si el usuario tampoco tiene permisos de administración).
class _NoAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.orangeAccent),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No tienes permisos para ver servidores en ninguna sección.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
