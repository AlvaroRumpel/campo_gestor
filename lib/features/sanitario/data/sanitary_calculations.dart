// Pure sanitary calculation helpers (SANI-01/02/03). Dependency-free — no
// flutter/material.dart, no supabase_flutter, no Riverpod — so these run as
// plain `flutter_test` unit tests with zero widget or network setup (D-40).
//
// `totalUaForCategories` resolves each category through the project's single
// UA weight table (`kUaWeights`, lib/features/animais/data/animal_constants.dart)
// rather than duplicating it — mirrors `calcTotalUa`'s `?? 0.0` idiom for an
// unrecognised category.
//
// A null cost (`costPerKg`/`costPerUa`) is never converted into `0.0` — a
// missing price stays unknown all the way to the widget that decides to omit
// the row (D-11).
import 'package:intl/intl.dart';

import '../../animais/data/animal_constants.dart';

/// mL/UA = mL/kg × kg/UA.
double dosagePerUa(double dosagePerKg, double kgPerUa) =>
    dosagePerKg * kgPerUa;

/// R$/UA = R$/kg × kg/UA. Null propagates — a missing cost is never a price.
double? costPerUa(double? costPerKg, double kgPerUa) =>
    costPerKg == null ? null : costPerKg * kgPerUa;

/// Sums each category's UA weight. Unknown categories contribute 0.0.
double totalUaForCategories(Iterable<String> categories) => categories.fold(
      0.0,
      (sum, category) => sum + (kUaWeights[category] ?? 0.0),
    );

/// Total mL for a composition = total UA × kg/UA × mL/kg.
double totalVolumeMl(double totalUa, double dosagePerKg, double kgPerUa) =>
    totalUa * kgPerUa * dosagePerKg;

/// Total cost for a composition = total UA × kg/UA × R$/kg. Null if the dose
/// has no known cost per kg (D-11).
double? totalCost(double totalUa, double? costPerKg, double kgPerUa) =>
    costPerKg == null ? null : totalUa * kgPerUa * costPerKg;

final NumberFormat _uaFmt = NumberFormat('#,##0.0', 'pt_BR');
final NumberFormat _mlFmt = NumberFormat('#,##0', 'pt_BR');
final NumberFormat _litersFmt = NumberFormat('#,##0.0', 'pt_BR');
final NumberFormat _currencyDigitsFmt = NumberFormat('#,##0.00', 'pt_BR');

/// Always one decimal place, comma separator — a whole UA total never renders
/// as a bare integer.
String formatUa(double ua) => _uaFmt.format(ua);

/// Below 1000 mL: `N mL`. At/above 1000 mL: `N,N L` (ResumoAplicacaoDialog
/// totals rule, UI-SPEC).
String formatVolumeMl(double ml) {
  if (ml < 1000) return '${_mlFmt.format(ml)} mL';
  return '${_litersFmt.format(ml / 1000)} L';
}

/// BRL symbol concatenated with a pattern-formatted number, rather than
/// `NumberFormat.currency` — the currency constructor inserts a
/// non-breaking space in some intl releases, which would make an
/// exact-string assertion environment-dependent.
String formatCurrencyBrl(double value) =>
    'R\$ ${_currencyDigitsFmt.format(value)}';
