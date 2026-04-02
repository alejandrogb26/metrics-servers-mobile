// ── Host ──────────────────────────────────────────────────────────────────────
class HostMetrics {
  final int? uptimeSeconds;
  const HostMetrics({this.uptimeSeconds});

  factory HostMetrics.fromJson(Map<String, dynamic> json) {
    return HostMetrics(uptimeSeconds: json['uptime_s'] as int?);
  }
}

// ── System ────────────────────────────────────────────────────────────────────
class CpuMetrics {
  final double? percent;
  final int? cores;
  final List<double> loadAvg;

  const CpuMetrics({this.percent, this.cores, required this.loadAvg});

  factory CpuMetrics.fromJson(Map<String, dynamic> json) {
    return CpuMetrics(
      percent: (json['percent'] as num?)?.toDouble(),
      cores: json['cores'] as int?,
      loadAvg: (json['loadavg'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

class MemMetrics {
  final int? usedBytes;
  final int? totalBytes;
  final double? percent;

  const MemMetrics({this.usedBytes, this.totalBytes, this.percent});

  factory MemMetrics.fromJson(Map<String, dynamic> json) {
    return MemMetrics(
      usedBytes: json['used_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

class SwapMetrics {
  final bool? present;
  final int? usedBytes;
  final int? totalBytes;
  final double? percent;

  const SwapMetrics({this.present, this.usedBytes, this.totalBytes, this.percent});

  factory SwapMetrics.fromJson(Map<String, dynamic> json) {
    return SwapMetrics(
      present: json['present'] as bool?,
      usedBytes: json['used_bytes'] as int?,
      totalBytes: json['total_bytes'] as int?,
      percent: (json['percent'] as num?)?.toDouble(),
    );
  }
}

class DiskMetrics {
  final String? mount;
  final String? fsType;
  final String? device;
  final int? usedBytes;
  final int? totalBytes;
  final double? percent;

  const DiskMetrics({
    this.mount,
    this.fsType,
    this.device,
    this.usedBytes,
    this.totalBytes,
    this.percent,
  });

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

class NetworkMetrics {
  final int? netRx;
  final int? netTx;

  const NetworkMetrics({this.netRx, this.netTx});

  factory NetworkMetrics.fromJson(Map<String, dynamic> json) {
    return NetworkMetrics(
      netRx: json['rx_bytes_total'] as int?,
      netTx: json['tx_bytes_total'] as int?,
    );
  }
}

class SystemMetrics {
  final CpuMetrics? cpu;
  final MemMetrics? mem;
  final SwapMetrics? swap;
  final List<DiskMetrics> disks;
  final NetworkMetrics? net;

  const SystemMetrics({this.cpu, this.mem, this.swap, required this.disks, this.net});

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
      disks: (json['disks'] as List<dynamic>?)
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
class ApacheWorkers {
  final double? busy;
  final double? idle;
  const ApacheWorkers({this.busy, this.idle});
  factory ApacheWorkers.fromJson(Map<String, dynamic> json) =>
      ApacheWorkers(
        busy: (json['busy'] as num?)?.toDouble(),
        idle: (json['idle'] as num?)?.toDouble(),
      );
}

class ApacheConnections {
  final double? total;
  final double? asyncKeepalive;
  const ApacheConnections({this.total, this.asyncKeepalive});
  factory ApacheConnections.fromJson(Map<String, dynamic> json) =>
      ApacheConnections(
        total: (json['total'] as num?)?.toDouble(),
        asyncKeepalive: (json['async_keepalive'] as num?)?.toDouble(),
      );
}

class ApacheMetrics {
  final bool? enabled;
  final int? uptime;
  final double? reqPerSec;
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
              json['connections'] as Map<String, dynamic>)
          : null,
    );
  }
}

class MariaDbThreads {
  final int? connected;
  final int? running;
  const MariaDbThreads({this.connected, this.running});
  factory MariaDbThreads.fromJson(Map<String, dynamic> json) =>
      MariaDbThreads(
        connected: json['connected'] as int?,
        running: json['running'] as int?,
      );
}

class MariaDbQueries {
  final int? queriesTotal;
  final double? slowQueries;
  const MariaDbQueries({this.queriesTotal, this.slowQueries});
  factory MariaDbQueries.fromJson(Map<String, dynamic> json) =>
      MariaDbQueries(
        queriesTotal: json['queries_total'] as int?,
        slowQueries: (json['slow_queries'] as num?)?.toDouble(),
      );
}

class MariaDbMetrics {
  final bool? enabled;
  final int? uptime;
  final MariaDbThreads? threads;
  final MariaDbQueries? queries;

  const MariaDbMetrics({this.enabled, this.uptime, this.threads, this.queries});

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

class SshListen {
  final int? port;
  final bool? portOpen;
  const SshListen({this.port, this.portOpen});
  factory SshListen.fromJson(Map<String, dynamic> json) =>
      SshListen(
        port: json['port'] as int?,
        portOpen: json['port_open'] as bool?,
      );
}

class SshMetrics {
  final bool? enabled;
  final String? systemdState;
  final SshListen? listen;
  final int? sessionsEstimated;

  const SshMetrics({this.enabled, this.systemdState, this.listen, this.sessionsEstimated});

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

class ServiceMetrics {
  final ApacheMetrics? apache2;
  final MariaDbMetrics? mariadb;
  final SshMetrics? ssh;

  const ServiceMetrics({this.apache2, this.mariadb, this.ssh});

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
class MetricPoint {
  final DateTime ts;
  final HostMetrics? host;
  final SystemMetrics? metrics;
  final ServiceMetrics? services;

  const MetricPoint({
    required this.ts,
    this.host,
    this.metrics,
    this.services,
  });

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
