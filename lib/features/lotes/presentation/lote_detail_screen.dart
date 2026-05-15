import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder until Plan 05 implements the full detail screen.
/// Constructor signature is final — Plan 05 reuses it.
class LoteDetailScreen extends ConsumerWidget {
  const LoteDetailScreen({super.key, required this.loteId});
  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lote')),
      body: Center(child: Text('LoteDetailScreen stub — loteId=$loteId')),
    );
  }
}
