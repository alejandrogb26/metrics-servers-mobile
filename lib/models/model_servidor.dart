/// model_servidor.dart
///
/// Propósito:
///   Define [Servidor], el modelo de dominio central de Metrics Manager.
///   Representa un servidor físico o virtual gestionado por la plataforma,
///   con su identidad, información de sistema operativo, imagen de presentación,
///   sección a la que pertenece y lista de servicios instalados.
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   PODO puro: no depende de Flutter, no contiene lógica de presentación
///   y no realiza llamadas HTTP. Es deserializado por el servicio de servidores
///   y consumido por los providers y todas las pantallas que operan con
///   servidores (listado, detalle, métricas).
///
/// Identidad del servidor — dos identificadores:
///   [Servidor] expone dos identificadores distintos con propósitos diferentes:
///
///   - [id] (int): clave primaria numérica en la base de datos de api-py.
///     Se usa en rutas HTTP (p. ej. `/servers/{id}/metrics`).
///   - [serverId] (String): identificador de aplicación, posiblemente un UUID
///     o slug único. Puede ser el identificador con el que el agente de
///     monitorización se registra en api-py.
///
/// Direccionamiento de red — dos campos de red:
///   - [dns]: dirección usada para conectar al servidor (nombre DNS o IP).
///   - [hostname]: hostname que el propio servidor reporta (salida de `hostname`).
///   Pueden diferir si el servidor está detrás de un proxy inverso, tiene un
///   alias DNS distinto de su hostname interno, o si se accede por IP.
///
/// Relaciones por ID (claves foráneas):
///   [Servidor] no embebe los objetos relacionados, sino que almacena sus IDs:
///
///   - [seccion] (int): ID de la [Seccion] a la que pertenece el servidor.
///     Para mostrar el nombre de la sección, el provider debe resolver este ID
///     contra el catálogo de secciones. Clave JSON: `"seccionId"`.
///   - [servicios] (`List<int>`): IDs de los [Servicio]s instalados en el servidor.
///     Para mostrar nombres y logos, el provider debe resolver contra el catálogo
///     de servicios. Los IDs corresponden a [Servicio.id] de model_servicio.dart.
///
/// Imagen del servidor — dos campos de imagen:
///   - [imagen]: nombre o identificador de la imagen (no es una URL directa).
///   - [imagenUrl]: URL completa a la imagen del servidor. Es el campo que
///     consume el widget [ServerImage] de `shared_widgets.dart`.
///
/// Claves JSON — excepciones al estilo de api-py:
///   Varios campos usan camelCase en el JSON, a diferencia del snake_case habitual:
///   `serverId`, `prettyOs`, `imagenUrl`, `seccionId`. Deben mantenerse exactamente
///   así en los accesos a JSON para no romper la deserialización.
///
/// Qué NO debe contener este fichero:
///   - Métricas en tiempo real del servidor (pertenecen a model_metrics.dart).
///   - Lógica de formateo (bytes → GB, uptime → días, etc.).
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de estado (online/offline); eso se deriva de las métricas.
library;

/// Servidor físico o virtual gestionado por Metrics Manager.
///
/// Responsabilidad:
///   Encapsula la información de identidad y configuración estática de un servidor
///   tal como la almacena api-py: identificadores, direccionamiento de red, datos
///   del sistema operativo, imagen de presentación, sección y servicios instalados.
///
/// Datos estáticos vs. dinámicos:
///   Este modelo contiene datos que cambian con poca frecuencia (configuración del
///   servidor). Los datos que cambian constantemente (uso de CPU, RAM, disco…) son
///   responsabilidad de [MetricPoint] en model_metrics.dart y se obtienen mediante
///   un endpoint diferente de api-py.
///
/// Relación con otros módulos:
///   - `ServidorService` / repositorio HTTP: obtiene y deserializa instancias de
///     [Servidor] desde api-py (listado paginado y detalle individual).
///   - Provider de servidores: expone la lista paginada de [Servidor] a la UI.
///   - Pantalla de listado de servidores: muestra [hostname], [imagenUrl] y estado.
///   - Pantalla de detalle de servidor: muestra todos los campos del modelo.
///   - [ServerImage] (shared_widgets.dart): consume [imagenUrl] para la miniatura.
///   - Provider de métricas: usa [id] para construir la URL del endpoint de métricas.
class Servidor {
  /// Clave primaria numérica del servidor en la base de datos de api-py.
  /// Se usa en las rutas HTTP para operaciones sobre el servidor concreto.
  /// Fallback a `0` si ausente (valor centinela; no debería ocurrir en producción).
  final int id;

  /// Identificador de aplicación del servidor, único como string.
  /// Puede ser un UUID o un slug asignado en el registro del agente de
  /// monitorización. Clave JSON: `"serverId"` (camelCase).
  /// Fallback a cadena vacía si ausente.
  final String serverId;

  /// Dirección DNS o IP usada para conectar al servidor externamente.
  /// Puede ser un nombre de dominio completo (FQDN) o una dirección IP.
  /// Fallback a cadena vacía si ausente.
  final String dns;

  /// Hostname que el propio servidor reporta internamente.
  /// Equivale a la salida del comando `hostname` en el servidor.
  /// Puede diferir de [dns] si el servidor tiene un alias externo distinto.
  /// Fallback a cadena vacía si ausente.
  final String hostname;

  /// Descripción legible del sistema operativo instalado.
  /// Proviene del campo `PRETTY_NAME` de `/etc/os-release` en Linux
  /// (p. ej. "Ubuntu 22.04.3 LTS", "Debian GNU/Linux 12 (bookworm)").
  /// Puede ser `null` si el agente no pudo leerlo o el SO no lo expone.
  /// Clave JSON: `"prettyOs"` (camelCase).
  final String? prettyOs;

  /// Arquitectura del procesador del servidor (p. ej. "x86_64", "aarch64").
  /// Puede ser `null` si el agente no pudo determinarlo.
  final String? arch;

  /// Versión del kernel del sistema operativo (p. ej. "6.1.0-18-amd64").
  /// Puede ser `null` si el agente no pudo leerlo.
  final String? kernel;

  /// Nombre o identificador interno de la imagen del servidor.
  /// No es una URL directa; representa el nombre del recurso de imagen en
  /// el sistema de almacenamiento de api-py. Ver [imagenUrl] para la URL
  /// completa de presentación.
  final String? imagen;

  /// URL absoluta a la imagen del servidor para mostrar en la UI.
  /// Consumida directamente por el widget [ServerImage] de `shared_widgets.dart`,
  /// que maneja la carga asíncrona y el fallback ante URLs nulas o rotas.
  /// Clave JSON: `"imagenUrl"` (camelCase).
  final String? imagenUrl;

  /// ID de la [Seccion] a la que pertenece este servidor.
  /// Es una clave foránea: para mostrar el nombre de la sección, el provider
  /// debe resolver este ID contra el catálogo de secciones de api-py.
  /// Clave JSON: `"seccionId"` — distinta del nombre del campo Dart (`seccion`).
  /// Fallback a `0` si ausente.
  final int seccion;

  /// Lista de IDs de los [Servicio]s instalados en este servidor.
  /// Son claves foráneas que referencian [Servicio.id] del catálogo de servicios.
  /// Para mostrar nombres y logos, el provider debe resolver estos IDs contra
  /// el catálogo. Nunca es `null`; puede ser una lista vacía si el servidor
  /// no tiene servicios configurados en api-py.
  final List<int> servicios;

  const Servidor({
    required this.id,
    required this.serverId,
    required this.dns,
    required this.hostname,
    this.prettyOs,
    this.arch,
    this.kernel,
    this.imagen,
    this.imagenUrl,
    required this.seccion,
    required this.servicios,
  });

  /// Deserializa desde el JSON de un servidor devuelto por api-py.
  ///
  /// Claves JSON esperadas (todas camelCase salvo `dns`, `hostname`, `arch`,
  /// `kernel` e `imagen`):
  ///   - `id`        (int?)         → [id]        (fallback: `0`)
  ///   - `serverId`  (String?)      → [serverId]  (fallback: `''`)
  ///   - `dns`       (String?)      → [dns]        (fallback: `''`)
  ///   - `hostname`  (String?)      → [hostname]   (fallback: `''`)
  ///   - `prettyOs`  (String?)      → [prettyOs]  (puede ser `null`)
  ///   - `arch`      (String?)      → [arch]       (puede ser `null`)
  ///   - `kernel`    (String?)      → [kernel]     (puede ser `null`)
  ///   - `imagen`    (String?)      → [imagen]     (puede ser `null`)
  ///   - `imagenUrl` (String?)      → [imagenUrl] (puede ser `null`)
  ///   - `seccionId` (int?)         → [seccion]   (fallback: `0`; nota: la clave
  ///                                               JSON lleva el sufijo "Id")
  ///   - `servicios` (`List<int>`?) → [servicios] (fallback: `[]`)
  factory Servidor.fromJson(Map<String, dynamic> json) {
    return Servidor(
      id: json['id'] as int? ?? 0,
      serverId: json['serverId'] as String? ?? '',
      dns: json['dns'] as String? ?? '',
      hostname: json['hostname'] as String? ?? '',
      prettyOs: json['prettyOs'] as String?,
      arch: json['arch'] as String?,
      kernel: json['kernel'] as String?,
      imagen: json['imagen'] as String?,
      imagenUrl: json['imagenUrl'] as String?,
      // La clave JSON es 'seccionId', no 'seccion'. El campo Dart omite el
      // sufijo 'Id' por convención de nomenclatura del modelo.
      seccion: json['seccionId'] as int? ?? 0,
      servicios:
          (json['servicios'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}
