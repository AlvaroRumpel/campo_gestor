import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder until Plan 06 implements the full detail screen.
class AnimalDetailScreen extends ConsumerWidget {
  const AnimalDetailScreen({super.key, required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animal')),
      body: Center(child: Text('AnimalDetailScreen stub — animalId=$animalId')),
    );
  }
}
