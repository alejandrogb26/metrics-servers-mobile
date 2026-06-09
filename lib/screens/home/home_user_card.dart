/// home_user_card.dart
///
/// Propósito:
///   Tarjeta de resumen del usuario autenticado. Muestra los datos de identidad
///   (avatar, nombre completo, username, email, grupo) y el desglose de permisos
///   activos de la sesión (globales y por sección) como badges de color.
///
/// Capa arquitectónica:
///   Capa de presentación — componente de la pantalla principal (screens/home/).
///   Es un widget de presentación pura: no accede a ningún provider ni realiza
///   peticiones HTTP. Recibe la [Session] ya construida desde [HomeScreen].
///
/// Clases definidas en este fichero:
///   - [HomeUserCard]: tarjeta principal con toda la información de sesión.
///   - [_UserAvatar]:  avatar circular con carga de imagen de red y fallback.
///
/// Datos de permisos — claves compuestas:
///   [Session.permisos] es un [PermissionMap] cuyas listas contienen strings en
///   formato `NOMBRE_AMBITO` (p. ej. `"AUDIT_USER"`, `"AUDIT_SERV"`), generados
///   por api-py con `CONCAT(p.nombre, '_', a.nombre)`. La tarjeta los muestra
///   tal cual como badges sin traducción a texto legible.
///   - Permisos globales → badges azules (`0xFF388BFD`).
///   - Permisos de sección → badges verdes (`0xFF3FB950`), agrupados por sección.
///
/// Nota: el [PermissionMap] de [Session] difiere del [GrupoPermissionMap] del
///   modelo de administración. En la sesión, las listas son de strings (claves
///   ya resueltas); en los grupos, son de IDs enteros pendientes de resolución.
///
/// Qué NO debe contener este fichero:
///   - Lógica de navegación.
///   - Acceso a providers ni peticiones HTTP.
///   - Widgets reutilizables fuera del contexto de la pantalla home.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_session.dart';

/// Tarjeta de información completa de la sesión del usuario autenticado.
///
/// Responsabilidad:
///   Presentar en un solo bloque visual: avatar, nombre, username, email, grupo
///   de pertenencia, badge SUPERADMIN condicional y los permisos activos de la
///   sesión organizados en dos secciones (globales y por sección).
///
/// Diseño — widget de presentación pura:
///   Recibe [session] como parámetro y lo renderiza sin escuchar cambios.
///   [HomeScreen] es responsable de observar [AuthProvider] y de pasar la
///   sesión actualizada. Si la sesión cambia, Flutter reconstruirá este widget
///   con los nuevos datos automáticamente.
///
/// Secciones de la tarjeta:
///   1. Avatar + nombre completo + username + badge SUPERADMIN (si aplica).
///   2. Divider.
///   3. Email y nombre del grupo ([InfoRow]).
///   4. Permisos globales como badges azules (solo si no está vacío).
///   5. Permisos por sección como badges verdes por sección (solo si no está vacío).
///
/// Relación con otros módulos:
///   - [HomeScreen]: instancia esta tarjeta pasando `auth.session`.
///   - [Session]: modelo de sesión con todos los datos que se muestran.
///   - [PermissionMap]: estructura de permisos de la sesión (strings, no IDs).
///   - [StatusBadge]: widget compartido para los badges de permisos y superAdmin.
///   - [InfoRow]: widget compartido para las filas de email y grupo.
class HomeUserCard extends StatelessWidget {
  /// Sesión activa del usuario autenticado. Nunca debería ser `null` en este
  /// punto; [HomeScreen] garantiza que el widget solo se construye si hay sesión.
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
            // ── Avatar + nombre + badge superAdmin ────────────────────────
            Row(
              children: [
                // Avatar circular con fallback si urlFoto es null, vacía o falla.
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
                // Badge SUPERADMIN solo si el grupo del usuario tiene superAdmin.
                // Usa el mismo color dorado que el badge de DetalleGrupoScreen.
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

            // ── Datos de identidad ────────────────────────────────────────
            InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: session.email,
            ),
            InfoRow(
              icon: Icons.group_outlined,
              label: 'Grupo',
              // Nombre del grupo principal del usuario (GrupoSession.nombre).
              value: session.grupo.nombre,
            ),

            // ── Permisos globales ─────────────────────────────────────────
            // Solo se muestra si el usuario tiene al menos un permiso global.
            // Las claves son strings compuestos ("AUDIT_USER", "AUDIT_SERV"),
            // no IDs; se muestran tal cual sin resolución adicional.
            if (session.permisos.global.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Permisos globales',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const SizedBox(height: 6),
              // Wrap gestiona el overflow: si los badges no caben en una línea,
              // fluyen a la siguiente automáticamente.
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: session.permisos.global
                    .map(
                      (p) => StatusBadge(
                        label: p,
                        color: const Color(
                          0xFF388BFD,
                        ), // Azul: permisos globales
                      ),
                    )
                    .toList(),
              ),
            ],

            // ── Permisos por sección ──────────────────────────────────────
            // Solo se muestra si el usuario tiene permisos en al menos una sección.
            // entry.key es la clave de sección (string); entry.value es la lista
            // de claves de permiso para esa sección. Las secciones se muestran
            // con su clave cruda ("Sección {key}"), sin resolución al nombre completo.
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
                                color: const Color(
                                  0xFF3FB950,
                                ), // Verde: permisos de sección
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

// ── Avatar del usuario ─────────────────────────────────────────────────────────

/// Avatar circular del usuario con carga de imagen de red y fallback local.
///
/// Responsabilidad:
///   Mostrar la foto del usuario (si existe y se puede cargar) o un icono de
///   persona genérico como fallback. Siempre renderiza un círculo de 64×64 px.
///
/// Estrategia de carga de imagen (tres casos):
///   1. `urlFoto` es `null` o vacía: muestra [_defaultAvatar] directamente,
///      sin intentar ninguna petición de red.
///   2. `urlFoto` tiene valor y la imagen carga correctamente: muestra la foto
///      real con animación de fade desde el placeholder local.
///   3. `urlFoto` tiene valor pero la carga falla (404, sin red, etc.):
///      `imageErrorBuilder` captura el error y muestra [_defaultAvatar].
///
/// Implementación técnica:
///   - [FadeInImage.assetNetwork]: muestra `assets/no_image.png` mientras carga
///     la imagen de red; hace un crossfade suave al completar. Requiere que el
///     asset esté declarado en `pubspec.yaml`.
///   - [ClipRRect] con radio 40: crea el recorte circular. Con 64px de ancho y
///     radio 40 (> 32 = mitad del lado), el recorte resulta en un círculo perfecto.
///   - [_defaultAvatar] es un método (no un widget separado) porque solo se usa
///     internamente en dos puntos de este mismo widget.
class _UserAvatar extends StatelessWidget {
  /// URL de la foto de perfil del usuario. Puede ser `null` si api-py no la
  /// devuelve, o una cadena vacía si el usuario no tiene foto configurada.
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
              // Captura errores de carga (red, 404, formato inválido) y muestra
              // el avatar por defecto en lugar de un widget de error de Flutter.
              imageErrorBuilder: (context, error, _) => _defaultAvatar(),
            )
          : _defaultAvatar(),
    );
  }

  /// Avatar genérico: fondo gris oscuro con icono de persona centrado.
  /// Se usa cuando no hay URL de foto o cuando la carga de red falla.
  Widget _defaultAvatar() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFF21262D),
      child: const Icon(Icons.person, size: 36, color: Color(0xFF8B949E)),
    );
  }
}
