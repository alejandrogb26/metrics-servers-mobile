/// models.dart
///
/// Propósito:
///   Barrel file (fichero de re-exportación) de toda la capa de modelos de
///   Metrics Manager. Actúa como punto de entrada único para que el resto de
///   capas (services, providers, screens) importen todos los modelos con un
///   solo import, sin necesidad de conocer la estructura interna del directorio.
///
/// Capa arquitectónica:
///   Índice de la capa de dominio / modelos (models/).
///
/// Uso:
///   ```dart
///   import 'package:metrics_servers_mobile/models/models.dart';
///   ```
///   Esta única línea da acceso a todos los modelos de la aplicación.
///
/// Modelos exportados y su responsabilidad:
///
///   Infraestructura transversal:
///   - [PagedResponse]      — Envoltura genérica para respuestas paginadas de api-py.
///
///   Autenticación y sesión:
///   - [LoginResponse]      — Respuesta del endpoint de login (token + sesión).
///   - [Session]            — Datos del usuario autenticado con métodos de acceso.
///   - [GrupoSession]       — Snapshot ligero del grupo del usuario en sesión.
///   - [PermissionMap]      — Mapa de permisos en forma de claves compuestas string.
///
///   Entidades de dominio:
///   - [Servidor]           — Servidor físico o virtual gestionado por la plataforma.
///   - [Servicio]           — Servicio o tecnología instalable en un servidor.
///   - [Seccion]            — Módulo o área de la aplicación (catálogo de secciones).
///   - [Grupo]              — Grupo de usuarios con mapa de permisos para administración.
///   - [GrupoPermissionMap] — Permisos de un grupo administrado como listas de IDs.
///   - [Permiso]            — Permiso individual del catálogo de autorización.
///   - [Ambito]             — Categoría funcional de un permiso.
///
///   Métricas en tiempo real:
///   - [MetricPoint]        — Punto de métrica completo (un instante de tiempo).
///   - [SystemMetrics]      — Métricas del SO: CPU, RAM, swap, disco, red.
///   - [ServiceMetrics]     — Métricas de servicios: Apache2, MariaDB, SSH.
///   - (y clases auxiliares de model_metrics.dart)
///
/// Qué NO debe contener este fichero:
///   - Ninguna definición de clase, función o constante propia.
///   - Imports de paquetes externos.
///   - Lógica de ningún tipo.
library;

export 'model_paged_response.dart';
export 'model_session.dart';
export 'model_servidor.dart';
export 'model_servicio.dart';
export 'model_seccion.dart';
export 'model_grupo.dart';
export 'model_permiso.dart';
export 'metrics/model_metrics.dart';
