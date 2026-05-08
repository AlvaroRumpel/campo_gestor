import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/piquete_repository.dart';

class PaddockDetailScreen extends ConsumerWidget {
  const PaddockDetailScreen({super.key, required this.paddockId});
  final String paddockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddockAsync = ref.watch(paddockByIdProvider(paddockId));
    return Scaffold(
      appBar: AppBar(title: const Text('Piquete')),
      body: paddockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const Center(child: Text('Erro ao carregar piquete.')),
        data: (paddock) {
          if (paddock == null) {
            return const Center(child: Text('Piquete não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Nome'),
                subtitle: Text(paddock.name),
              ),
              ListTile(
                title: const Text('Área'),
                subtitle: Text(
                  '${paddock.areaHa.toStringAsFixed(2).replaceAll('.', ',')} ha',
                ),
              ),
              ListTile(
                title: const Text('Capacidade'),
                subtitle: Text(
                  '${paddock.uaCapacity.toStringAsFixed(2).replaceAll('.', ',')} UA',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
