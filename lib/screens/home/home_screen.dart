import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/home/home_user_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      });

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
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
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
                    _NoAccessCard(),
                  if (auth.canViewUserManagement()) ...[
                    _QuickAccessTile(
                      icon: Icons.manage_accounts_outlined,
                      label: 'Gestión de grupos',
                      subtitle: 'Grupos, permisos y ámbitos',
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

// ── Drawer ─────────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final AuthProvider auth;
  const _AppDrawer({required this.auth});

  @override
  Widget build(BuildContext context) {
    final session = auth.session;

    if (session == null) {
      return const Drawer(child: SafeArea(child: SizedBox.shrink()));
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
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
                  if (auth.canViewAnyServer()) ...[
                    _DrawerItem(
                      icon: Icons.dns_outlined,
                      label: 'Listado de servidores',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, AppRoutes.listaServidores);
                      },
                    ),
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
                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      auth.logout();
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.exit_to_app,
                    label: 'Salir de la aplicación',
                    color: Colors.redAccent,
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
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

// ── Quick access tile ──────────────────────────────────────────────────────────
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
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
                  color: color.withOpacity(0.12),
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

class _NoAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
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
