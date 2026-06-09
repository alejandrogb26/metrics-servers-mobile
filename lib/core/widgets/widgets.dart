/// widgets.dart
///
/// Propósito:
///   Barrel file (fichero de re-exportación) del paquete de widgets compartidos
///   de Metrics Manager. Actúa como punto de entrada único para todos los widgets
///   comunes de la aplicación, de forma que el resto de capas solo necesitan
///   importar este fichero y no conocer la estructura interna del directorio.
///
/// Capa arquitectónica:
///   Capa de presentación — índice de widgets compartidos (core/widgets/).
///
/// Uso:
///   En lugar de importar `shared_widgets.dart` directamente, cualquier pantalla
///   o widget de la app debe importar este barrel:
///
///   ```dart
///   import 'package:app_mobil/core/widgets/widgets.dart';
///   ```
///
///   Esto desacopla al consumidor de la organización interna del directorio:
///   si en el futuro se divide `shared_widgets.dart` en varios ficheros temáticos,
///   basta con añadir los nuevos exports aquí sin tocar los imports de los
///   consumidores.
///
/// Qué NO debe contener este fichero:
///   - Ninguna definición de clase, función o constante propia.
///   - Imports de paquetes externos (solo re-exports de ficheros internos).
///   - Lógica de ningún tipo.
library;

export 'shared_widgets.dart';
