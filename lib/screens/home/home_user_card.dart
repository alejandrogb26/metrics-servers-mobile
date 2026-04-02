import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_session.dart';

class HomeUserCard extends StatelessWidget {
  final Session session;
  const HomeUserCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + nombre ───────────────────────────────────────────────
            Row(
              children: [
                _UserAvatar(urlFoto: session.urlFoto),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                if (session.isSuperAdmin)
                  const StatusBadge(
                    label: 'SUPERADMIN',
                    color: Color(0xFFE3B341),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF30363D)),
            const SizedBox(height: 12),

            // ── Info ──────────────────────────────────────────────────────────
            InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: session.email,
            ),
            InfoRow(
              icon: Icons.group_outlined,
              label: 'Grupo',
              value: session.grupo.nombre,
            ),

            // ── Permisos globales ──────────────────────────────────────────────
            if (session.permisos.global.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Permisos globales',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: session.permisos.global
                    .map(
                      (p) =>
                          StatusBadge(label: p, color: const Color(0xFF388BFD)),
                    )
                    .toList(),
              ),
            ],

            // ── Permisos por sección ──────────────────────────────────────────
            if (session.permisos.sections.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Permisos por sección',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const SizedBox(height: 6),
              ...session.permisos.sections.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        'Sección ${entry.key}: ',
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        children: entry.value
                            .map(
                              (p) => StatusBadge(
                                label: p,
                                color: const Color(0xFF3FB950),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? urlFoto;
  const _UserAvatar({this.urlFoto});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: urlFoto != null && urlFoto!.isNotEmpty
          ? FadeInImage.assetNetwork(
              placeholder: 'assets/no_image.png',
              image: urlFoto!,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              imageErrorBuilder: (_, __, ___) => _defaultAvatar(),
            )
          : _defaultAvatar(),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFF21262D),
      child: const Icon(Icons.person, size: 36, color: Color(0xFF8B949E)),
    );
  }
}
