import 'package:flutter/material.dart';

import 'entregas_page.dart';
import 'financeiro_page.dart';
import 'relatorios_page.dart';
import 'configuracoes_page.dart';
import 'perfil_page.dart';
import 'entrega_em_massa_page.dart';
import 'services/sincronizacao_fotos_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  bool sincronizando = false;
  int totalEncontradas = 0;
  int totalEnviadas = 0;
  int totalIgnoradas = 0;
  int totalErros = 0;

  void _abrirEntregas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EntregasPage()),
    );
  }

  Future<void> _sincronizarFotosManual() async {
    if (SincronizacaoFotosService.instance.emExecucao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe uma sincronização em andamento.'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sincronizar fotos?'),
          content: const Text(
            'O app vai enviar apenas as fotos pendentes do motorista logado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sincronizar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    await _executarSincronizacao(mostrarMensagemFinal: true);
  }

  Future<void> _executarSincronizacao({
    required bool mostrarMensagemFinal,
  }) async {
    if (sincronizando) return;

    setState(() {
      sincronizando = true;
      totalEncontradas = 0;
      totalEnviadas = 0;
      totalIgnoradas = 0;
      totalErros = 0;
    });

    final resultado = await SincronizacaoFotosService.instance.sincronizar(
      onInicio: (encontradas, ignoradas) {
        if (!mounted) return;
        setState(() {
          totalEncontradas = encontradas;
          totalIgnoradas = ignoradas;
        });
      },
      onProgresso: (enviadas, erros) {
        if (!mounted) return;
        setState(() {
          totalEnviadas = enviadas;
          totalErros = erros;
        });
      },
    );

    if (!mounted) return;

    setState(() {
      sincronizando = false;
    });

    if (!mostrarMensagemFinal) return;

    if (resultado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível sincronizar agora. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.totalEncontradas == 0
              ? 'Nenhuma foto pendente para sincronizar.'
              : 'Finalizado. Pendentes: ${resultado.totalEncontradas} | Enviadas: ${resultado.totalEnviadas} | Já sincronizadas: ${resultado.totalIgnoradas} | Erros: ${resultado.totalErros}',
        ),
        backgroundColor: resultado.totalErros == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _itemMenu({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback? onTap,
    Color iconColor = Colors.blue,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: iconColor),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
        trailing: sincronizando && titulo == 'Sincronizar fotos'
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progresso = totalEncontradas == 0
        ? 'Procurando fotos pendentes...'
        : 'Pendentes: $totalEncontradas | Enviadas: $totalEnviadas | Já sincronizadas: $totalIgnoradas | Erros: $totalErros';

    return Scaffold(
      appBar: AppBar(title: const Text('Menu'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _itemMenu(
              icon: Icons.person,
              titulo: 'Meu Perfil',
              subtitulo: 'Ver dados do motorista logado',
              iconColor: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PerfilPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.list_alt,
              titulo: 'Entregas',
              subtitulo: 'Ver pacotes entregues',
              onTap: () => _abrirEntregas(context),
            ),
            _itemMenu(
              icon: Icons.dynamic_feed,
              titulo: 'Entrega em massa',
              subtitulo: 'Bipar vários pacotes seguidos, com foto de cada um',
              iconColor: Colors.teal,
              onTap: () async {
                final quantidade = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(builder: (_) => const EntregaEmMassaPage()),
                );

                if (!context.mounted) return;

                if (quantidade != null && quantidade > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$quantidade pacote(s) registrados no lote.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            _itemMenu(
              icon: Icons.bar_chart,
              titulo: 'Relatórios',
              subtitulo: 'Ganhos por dia e por semana',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RelatoriosPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.account_balance_wallet,
              titulo: 'Financeiro',
              subtitulo: 'Quanto já ganhei, recebi e ainda falta receber',
              iconColor: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinanceiroPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.cloud_upload,
              titulo: 'Sincronizar fotos',
              subtitulo: sincronizando
                  ? progresso
                  : 'Enviar minhas fotos pendentes para o Google Drive',
              iconColor: Colors.green,
              onTap: sincronizando ? null : _sincronizarFotosManual,
            ),
            _itemMenu(
              icon: Icons.settings,
              titulo: 'Configurações',
              subtitulo: 'Ajustes do aplicativo',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConfiguracoesPage()),
                );
              },
            ),
            _itemMenu(
              icon: Icons.info,
              titulo: 'Sobre o app',
              subtitulo: 'Informações do Entrega App',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
