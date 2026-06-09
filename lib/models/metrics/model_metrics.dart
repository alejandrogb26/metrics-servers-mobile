/// model_metrics.dart
///
/// Propósito:
///   Define la jerarquía completa de modelos de datos para las métricas de
///   servidor recibidas desde api-py. Cada clase representa un fragmento del
///   payload JSON del endpoint de métricas y es responsable de su propia
///   deserialización mediante el patrón `factory fromJson`.
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/metrics/).
///   Estos modelos son Plain Old Dart Objects (PODO): no contienen lógica de
///   negocio, no conocen la UI y no dependen de Flutter. Son consumidos por
///   los providers de métricas, que los obtienen a través del servicio HTTP
///   correspondiente y los expeen a las pantallas de visualización.
///
/// Estructura jerárquica del modelo:
///
///   MetricPoint                   ← Punto de métrica completo (un instante)
///   ├── HostMetrics               ← Información del host (uptime)
///   ├── SystemMetrics             ← Métricas del sistema operativo
///   │   ├── CpuMetrics            ← CPU: uso, núcleos, carga media
///   │   ├── MemMetrics            ← RAM: usada, total, porcentaje
///   │   ├── SwapMetrics           ← Swap: presencia, usada, total, porcentaje
///   │   ├── `List<DiskMetrics>`   ← Discos: montaje, tipo, uso por partición
///   │   └── NetworkMetrics        ← Red: bytes recibidos y transmitidos totales
///   └── ServiceMetrics            ← Métricas de servicios monitorizados
///       ├── ApacheMetrics         ← Apache2: workers, conexiones, tasa de req.
///       │   ├── ApacheWorkers     ← Workers activos e inactivos
///       │   └── ApacheConnections ← Conexiones totales y async keepalive
///       ├── MariaDbMetrics        ← MariaDB: hilos, consultas, uptime
///       │   ├── MariaDbThreads    ← Hilos conectados y en ejecución
///       │   └── MariaDbQueries    ← Consultas totales y lentas
///       └── SshMetrics            ← SSH: estado systemd, puerto, sesiones
///           └── SshListen         ← Puerto y disponibilidad del puerto SSH
///
/// Compatibilidad con api-py:
///   Los nombres de campo JSON siguen el estilo snake_case del backend Python.
///   Los campos Dart usan camelCase según las convenciones de Dart/Flutter.
///   El mapeo exacto de claves se documenta en cada `fromJson`.
///
/// Decisiones de diseño transversales:
///
///   1. Todos los campos son nullable (`?`) salvo `loadAvg` y `disks` (listas
///      con fallback a `[]`). Esto es intencional: el agente de monitorización
///      de api-py puede no disponer de todos los datos en cada ciclo de recogida
///      (servicio caído, permisos insuficientes, subsistema no disponible). Un
///      campo `null` significa "dato no disponible", distinto de "cero".
///
///   2. Los modelos son completamente inmutables: constructores `const`,
///      todos los campos `final`. Esto es seguro para usar en providers de
///      Riverpod/ChangeNotifier sin riesgo de mutación accidental.
///
///   3. El patrón `(json['x'] as num?)?.toDouble()` se usa en todos los campos
///      numéricos decimales. Es necesario porque la API puede devolver enteros
///      (p. ej. `0`) donde semánticamente se espera un `double` (p. ej. `0.0`);
///      un cast directo `as double?` fallaría con un `int` JSON.
///
/// Qué NO debe contener este fichero:
///   - Lógica de formateo de valores (eso pertenece a helpers de UI o widgets).
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de presentación (colores según umbrales, textos localizados, etc.).
///   - Transformaciones de unidades (p. ej. bytes → GB); eso va en la capa UI.
library;

// ── Host ──────────────────────────────────────────────────────────────────────

/// Métricas básicas del host físico o virtual.
///
/// Actualmente solo expone el tiempo de actividad del sistema en segundos.
/// Es el nivel más alto de abstracción del hardware; se recibe dentro de
/// [MetricPoint] bajo la clave `"host"` del JSON de api-py.
class HostMetrics {
  /// Segundos que lleva el sistema en funcionamiento desde el último arranque.
  /// Equivale a la salida de `/proc/uptime` en Linux.
  /// Puede ser `null` si el agente no pudo leer el valor.
  final int? uptimeSeconds;

  const HostMetrics({this.uptimeSeconds});

  /// Deserializa desde el objeto JSON `host` del payload de métricas.
  ///
  /// Clave JSON esperada:
  ///   - `uptime_s` (int?) → [uptimeSeconds]
  factory HostMetrics.fromJson(Map<String, dynamic> json) {
    return HostMetrics(uptimeSeconds: json['uptime_s'] as int?);
  }
}

// ── System ────────────────────────────────────────────────────────────────────

/// Métricas de uso del procesador.
///
/// Contiene el porcentaje de uso global, el número de núcleos lógicos y la
/// carga media del sistema en los últimos 1, 5 y 15 minutos (equivalente a
/// `getloadavg()` en POSIX). Se recibe bajo la clave `"cpu"` dentro de
/// `"metrics"` en el JSON de api-py.
class CpuMetrics {
  /// Porcentaje de uso de CPU (0.0–100.0). Puede ser `null` si no disponible.
  final double? percent;

  /// Número de núcleos lógicos del procesador. Puede ser `null`.
  final int? cores;

  /// Carga media del sistema: lista de tres valores correspondientes a los
  /// promedios de 1, 5 y 15 minutos. Nunca es `null`; si la API no devuelve
  /// el campo, se usa una lista vacía como valor por defecto seguro.
  final List<double> loadAvg;

  const CpuMetrics({this.percent, this.cores, required this.loadAvg});

  /// Deserializa desde el objeto JSON `cpu`.
  ///
  /// Claves JSON esperadas:
  ///   - `percent`  (num?)          → [percent]  (cast seguro a double)
  ///   - `cores`    (int?)          → [cores]
  ///   - `loadavg`  (`List<num>`?)   → [loadAvg]  (cada elemento a double)
  factory CpuMetrics.fromJson(Map<String, dynamic> json) {
    return CpuMetrics(
      percent: (json['percent'] as num?)?.toDouble(),
      cores: json['cores'] as int?,
      // Cada elemento puede llegar como int o double desde Python; se normaliza
      // a double para uniformidad en la capa de presentación.
      loadAvg:
          (json['loadavg'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

/// Métricas de uso de memoria RAM.
///
/// Expone los bytes usados, el total disponible y el porcentaje de uso.
/// Los valores en bytes permiten a la UI formatear en la unidad más adecuada
/// (KB, MB, GB) sin que el modelo asuma una escala concreta.
/// Se recibe bajo la clave `"mem"` dentro de `"metrics"`.
class MemMetrics {
  /// Bytes de RAM actualmente en uso.
  final int? usedBytes;

  /// Total de bytes de RAM instalada.
  final int? totalBytes;

  /// Porcentaje de RAM usada (0.0–100.0).
  final double? percent;

  const MemMetrics({this.usedBytes, this.totalBytes, this.percent});

  /// Deserializa desde el objeto JSON `mem`.
  ///
  /// Claves JSON esperadas:
  ///   - `used_bytes`  (int?)  → [usedBytes]
  ///   - `total_bytes` (int?)  → [totalBytes]
  ///   - `percent`     (num?)  → [percent]  (cast seguro a double)
  factory MemMetrics.fromJson(Map<String, dynamic> json) {
    return MemMetrics(
      usedBytes: json['used_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

/// Métricas de uso del espacio de intercambio (swap).
///
/// Incluye una bandera [present] para distinguir entre "swap no configurada en
/// el sistema" (`present: false`) y "swap configurada pero sin datos disponibles"
/// (`present: null`). Si [present] es `false`, los campos numéricos serán `null`
/// o cero y no deben mostrarse en la UI.
/// Se recibe bajo la clave `"swap"` dentro de `"metrics"`.
class SwapMetrics {
  /// Indica si el sistema tiene swap configurada y activa.
  /// `false` → no hay swap; `null` → estado desconocido.
  final bool? present;

  /// Bytes de swap en uso. Solo relevante si [present] es `true`.
  final int? usedBytes;

  /// Total de bytes de swap disponibles. Solo relevante si [present] es `true`.
  final int? totalBytes;

  /// Porcentaje de swap usada (0.0–100.0). Solo relevante si [present] es `true`.
  final double? percent;

  const SwapMetrics({
    this.present,
    this.usedBytes,
    this.totalBytes,
    this.percent,
  });

  /// Deserializa desde el objeto JSON `swap`.
  ///
  /// Claves JSON esperadas:
  ///   - `present`     (bool?) → [present]
  ///   - `used_bytes`  (int?)  → [usedBytes]
  ///   - `total_bytes` (int?)  → [totalBytes]
  ///   - `percent`     (num?)  → [percent]  (cast seguro a double)
  factory SwapMetrics.fromJson(Map<String, dynamic> json) {
    return SwapMetrics(
      present: json['present'] as bool?,
      usedBytes: json['used_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

/// Métricas de uso de una partición de disco.
///
/// Un servidor puede tener múltiples particiones; por eso [SystemMetrics]
/// contiene una `List<DiskMetrics>` en lugar de un único objeto. Cada instancia
/// representa una partición montada distinta, identificada por [mount].
/// Se recibe como elemento de la lista `"disks"` dentro de `"metrics"`.
class DiskMetrics {
  /// Punto de montaje de la partición (p. ej. `"/"`, `"/home"`, `"/data"`).
  final String? mount;

  /// Tipo de sistema de ficheros (p. ej. `"ext4"`, `"xfs"`, `"tmpfs"`).
  /// Clave JSON: `"fstype"` (sin mayúscula en la T, diferencia respecto al campo Dart).
  final String? fsType;

  /// Dispositivo de bloque asociado (p. ej. `"/dev/sda1"`, `"/dev/nvme0n1p2"`).
  final String? device;

  /// Bytes usados en la partición.
  final int? usedBytes;

  /// Capacidad total de la partición en bytes.
  final int? totalBytes;

  /// Porcentaje de espacio usado (0.0–100.0).
  final double? percent;

  const DiskMetrics({
    this.mount,
    this.fsType,
    this.device,
    this.usedBytes,
    this.totalBytes,
    this.percent,
  });

  /// Deserializa desde un elemento JSON de la lista `disks`.
  ///
  /// Claves JSON esperadas:
  ///   - `mount`       (String?) → [mount]
  ///   - `fstype`      (String?) → [fsType]  (nota: JSON usa `fstype`, no `fsType`)
  ///   - `device`      (String?) → [device]
  ///   - `used_bytes`  (int?)    → [usedBytes]
  ///   - `total_bytes` (int?)    → [totalBytes]
  ///   - `percent`     (num?)    → [percent]  (cast seguro a double)
  factory DiskMetrics.fromJson(Map<String, dynamic> json) {
    return DiskMetrics(
      mount: json['mount'] as String?,
      fsType: json['fstype'] as String?,
      device: json['device'] as String?,
      usedBytes: json['used_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

/// Métricas de red acumuladas del servidor.
///
/// Expone los bytes totales recibidos y transmitidos desde el arranque del
/// sistema (contadores absolutos, no tasas por segundo). Si la UI necesita una
/// tasa, debe calcular la diferencia entre dos [MetricPoint] consecutivos.
/// Se recibe bajo la clave `"net"` dentro de `"metrics"`.
///
/// Limitación: solo expone los totales acumulados de todas las interfaces de
/// red combinadas, no el desglose por interfaz (eth0, ens3, etc.).
class NetworkMetrics {
  /// Bytes totales recibidos desde el arranque (acumulado, todas las interfaces).
  /// Clave JSON: `"rx_bytes_total"`.
  final int? netRx;

  /// Bytes totales transmitidos desde el arranque (acumulado, todas las interfaces).
  /// Clave JSON: `"tx_bytes_total"`.
  final int? netTx;

  const NetworkMetrics({this.netRx, this.netTx});

  /// Deserializa desde el objeto JSON `net`.
  ///
  /// Claves JSON esperadas:
  ///   - `rx_bytes_total` (int?) → [netRx]
  ///   - `tx_bytes_total` (int?) → [netTx]
  factory NetworkMetrics.fromJson(Map<String, dynamic> json) {
    return NetworkMetrics(
      netRx: json['rx_bytes_total'] as int?,
      netTx: json['tx_bytes_total'] as int?,
    );
  }
}

/// Agregado de todas las métricas del sistema operativo para un servidor.
///
/// Es el contenedor de nivel `"metrics"` en el JSON de api-py y agrupa
/// CPU, RAM, swap, discos y red. Todos los campos son opcionales excepto
/// [disks], que es una lista (posiblemente vacía) porque un servidor sin
/// particiones detectadas es un caso válido.
///
/// Este modelo es el más "pesado" del árbol; su deserialización implica
/// instanciar hasta 5 sub-modelos distintos.
class SystemMetrics {
  final CpuMetrics? cpu;
  final MemMetrics? mem;
  final SwapMetrics? swap;

  /// Lista de particiones de disco. Nunca `null`; puede estar vacía si el
  /// agente no detectó particiones o no tiene permisos para leerlas.
  final List<DiskMetrics> disks;

  final NetworkMetrics? net;

  const SystemMetrics({
    this.cpu,
    this.mem,
    this.swap,
    required this.disks,
    this.net,
  });

  /// Deserializa desde el objeto JSON `metrics`.
  ///
  /// Cada sub-campo se deserializa condicionalmente: si la clave está ausente
  /// o es `null` en el JSON, el campo del modelo queda `null` en lugar de
  /// lanzar una excepción, garantizando robustez ante respuestas parciales.
  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      cpu: json['cpu'] != null
          ? CpuMetrics.fromJson(json['cpu'] as Map<String, dynamic>)
          : null,
      mem: json['mem'] != null
          ? MemMetrics.fromJson(json['mem'] as Map<String, dynamic>)
          : null,
      swap: json['swap'] != null
          ? SwapMetrics.fromJson(json['swap'] as Map<String, dynamic>)
          : null,
      disks:
          (json['disks'] as List<dynamic>?)
              ?.map((e) => DiskMetrics.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      net: json['net'] != null
          ? NetworkMetrics.fromJson(json['net'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ── Service metrics ────────────────────────────────────────────────────────────

/// Workers del servidor Apache2 en un instante dado.
///
/// Los valores [busy] e [idle] llegan como `num` desde Python (pueden ser
/// int o float según la versión del módulo mod_status), de ahí el uso de
/// `double?` en lugar de `int?`.
class ApacheWorkers {
  /// Workers ocupados procesando solicitudes activas.
  final double? busy;

  /// Workers inactivos disponibles para nuevas conexiones.
  final double? idle;

  const ApacheWorkers({this.busy, this.idle});

  /// Deserializa desde el objeto JSON `workers` dentro de `apache2`.
  ///
  /// Claves JSON esperadas:
  ///   - `busy` (num?) → [busy]
  ///   - `idle` (num?) → [idle]
  factory ApacheWorkers.fromJson(Map<String, dynamic> json) => ApacheWorkers(
    busy: (json['busy'] as num?)?.toDouble(),
    idle: (json['idle'] as num?)?.toDouble(),
  );
}

/// Estadísticas de conexiones activas en Apache2.
class ApacheConnections {
  /// Total de conexiones abiertas al servidor Apache en este momento.
  final double? total;

  /// Conexiones en estado async keepalive (HTTP keep-alive sin solicitud activa).
  /// Clave JSON: `"async_keepalive"`.
  final double? asyncKeepalive;

  const ApacheConnections({this.total, this.asyncKeepalive});

  /// Deserializa desde el objeto JSON `connections` dentro de `apache2`.
  ///
  /// Claves JSON esperadas:
  ///   - `total`           (num?) → [total]
  ///   - `async_keepalive` (num?) → [asyncKeepalive]
  factory ApacheConnections.fromJson(Map<String, dynamic> json) =>
      ApacheConnections(
        total: (json['total'] as num?)?.toDouble(),
        asyncKeepalive: (json['async_keepalive'] as num?)?.toDouble(),
      );
}

/// Métricas del servidor web Apache2.
///
/// Agrupa los indicadores clave de rendimiento de Apache: tasa de peticiones,
/// throughput de bytes, workers y conexiones activas. El campo [enabled]
/// indica si el agente de api-py detectó Apache2 como servicio activo en el
/// servidor; si es `false` o `null`, el resto de campos pueden estar vacíos
/// y no deben mostrarse en la UI.
///
/// Se recibe bajo la clave `"apache2"` dentro de `"services"`.
class ApacheMetrics {
  /// `true` si el agente detectó Apache2 activo en el servidor.
  final bool? enabled;

  /// Segundos que lleva Apache2 en funcionamiento. Clave JSON: `"uptime_s"`.
  final int? uptime;

  /// Peticiones HTTP servidas por segundo (tasa instantánea). Clave JSON: `"req_per_sec"`.
  final double? reqPerSec;

  /// Bytes de respuesta HTTP enviados por segundo. Clave JSON: `"bytes_per_sec"`.
  final double? bytesPerSec;

  final ApacheWorkers? workers;
  final ApacheConnections? connections;

  const ApacheMetrics({
    this.enabled,
    this.uptime,
    this.reqPerSec,
    this.bytesPerSec,
    this.workers,
    this.connections,
  });

  /// Deserializa desde el objeto JSON `apache2`.
  ///
  /// Claves JSON esperadas:
  ///   - `enabled`       (bool?)          → [enabled]
  ///   - `uptime_s`      (int?)           → [uptime]
  ///   - `req_per_sec`   (num?)           → [reqPerSec]
  ///   - `bytes_per_sec` (num?)           → [bytesPerSec]
  ///   - `workers`       (Map? / null)    → [workers]
  ///   - `connections`   (Map? / null)    → [connections]
  factory ApacheMetrics.fromJson(Map<String, dynamic> json) {
    return ApacheMetrics(
      enabled: json['enabled'] as bool?,
      uptime: json['uptime_s'] as int?,
      reqPerSec: (json['req_per_sec'] as num?)?.toDouble(),
      bytesPerSec: (json['bytes_per_sec'] as num?)?.toDouble(),
      workers: json['workers'] != null
          ? ApacheWorkers.fromJson(json['workers'] as Map<String, dynamic>)
          : null,
      connections: json['connections'] != null
          ? ApacheConnections.fromJson(
              json['connections'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// Estadísticas de hilos de MariaDB.
///
/// Permite a la UI visualizar la carga de conexiones activas sobre el servidor
/// de base de datos: hilos conectados (sesiones abiertas) vs. hilos ejecutando
/// consultas activamente.
class MariaDbThreads {
  /// Número total de hilos con sesión abierta (SHOW STATUS LIKE 'Threads_connected').
  final int? connected;

  /// Hilos ejecutando una consulta en este instante (SHOW STATUS LIKE 'Threads_running').
  final int? running;

  const MariaDbThreads({this.connected, this.running});

  /// Deserializa desde el objeto JSON `threads` dentro de `mariadb`.
  ///
  /// Claves JSON esperadas:
  ///   - `connected` (int?) → [connected]
  ///   - `running`   (int?) → [running]
  factory MariaDbThreads.fromJson(Map<String, dynamic> json) => MariaDbThreads(
    connected: json['connected'] as int?,
    running: json['running'] as int?,
  );
}

/// Estadísticas de consultas de MariaDB.
class MariaDbQueries {
  /// Total acumulado de consultas ejecutadas desde el arranque de MariaDB.
  /// Clave JSON: `"queries_total"`.
  final int? queriesTotal;

  /// Número de consultas lentas (superan el umbral `long_query_time`).
  /// Llega como `num` desde Python por la misma razón que [ApacheWorkers].
  /// Clave JSON: `"slow_queries"`.
  final double? slowQueries;

  const MariaDbQueries({this.queriesTotal, this.slowQueries});

  /// Deserializa desde el objeto JSON `queries` dentro de `mariadb`.
  ///
  /// Claves JSON esperadas:
  ///   - `queries_total` (int?)  → [queriesTotal]
  ///   - `slow_queries`  (num?)  → [slowQueries]
  factory MariaDbQueries.fromJson(Map<String, dynamic> json) => MariaDbQueries(
    queriesTotal: json['queries_total'] as int?,
    slowQueries: (json['slow_queries'] as num?)?.toDouble(),
  );
}

/// Métricas del servidor de base de datos MariaDB.
///
/// Análogo a [ApacheMetrics] para MariaDB: el campo [enabled] indica si el
/// agente detectó el servicio activo. Si [enabled] es `false` o `null`, los
/// sub-campos pueden estar vacíos.
///
/// Se recibe bajo la clave `"mariadb"` dentro de `"services"`.
class MariaDbMetrics {
  /// `true` si el agente detectó MariaDB activo en el servidor.
  final bool? enabled;

  /// Segundos que lleva MariaDB en funcionamiento. Clave JSON: `"uptime_s"`.
  final int? uptime;

  final MariaDbThreads? threads;
  final MariaDbQueries? queries;

  const MariaDbMetrics({this.enabled, this.uptime, this.threads, this.queries});

  /// Deserializa desde el objeto JSON `mariadb`.
  ///
  /// Claves JSON esperadas:
  ///   - `enabled`  (bool?)       → [enabled]
  ///   - `uptime_s` (int?)        → [uptime]
  ///   - `threads`  (Map? / null) → [threads]
  ///   - `queries`  (Map? / null) → [queries]
  factory MariaDbMetrics.fromJson(Map<String, dynamic> json) {
    return MariaDbMetrics(
      enabled: json['enabled'] as bool?,
      uptime: json['uptime_s'] as int?,
      threads: json['threads'] != null
          ? MariaDbThreads.fromJson(json['threads'] as Map<String, dynamic>)
          : null,
      queries: json['queries'] != null
          ? MariaDbQueries.fromJson(json['queries'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Información sobre el puerto de escucha del servicio SSH.
class SshListen {
  /// Puerto en el que escucha el daemon SSH (habitualmente 22, pero puede
  /// estar personalizado).
  final int? port;

  /// `true` si el puerto está abierto y aceptando conexiones TCP.
  /// Clave JSON: `"port_open"`.
  final bool? portOpen;

  const SshListen({this.port, this.portOpen});

  /// Deserializa desde el objeto JSON `listen` dentro de `ssh`.
  ///
  /// Claves JSON esperadas:
  ///   - `port`      (int?)  → [port]
  ///   - `port_open` (bool?) → [portOpen]
  factory SshListen.fromJson(Map<String, dynamic> json) => SshListen(
    port: json['port'] as int?,
    portOpen: json['port_open'] as bool?,
  );
}

/// Métricas del servicio SSH (OpenSSH / dropbear).
///
/// A diferencia de Apache y MariaDB, SSH no expone contadores de rendimiento
/// propios; el agente de api-py solo puede determinar su estado mediante
/// systemd y la apertura del puerto. [sessionsEstimated] es una estimación
/// basada en el conteo de procesos, no una cifra exacta.
///
/// Se recibe bajo la clave `"ssh"` dentro de `"services"`.
class SshMetrics {
  /// `true` si el agente detectó SSH activo.
  final bool? enabled;

  /// Estado del unit de systemd (p. ej. `"active"`, `"inactive"`, `"failed"`).
  /// Clave JSON: `"systemd_state"`.
  final String? systemdState;

  final SshListen? listen;

  /// Número estimado de sesiones SSH activas, basado en el conteo de procesos
  /// sshd hijo. Es una aproximación, no un valor exacto.
  /// Clave JSON: `"sessions_estimated"`.
  final int? sessionsEstimated;

  const SshMetrics({
    this.enabled,
    this.systemdState,
    this.listen,
    this.sessionsEstimated,
  });

  /// Deserializa desde el objeto JSON `ssh`.
  ///
  /// Claves JSON esperadas:
  ///   - `enabled`             (bool?)       → [enabled]
  ///   - `systemd_state`       (String?)     → [systemdState]
  ///   - `listen`              (Map? / null) → [listen]
  ///   - `sessions_estimated`  (int?)        → [sessionsEstimated]
  factory SshMetrics.fromJson(Map<String, dynamic> json) {
    return SshMetrics(
      enabled: json['enabled'] as bool?,
      systemdState: json['systemd_state'] as String?,
      listen: json['listen'] != null
          ? SshListen.fromJson(json['listen'] as Map<String, dynamic>)
          : null,
      sessionsEstimated: json['sessions_estimated'] as int?,
    );
  }
}

/// Agregado de métricas de todos los servicios monitorizados en un servidor.
///
/// Corresponde al objeto `"services"` del JSON de api-py. Los tres servicios
/// actualmente soportados son Apache2, MariaDB y SSH. Si un servicio no está
/// presente en el servidor, su campo será `null` (no `enabled: false`).
///
/// Decisión de diseño: los servicios están enumerados explícitamente como campos
/// en lugar de usar un `Map<String, dynamic>`. Esto impone fuertemente que el
/// conjunto de servicios monitorizados es fijo y conocido en tiempo de compilación.
/// Si en el futuro api-py añade soporte para nuevos servicios (Nginx, PostgreSQL,
/// Redis…), habrá que añadir los campos correspondientes aquí y en la UI.
class ServiceMetrics {
  final ApacheMetrics? apache2;
  final MariaDbMetrics? mariadb;
  final SshMetrics? ssh;

  const ServiceMetrics({this.apache2, this.mariadb, this.ssh});

  /// Deserializa desde el objeto JSON `services`.
  ///
  /// Claves JSON esperadas:
  ///   - `apache2`  (Map? / null) → [apache2]
  ///   - `mariadb`  (Map? / null) → [mariadb]
  ///   - `ssh`      (Map? / null) → [ssh]
  factory ServiceMetrics.fromJson(Map<String, dynamic> json) {
    return ServiceMetrics(
      apache2: json['apache2'] != null
          ? ApacheMetrics.fromJson(json['apache2'] as Map<String, dynamic>)
          : null,
      mariadb: json['mariadb'] != null
          ? MariaDbMetrics.fromJson(json['mariadb'] as Map<String, dynamic>)
          : null,
      ssh: json['ssh'] != null
          ? SshMetrics.fromJson(json['ssh'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ── MetricPoint ───────────────────────────────────────────────────────────────

/// Representa un único punto de métrica: el estado completo de un servidor en
/// un instante de tiempo concreto.
///
/// Es la clase raíz del árbol de modelos de métricas y la que consume
/// directamente el provider/servicio de métricas. Una colección de
/// [MetricPoint] ordenada por [ts] forma la serie temporal de un servidor.
///
/// Estructura del JSON de api-py que mapea a esta clase:
/// ```json
/// {
///   "ts":       "2025-11-10T14:32:00Z",   // ISO 8601 UTC
///   "host":     { ... },                   // HostMetrics
///   "metrics":  { ... },                   // SystemMetrics
///   "services": { ... }                    // ServiceMetrics
/// }
/// ```
///
/// Compatibilidad con api-py:
///   El endpoint de métricas devuelve una lista de [MetricPoint] paginada.
///   El provider de métricas es responsable de iterar las páginas y construir
///   la serie temporal completa como `List<MetricPoint>`.
class MetricPoint {
  /// Marca temporal del punto de métrica en UTC (ISO 8601).
  /// Es el campo de ordenación principal de la serie temporal.
  final DateTime ts;

  final HostMetrics? host;

  /// Métricas del sistema operativo en este instante.
  final SystemMetrics? metrics;

  /// Métricas de los servicios monitorizados en este instante.
  final ServiceMetrics? services;

  const MetricPoint({required this.ts, this.host, this.metrics, this.services});

  /// Deserializa desde el JSON de un punto de métrica devuelto por api-py.
  ///
  /// Parámetros JSON esperados:
  ///   - `ts`       (String?) — timestamp ISO 8601. Si es `null` o no parseable,
  ///                            se usa `DateTime.now()` como fallback (ver nota).
  ///   - `host`     (Map? / null) → [host]
  ///   - `metrics`  (Map? / null) → [metrics]
  ///   - `services` (Map? / null) → [services]
  ///
  /// Nota sobre el fallback de timestamp:
  ///   Si `ts` es `null` o no es un string ISO 8601 válido, `DateTime.tryParse`
  ///   devuelve `null` y se sustituye silenciosamente por `DateTime.now()`.
  ///   Esto puede causar ordenación incorrecta de puntos en la serie temporal
  ///   si api-py devuelve timestamps corruptos. Ver observaciones del fichero.
  factory MetricPoint.fromJson(Map<String, dynamic> json) {
    return MetricPoint(
      ts: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
      host: json['host'] != null
          ? HostMetrics.fromJson(json['host'] as Map<String, dynamic>)
          : null,
      metrics: json['metrics'] != null
          ? SystemMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : null,
      services: json['services'] != null
          ? ServiceMetrics.fromJson(json['services'] as Map<String, dynamic>)
          : null,
    );
  }
}
