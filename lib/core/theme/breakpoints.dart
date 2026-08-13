/// Fonte única das faixas de largura do shell adaptativo (spec "musgo
/// evoluído"). Não duplicar estes valores em telas ou widgets.
///
/// - abaixo de [mobile]: bottom nav (comportamento mobile atual).
/// - de [mobile] até abaixo de [drawer]: rail de ícones de 76px.
/// - a partir de [drawer]: drawer fixo de 232px.
///
/// [rail] não é uma faixa do shell — ele existe para telas que precisam de
/// layout mestre-detalhe decidirem sua própria composição; o shell não muda
/// de forma nesse valor.
abstract final class Breakpoints {
  static const double mobile = 600;
  static const double rail = 1024;
  static const double drawer = 1440;
}
