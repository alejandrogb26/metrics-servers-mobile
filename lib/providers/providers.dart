import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/material_app.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:metrics_servers_mobile/providers/metrics_provider.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:provider/provider.dart';

export 'auth_provider.dart';
export 'servidor_provider.dart';
export 'grupo_provider.dart';
export 'metrics_provider.dart';

class Providers extends StatelessWidget {
  const Providers({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ServidorProvider()),
        ChangeNotifierProvider(create: (_) => GrupoProvider()),
        ChangeNotifierProvider(create: (_) => MetricsProvider()),
      ],
      child: const MonitoringApp(),
    );
  }
}
