import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/lancamentos_service.dart';
import '../utils/quinzena.dart' as quinzena;

/// Peças visuais do painel financeiro da Home: cartão principal com a
/// quinzena, gráfico de ganho por dia e linha de métricas. Tipografia
/// Inter (embutida no app) e gráficos com fl_chart.
const String _fonte = 'Inter';

String _dinheiro(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

TextStyle _estilo({
  double tamanho = 14,
  FontWeight peso = FontWeight.w500,
  Color? cor,
  double? altura,
  double? espacamento,
}) {
  return TextStyle(
    fontFamily: _fonte,
    fontSize: tamanho,
    fontWeight: peso,
    color: cor,
    height: altura,
    letterSpacing: espacamento,
  );
}

/// Valor em reais que "conta" até o número final quando muda.
class _ValorAnimado extends StatelessWidget {
  final double valor;
  final TextStyle estilo;

  const _ValorAnimado({required this.valor, required this.estilo});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: valor),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, atual, _) => Text(_dinheiro(atual), style: estilo),
    );
  }
}

class _Pilula extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Pilula({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            texto,
            style: _estilo(
              tamanho: 12.5,
              peso: FontWeight.w600,
              cor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão principal: quanto já ganhou na quinzena, quanto da quinzena já
/// passou e quando o dinheiro cai.
class HeroQuinzena extends StatelessWidget {
  final ResumoLancamentos resumo;

  /// Meta de ganho da quinzena (null = sem meta) e o toque pra defini-la.
  final double? meta;
  final VoidCallback? onEditarMeta;

  const HeroQuinzena({
    super.key,
    required this.resumo,
    this.meta,
    this.onEditarMeta,
  });

  Widget _blocoMeta(int diasRestantes) {
    final alvo = meta;

    if (alvo == null) {
      return InkWell(
        onTap: onEditarMeta,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Definir meta da quinzena',
                  style: _estilo(
                    tamanho: 13,
                    peso: FontWeight.w600,
                    cor: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      );
    }

    final atingida = resumo.ganho >= alvo;
    final percentual = (resumo.ganho / alvo).clamp(0.0, 1.0);
    final falta = alvo - resumo.ganho;

    String apoio;
    if (atingida) {
      apoio = 'Meta batida! 🎉';
    } else if (diasRestantes > 0) {
      apoio =
          'Faltam ${_dinheiro(falta)} • ${_dinheiro(falta / diasRestantes)} por dia';
    } else {
      apoio = 'Faltaram ${_dinheiro(falta)}';
    }

    return InkWell(
      onTap: onEditarMeta,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Meta ${_dinheiro(alvo)}',
                    style: _estilo(
                      tamanho: 13,
                      cor: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Text(
                  '${(resumo.ganho / alvo * 100).floor()}%',
                  style: _estilo(
                    tamanho: 14,
                    peso: FontWeight.w800,
                    cor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: percentual),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, valor, _) => LinearProgressIndicator(
                  value: valor,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(
                    atingida ? const Color(0xFF6EE7A8) : Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              apoio,
              style: _estilo(
                tamanho: 12,
                cor: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final inicio = quinzena.inicioDaQuinzena(hoje);
    final fim = quinzena.fimDaQuinzena(hoje);
    final previsao = quinzena.previsaoPagamento(fim);

    final diasTotais = fim.difference(inicio).inDays + 1;
    final diasPassados = (hoje.difference(inicio).inDays + 1).clamp(
      1,
      diasTotais,
    );
    final progresso = diasPassados / diasTotais;
    final diasRestantes = diasTotais - diasPassados;

    final formatoCurto = DateFormat('dd/MM');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F44), Color(0xFF12397A), Color(0xFF1673D1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1673D1).withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GANHO DA QUINZENA',
                style: _estilo(
                  tamanho: 11.5,
                  peso: FontWeight.w700,
                  cor: Colors.white.withValues(alpha: 0.72),
                  espacamento: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                '${formatoCurto.format(inicio)} – ${formatoCurto.format(fim)}',
                style: _estilo(
                  tamanho: 12.5,
                  peso: FontWeight.w600,
                  cor: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _ValorAnimado(
              valor: resumo.ganho,
              estilo: _estilo(
                tamanho: 44,
                peso: FontWeight.w800,
                cor: Colors.white,
                altura: 1.1,
                espacamento: -1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pilula(
                icone: Icons.inventory_2_outlined,
                texto: '${resumo.totalPacotes} pacotes',
              ),
              _Pilula(
                icone: Icons.local_shipping_outlined,
                texto: 'Anjun ${resumo.anjun}',
              ),
              _Pilula(
                icone: Icons.inventory_outlined,
                texto: 'iMile ${resumo.imile}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _blocoMeta(diasRestantes),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            diasRestantes == 0
                ? 'Último dia da quinzena'
                : 'Faltam $diasRestantes dia${diasRestantes == 1 ? '' : 's'} pra fechar a quinzena',
            style: _estilo(
              tamanho: 12,
              cor: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Previsão de pagamento',
                    style: _estilo(
                      tamanho: 13,
                      cor: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(previsao),
                  style: _estilo(
                    tamanho: 14,
                    peso: FontWeight.w700,
                    cor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Três números do dia/mês numa linha só, separados por divisórias finas.
class LinhaMetricas extends StatelessWidget {
  final ResumoLancamentos hoje;
  final ResumoLancamentos mes;

  const LinhaMetricas({super.key, required this.hoje, required this.mes});

  Widget _metrica(BuildContext context, String rotulo, String valor) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: _estilo(
                tamanho: 19,
                peso: FontWeight.w700,
                cor: colors.onSurface,
                espacamento: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rotulo,
            style: _estilo(
              tamanho: 12,
              cor: colors.onSurfaceVariant,
              peso: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.painel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _metrica(context, 'Ganho hoje', _dinheiro(hoje.ganho)),
            VerticalDivider(
              width: 1,
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
            _metrica(context, 'Pacotes hoje', '${hoje.totalPacotes}'),
            VerticalDivider(
              width: 1,
              color: colors.outlineVariant.withValues(alpha: 0.6),
            ),
            _metrica(context, 'Ganho no mês', _dinheiro(mes.ganho)),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de barras do ganho por dia nos últimos 14 dias (fl_chart).
class GraficoGanhos extends StatelessWidget {
  final List<Lancamento> lancamentos;

  const GraficoGanhos({super.key, required this.lancamentos});

  static const int _dias = 14;
  static const List<String> _letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    final dias = List.generate(
      _dias,
      (i) => hoje.subtract(Duration(days: _dias - 1 - i)),
    );
    final valores = dias
        .map(
          (dia) => LancamentosService.somar(
            lancamentos,
            inicio: dia,
            fim: dia,
          ).ganho,
        )
        .toList();

    final total = valores.fold<double>(0, (a, b) => a + b);
    final maior = valores.fold<double>(0, (a, b) => a > b ? a : b);
    final topo = maior == 0 ? 10.0 : maior * 1.25;

    final grupos = List.generate(_dias, (i) {
      final ehHoje = i == _dias - 1;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: valores[i],
            width: 12,
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: ehHoje
                  ? [colors.primary, colors.primary.withValues(alpha: 0.75)]
                  : [
                      colors.primary.withValues(alpha: 0.35),
                      colors.primary.withValues(alpha: 0.65),
                    ],
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: topo,
              color: colors.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: colors.painel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ganho por dia',
                      style: _estilo(
                        tamanho: 15,
                        peso: FontWeight.w700,
                        cor: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Últimos $_dias dias',
                      style: _estilo(tamanho: 12, cor: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                _dinheiro(total),
                style: _estilo(
                  tamanho: 15,
                  peso: FontWeight.w700,
                  cor: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: topo,
                alignment: BarChartAlignment.spaceBetween,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: grupos,
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= dias.length) {
                          return const SizedBox.shrink();
                        }

                        final ehHoje = i == _dias - 1;

                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            _letras[dias[i].weekday - 1],
                            style: _estilo(
                              tamanho: 11,
                              peso: ehHoje ? FontWeight.w800 : FontWeight.w500,
                              cor: ehHoje
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.inverseSurface,
                    tooltipBorderRadius: BorderRadius.circular(10),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dia = dias[group.x];

                      return BarTooltipItem(
                        '${DateFormat('dd/MM').format(dia)}\n',
                        _estilo(
                          tamanho: 11,
                          cor: colors.onInverseSurface.withValues(alpha: 0.75),
                        ),
                        children: [
                          TextSpan(
                            text: _dinheiro(rod.toY),
                            style: _estilo(
                              tamanho: 13,
                              peso: FontWeight.w700,
                              cor: colors.onInverseSurface,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de destaque genérico (mesmo degradê do cartão da Home): um
/// rótulo, um valor grande em reais, uma linha de apoio e pílulas.
class PainelHero extends StatelessWidget {
  final String rotulo;
  final double valor;
  final String? apoio;
  final List<(IconData, String)> pilulas;
  final Widget? rodape;

  const PainelHero({
    super.key,
    required this.rotulo,
    required this.valor,
    this.apoio,
    this.pilulas = const [],
    this.rodape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1F44), Color(0xFF12397A), Color(0xFF1673D1)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1673D1).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo.toUpperCase(),
            style: _estilo(
              tamanho: 11.5,
              peso: FontWeight.w700,
              cor: Colors.white.withValues(alpha: 0.72),
              espacamento: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _ValorAnimado(
              valor: valor,
              estilo: _estilo(
                tamanho: 40,
                peso: FontWeight.w800,
                cor: Colors.white,
                altura: 1.1,
                espacamento: -1.0,
              ),
            ),
          ),
          if (apoio != null) ...[
            const SizedBox(height: 6),
            Text(
              apoio!,
              style: _estilo(
                tamanho: 13,
                cor: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (pilulas.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in pilulas) _Pilula(icone: p.$1, texto: p.$2),
              ],
            ),
          ],
          if (rodape != null) ...[const SizedBox(height: 16), rodape!],
        ],
      ),
    );
  }
}

/// Faixa com N métricas lado a lado (rótulo pequeno embaixo do valor).
class FaixaMetricas extends StatelessWidget {
  final List<(String rotulo, String valor)> itens;

  const FaixaMetricas({super.key, required this.itens});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final divisoria = VerticalDivider(
      width: 1,
      color: colors.outlineVariant.withValues(alpha: 0.6),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.painel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < itens.length; i++) ...[
              if (i > 0) divisoria,
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        itens[i].$2,
                        style: _estilo(
                          tamanho: 19,
                          peso: FontWeight.w700,
                          cor: colors.onSurface,
                          espacamento: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itens[i].$1,
                      style: _estilo(tamanho: 12, cor: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Título de seção no padrão do painel.
class TituloSecao extends StatelessWidget {
  final String texto;
  final String? apoio;

  const TituloSecao(this.texto, {super.key, this.apoio});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            texto,
            style: _estilo(
              tamanho: 16,
              peso: FontWeight.w700,
              cor: colors.onSurface,
              espacamento: -0.2,
            ),
          ),
          if (apoio != null) ...[
            const SizedBox(width: 8),
            Text(
              apoio!,
              style: _estilo(tamanho: 12.5, cor: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
