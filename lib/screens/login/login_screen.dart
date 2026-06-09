/// login_screen.dart
///
/// Propósito:
///   Pantalla de autenticación de la aplicación. Presenta el formulario de login
///   con campos de usuario y contraseña, valida las entradas localmente y delega
///   la autenticación a [AuthProvider.login]. Es la ruta inicial de la app
///   (ver [AppRoutes.login] y [MonitoringApp.initialRoute]).
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de login (screens/login/).
///
/// Clases definidas en este fichero:
///   - [LoginScreen]:      StatefulWidget raíz de la pantalla de login.
///   - [_LoginScreenState]: estado del formulario, controllers y lógica de submit.
///   - [_Logo]:            Widget decorativo del logo de la app.
///
/// Flujo de autenticación:
///   1. El usuario rellena usuario y contraseña y pulsa "Iniciar sesión" (o
///      envía con la tecla de teclado en el campo de contraseña).
///   2. [_submit] valida el formulario. Si algún campo está vacío, muestra el
///      mensaje de validación y no hace ninguna petición HTTP.
///   3. Si la validación pasa, llama a [AuthProvider.login] (que realiza la
///      petición HTTP y actualiza [AuthStatus]).
///   4. Durante la espera, [AuthStatus.loading] deshabilita el botón y muestra
///      un [CircularProgressIndicator] en su lugar.
///   5a. Si login es exitoso (`ok == true`), navega a [AppRoutes.home] con
///       [Navigator.pushReplacementNamed], eliminando la ruta de login del stack.
///   5b. Si login falla, [AuthProvider] establece [AuthStatus.error] y
///       [AuthProvider.errorMessage]. El [context.watch] de build detecta el
///       cambio y muestra el aviso de error en rojo.
///
/// Diseño — StatefulWidget:
///   Se usa [StatefulWidget] porque la pantalla necesita mantener estado local:
///   - [_formKey]: [GlobalKey] para la validación del [Form].
///   - [_userCtrl] / [_passCtrl]: [TextEditingController] que requieren [dispose].
///   - [_obscure]: booleano para mostrar/ocultar la contraseña (toggle del campo).
///
/// Doble uso de AuthProvider (read vs. watch):
///   - `context.watch` en [build]: para reconstruir la UI cuando [AuthStatus]
///     cambia (loading → spinner, error → aviso rojo).
///   - `context.read` en [_submit]: para llamar a `login()` sin crear una
///     suscripción innecesaria dentro de un método asíncrono.
///
/// Qué NO debe contener este fichero:
///   - Lógica HTTP directa (pertenece a AuthService / AuthProvider).
///   - Gestión de sesión tras el login (pertenece a AuthProvider).
///   - Navegación posterior al home (salvo la redirección inmediata tras login).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:provider/provider.dart';

/// Pantalla de autenticación con formulario de usuario y contraseña.
///
/// Responsabilidad:
///   Recoger las credenciales del usuario, validarlas localmente y delegar la
///   autenticación a [AuthProvider]. Gestiona los estados visuales de carga y
///   error reactivamente a través del provider.
///
/// Ciclo de vida del estado:
///   - [initState]: implícito; los controllers se inicializan al declararlos.
///   - [dispose]: libera [_userCtrl] y [_passCtrl] para evitar memory leaks.
///     Si no se llama a [dispose], los controllers continúan escuchando cambios
///     aunque el widget ya no exista en el árbol.
///   - [build]: usa `context.watch<AuthProvider>()` para reconstruir el botón
///     (spinner vs. texto) y el aviso de error ante cada cambio de [AuthStatus].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Clave del formulario para acceder a su estado y disparar la validación.
  final _formKey = GlobalKey<FormState>();

  /// Controlador del campo de usuario. Se dispone en [dispose].
  final _userCtrl = TextEditingController();

  /// Controlador del campo de contraseña. Se dispone en [dispose].
  final _passCtrl = TextEditingController();

  /// `true` cuando la contraseña está oculta (***). Cambia con el botón del ojo.
  bool _obscure = true;

  @override
  void dispose() {
    // Liberar los controllers al destruir el widget evita que continúen
    // escuchando cambios de texto en segundo plano.
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Valida el formulario y, si es correcto, inicia el proceso de autenticación.
  ///
  /// Validación local:
  ///   [Form.validate] activa los validadores de cada campo. Si alguno falla,
  ///   muestra el mensaje de error bajo el campo y retorna sin hacer peticiones.
  ///
  /// Trim selectivo:
  ///   El username se pasa con `.trim()` para descartar espacios accidentales.
  ///   La contraseña NO se recorta: los espacios al inicio/final pueden ser
  ///   intencionales y forman parte del secreto.
  ///
  /// Guard `mounted`:
  ///   `login()` es asíncrono; el widget podría desmontarse mientras espera la
  ///   respuesta HTTP (p. ej. el usuario pulsa atrás). Se comprueba `mounted`
  ///   antes de usar el contexto en la navegación para evitar llamar a
  ///   `Navigator` sobre un contexto ya destruido.
  ///
  /// Navegación tras login exitoso:
  ///   [Navigator.pushReplacementNamed] sustituye la ruta de login por [AppRoutes.home].
  ///   Así, si el usuario pulsa "atrás" desde [HomeScreen], sale de la app en
  ///   lugar de volver al formulario de login.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // context.read: no necesita suscripción; solo invoca el método login().
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch: reconstruye el widget cuando AuthStatus cambia, lo que
    // actualiza el estado del botón (habilitado/spinner) y el aviso de error.
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Logo ──────────────────────────────────────────────────
                _Logo(),
                const SizedBox(height: 48),

                // ── Título ────────────────────────────────────────────────
                const Text(
                  'Server Monitor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accede con tus credenciales corporativas',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                ),
                const SizedBox(height: 40),

                // ── Formulario ────────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Campo de usuario: TextInputAction.next mueve el foco
                      // al siguiente campo al pulsar "siguiente" en el teclado.
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        // El trim() en el validador rechaza cadenas de solo espacios.
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // Campo de contraseña: puede mostrarse/ocultarse con el
                      // botón del ojo. TextInputAction.done + onFieldSubmitted
                      // permiten enviar el formulario directamente desde el teclado.
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          // Botón de toggle de visibilidad: alterna el icono
                          // y llama a setState para actualizar obscureText.
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        // Envía el formulario al pulsar "listo" en el teclado,
                        // equivalente a pulsar el botón "Iniciar sesión".
                        onFieldSubmitted: (_) => _submit(),
                        // La contraseña no usa trim() en el validador: los espacios
                        // al inicio/final son parte válida del secreto.
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // ── Aviso de error ────────────────────────────────────
                      // Solo se muestra cuando AuthProvider indica error.
                      // El mensaje proviene de auth.errorMessage, que establece
                      // AuthProvider.login() al recibir una respuesta de error.
                      if (auth.status == AuthStatus.error &&
                          auth.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // ── Botón de submit ────────────────────────────────────
                      // onPressed == null cuando isLoading: deshabilita el botón
                      // visualmente y evita envíos duplicados mientras se espera
                      // la respuesta HTTP.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Iniciar sesión'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Crédito del proyecto.
                const Text(
                  'PFC Metrics Servers - Alejandro Gómez Blanco',
                  style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────────────────────

/// Widget decorativo del logo de la aplicación en la pantalla de login.
///
/// Responsabilidad:
///   Mostrar el icono de la app ([Icons.monitor_heart_outlined]) en un contenedor
///   cuadrado redondeado con borde gris y halo azul difuminado. Es puramente
///   visual; no tiene comportamiento interactivo.
///
/// Diseño:
///   - Fondo `0xFF161B22` (nivel 2 de la paleta GitHub Dark).
///   - Borde `0xFF30363D` de 1.5 px.
///   - [BoxShadow] con color primario azul al 30% de opacidad y blurRadius 24:
///     crea el efecto de halo azul que destaca el logo sobre el fondo oscuro.
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF30363D), width: 1.5),
        boxShadow: [
          BoxShadow(
            // Halo azul: mismo color primario de la app con baja opacidad.
            color: const Color(0xFF1F6FEB).withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.monitor_heart_outlined,
        size: 52,
        color: Color(0xFF1F6FEB),
      ),
    );
  }
}
