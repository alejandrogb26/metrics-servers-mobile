/// main.dart
///
/// Propósito:
///   Punto de entrada de la aplicación Flutter. Arranca el árbol de widgets
///   pasando a [runApp] el widget raíz [Providers], que encapsula la
///   configuración del estado global y la navegación de toda la app.
///
/// Capa arquitectónica:
///   Capa de arranque. Es el único fichero que llama a [runApp]; el resto de
///   la inicialización (providers, rutas, tema) se delega a [Providers] y a
///   la clase de aplicación que [Providers] envuelve.
///
/// Diseño intencionado:
///   `main` no contiene ninguna lógica de inicialización propia. La decisión
///   de mantenerlo mínimo simplifica los tests de integración y facilita
///   sustituir el widget raíz sin modificar el punto de entrada.
///   No se llama a [WidgetsFlutterBinding.ensureInitialized] porque no hay
///   canales de plataforma ni plugins que requieran el binding antes de [runApp].
///
/// Qué NO debe contener este fichero:
///   - Configuración de providers, rutas o tema (pertenece a [Providers] y a
///     la clase de aplicación).
///   - Inicialización de servicios (pertenece a los constructores de providers
///     o a llamadas diferidas dentro del árbol de widgets).
///   - Lógica de negocio de ningún tipo.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/providers/providers.dart';

/// Punto de entrada de la aplicación.
///
/// Construye [Providers] como `const` (sin parámetros de configuración en
/// tiempo de ejecución) y lo entrega a [runApp], que lo monta como raíz del
/// árbol de widgets e inicia el bucle de renderizado de Flutter.
void main() {
  runApp(const Providers());
}
