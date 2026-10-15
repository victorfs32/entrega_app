import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'acha_parada_page.dart';
import 'services/rota_lida_service.dart';
import 'ui/painel_financeiro.dart';

/// Lê a rota da tela de outro app (ex.: Circuit) pra depois, ao bipar um
/// pacote, o Baixa Fácil dizer em qual parada ele está. Sem API: usa o
/// serviço de acessibilidade do Android, que o motorista liga uma vez.
class LeitorRotaPage extends StatefulWidget {
  const LeitorRotaPage({super.key});

  @override
  State<LeitorRotaPage> createState() => _LeitorRotaPageState();
}

class _LeitorRotaPageState extends State<LeitorRotaPage>
    with WidgetsBindingObserver {
  final _rota = RotaLidaService.instance;

  bool carregando = true;
  bool servicoAtivo = false;
  bool lendo = false;
  int novosNaSessao = 0;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _rota.carregar();
    servicoAtivo = await _rota.servicoAtivo();

    if (!mounted) return;
    setState(() => carregando = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _relogio?.cancel();
    _rota.capturar(false);
    super.dispose();
  }

  // Ao voltar das configurações do Android, confere se o serviço foi ligado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _rota.servicoAtivo().then((ativo) {
        if (mounted) setState(() => servicoAtivo = ativo);
      });
      if (lendo) _coletar();
    }
  }

  Future<void> _escolherApp() async {
    final apps = await _rota.listarApps();
    if (!mounted) return;

    final escolhido = await showModalBottomSheet<AppInstalado>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EscolhaDeApp(apps: apps),
    );

    if (escolhido == null) return;

    await _rota.definirAlvo(escolhido);
    if (mounted) setState(() {});
  }

  Future<void> _comecar() async {
    if (_rota.pacoteAlvo == null) {
      await _escolherApp();
      if (_rota.pacoteAlvo == null) return;
    }

    novosNaSessao = 0;
    await _rota.capturar(true);

    _relogio?.cancel();
    _relogio = Timer.periodic(const Duration(seconds: 2), (_) => _coletar());

    setState(() => lendo = true);

    final abriu = await _rota.abrirAlvo();
    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui abrir o app. Abra ele à mão.')),
      );
    }
  }

  Future<void> _parar() async {
    _relogio?.cancel();
    await _rota.capturar(false);
    await _coletar();

    if (mounted) setState(() => lendo = false);
  }

  Future<void> _coletar() async {
    try {
      final novos = await _rota.coletar();
      if (!mounted) return;
      setState(() => novosNaSessao += novos);
    } catch (_) {
      // próxima rodada tenta de novo
    }
  }

  Future<void> _limpar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar rota lida?'),
        content: const Text(
          'Os pacotes lidos da rota serão esquecidos. Você pode ler de novo '
          'quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _rota.limpar();
    if (mounted) setState(() => novosNaSessao = 0);
  }

  void _verTextoLido() {
    final telas = _rota.ultimasTelas;
    final texto = telas.isEmpty
        ? 'Nada foi lido ainda. Ligue a leitura, abra o app e navegue pela rota.'
        : telas
              .asMap()
              .entries
              .map((e) => '--- tela ${e.key + 1} ---\n${e.value.join('\n')}')
              .join('\n\n');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Texto lido do outro app',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: texto));
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Texto copiado.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  texto,
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passo({
    required int numero,
    required String titulo,
    required String texto,
    required bool feito,
    Widget? acao,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: feito ? Colors.green : colors.primaryContainer,
              child: feito
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                      '$numero',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  if (acao != null) ...[const SizedBox(height: 12), acao],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ler rota de outro app')),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PainelHero(
                  rotulo: 'Paradas na rota lida',
                  valor: _rota.totalParadas.toDouble(),
                  dinheiro: false,
                  apoio: lendo
                      ? 'Lendo agora — $novosNaSessao parada(s) nova(s) nesta leitura'
                      : (_rota.nomeAlvo == null
                            ? 'Nenhum app escolhido ainda'
                            : 'App: ${_rota.nomeAlvo}'),
                ),
                const SizedBox(height: 14),
                _passo(
                  numero: 1,
                  titulo: 'Ligar o leitor de tela',
                  texto: servicoAtivo
                      ? 'Ligado. O Baixa Fácil só lê o app que você escolher '
                            'e só enquanto a leitura estiver ativa.'
                      : 'Em Acessibilidade, procure "Baixa Fácil — leitor de '
                            'tela" e ligue. Se a opção estiver cinza, abra '
                            '"Detalhes do app", toque nos três pontinhos e '
                            'escolha "Permitir configurações restritas".',
                  feito: servicoAtivo,
                  acao: servicoAtivo
                      ? null
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _rota.abrirAcessibilidade,
                              child: const Text('Abrir Acessibilidade'),
                            ),
                            OutlinedButton(
                              onPressed: _rota.abrirDetalhesDoApp,
                              child: const Text('Detalhes do app'),
                            ),
                          ],
                        ),
                ),
                _passo(
                  numero: 2,
                  titulo: 'Escolher o app da rota',
                  texto: _rota.nomeAlvo == null
                      ? 'Escolha o Circuit (ou outro app) na lista.'
                      : 'Lendo: ${_rota.nomeAlvo}',
                  feito: _rota.pacoteAlvo != null,
                  acao: OutlinedButton(
                    onPressed: lendo ? null : _escolherApp,
                    child: Text(
                      _rota.pacoteAlvo == null ? 'Escolher app' : 'Trocar app',
                    ),
                  ),
                ),
                _passo(
                  numero: 3,
                  titulo: 'Ler a rota',
                  texto: lendo
                      ? 'Agora vá no app, abra a lista da rota e role devagar até o '
                            'fim. O Baixa Fácil guarda o ID, o endereço e a '
                            'quantidade de pacotes de cada parada. Volte aqui '
                            'e toque em "Parar" quando terminar.'
                      : 'Toque em "Começar": o app da rota abre e o Baixa '
                            'Fácil lê o que aparecer na tela.',
                  feito: _rota.totalParadas > 0 && !lendo,
                  acao: lendo
                      ? FilledButton.icon(
                          onPressed: _parar,
                          icon: const Icon(Icons.stop),
                          label: const Text('Parar leitura'),
                        )
                      : FilledButton.icon(
                          onPressed: servicoAtivo ? _comecar : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Começar a ler'),
                        ),
                ),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  onPressed: _rota.totalParadas == 0
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AchaParadaPage(),
                          ),
                        ),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Achar a parada de um pacote'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _verTextoLido,
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('Ver texto lido'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rota.totalParadas == 0 ? null : _limpar,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Limpar'),
                      ),
                    ),
                  ],
                ),
                if (_rota.totalParadas > 0) ...[
                  const SizedBox(height: 10),
                  const TituloSecao('Paradas lidas'),
                  for (final parada in _rota.paradas)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(parada.id)),
                        title: Text(parada.endereco),
                        subtitle: Text(
                          [
                            if (parada.local != null) parada.local!,
                            if (parada.pacotes != null)
                              '${parada.pacotes} pacote${parada.pacotes == 1 ? '' : 's'}',
                          ].join(' • '),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _EscolhaDeApp extends StatefulWidget {
  final List<AppInstalado> apps;

  const _EscolhaDeApp({required this.apps});

  @override
  State<_EscolhaDeApp> createState() => _EscolhaDeAppState();
}

class _EscolhaDeAppState extends State<_EscolhaDeApp> {
  String filtro = '';

  @override
  Widget build(BuildContext context) {
    final apps = widget.apps
        .where((a) => a.nome.toLowerCase().contains(filtro.toLowerCase()))
        .toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => filtro = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar app (ex.: Circuit)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: apps.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.apps),
                  title: Text(apps[i].nome),
                  onTap: () => Navigator.pop(context, apps[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
