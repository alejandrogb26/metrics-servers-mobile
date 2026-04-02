import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';

class ServidorSearchDelegate extends SearchDelegate<Servidor?> {
  final ServidorProvider servidorProvider;

  ServidorSearchDelegate({required this.servidorProvider})
      : super(searchFieldLabel: 'Buscar por hostname, DNS o ID…');

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Color(0xFF8B949E)),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.trim().isEmpty) {
      return const EmptyStateWidget(
        message: 'Escribe para buscar servidores',
        icon: Icons.search,
      );
    }
    final results = servidorProvider.search(query.trim());
    if (results.isEmpty) {
      return EmptyStateWidget(
        message: 'No se encontraron resultados para "$query"',
        icon: Icons.dns_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final s = results[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ServerImage(imageUrl: s.imagenUrl, width: 44, height: 44),
          ),
          title: Text(s.hostname,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text(s.dns,
              style:
                  const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
          onTap: () {
            close(context, s);
            Navigator.pushNamed(
              context,
              AppRoutes.detalleServidor,
              arguments: s,
            );
          },
        );
      },
    );
  }
}
