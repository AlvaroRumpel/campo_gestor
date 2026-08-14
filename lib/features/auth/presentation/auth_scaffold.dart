import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';

/// Shell visual das telas de auth (spec 4.13): fundo verde musgo, bloco de
/// marca no topo (logo laranja + título + tagline) e painel bone r22 no
/// rodapé com o formulário. A partir de [Breakpoints.mobile] a composição
/// vira um card de 440px com raio nos quatro cantos e sombra, centrado
/// sobre o fundo verde, com a marca imediatamente acima.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.tagline,
    this.icon = Icons.grass,
    required this.child,
  });

  final String title;
  final String? tagline;
  final IconData icon;

  /// Conteúdo do painel (o formulário).
  final Widget child;

  /// Identifica o card centrado (>= [Breakpoints.mobile]) nos testes.
  static const Key cardKey = ValueKey('auth-card');

  /// Identifica a folha inferior (< [Breakpoints.mobile]) nos testes.
  static const Key sheetKey = ValueKey('auth-sheet');

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 30, color: AppColors.onAccent),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.onGreen,
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: 10),
          Text(
            tagline!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.onGreenSecondary,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= Breakpoints.mobile) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _brand(),
                          const SizedBox(height: 28),
                          Container(
                            key: cardKey,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.ink.withValues(alpha: 0.18),
                                  blurRadius: 32,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                            child: child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 24,
                      ),
                      child: _brand(),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Container(
                          key: sheetKey,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
