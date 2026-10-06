import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'scanner_page.dart';
import 'model/pacote.dart';
import 'entregas_page.dart';
import 'fotos_pendentes_page.dart';
import 'menu_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/atualizacao_service.dart';
import 'services/atualizacao_dialog.dart';
import 'services/sincronizacao_fotos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'login_page.dart';
import 'manutencao_page.dart';
import 'assinatura_gate.dart';
import 'entrega_em_massa_page.dart';
import 'financeiro_page.dart';
import 'lancamento_page.dart';
import 'relatorios_page.dart';
import 'services/lancamentos_service.dart';
import 'ui/painel_financeiro.dart';
import 'utils/quinzena.dart' as quinzena;

List<Pacote> listaPacotes = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final ValueNotifier<bool> darkMode = ValueNotifier(false);

  @override
  State<MyApp> createState() => _MyAppState();

  static Future<void> carregarTema() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode.value = prefs.getBool('darkMode') ?? false;
  }

  static Future<void> salvarTema(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    darkMode.value = value;
  }
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    MyApp.carregarTema();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MyApp.darkMode,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Baixa Fácil',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
          locale: const Locale('pt', 'BR'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const ManutencaoGate(),
        );
      },
    );
  }
}

// Checa em tempo real (via snapshots, não um get() único) se o app está
// em modo de manutenção, ANTES até da tela de login — assim dá pra
// bloquear o acesso de todo mundo direto pelo Firestore, sem precisar
// gerar e reinstalar um novo APK em cada celular.
class ManutencaoGate extends StatelessWidget {
  const ManutencaoGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('app')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final dados = snapshot.data?.data() as Map<String, dynamic>?;

        if (dados?['manutencao'] == true) {
          return ManutencaoPage(mensagem: dados?['mensagemManutencao']);
        }

        return const AuthCheckPage();
      },
    );
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key});

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  late final Future<bool> _verificacao = _verificarAcesso();
  String? _mensagemBloqueio;

  // Uma sessão já aberta antes do motorista ser bloqueado por um admin
  // continua válida no Firebase Auth — sem essa checagem, ele reabriria o
  // app direto na Home e só veria telas vazias (as regras do Firestore
  // negam a leitura, mas isso sozinho não é uma boa experiência).
  Future<bool> _verificarAcesso() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return false;

    try {
      final motoristaDoc = await FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get();

      if (motoristaDoc.data()?['ativo'] == false) {
        _mensagemBloqueio =
            'Sua conta está bloqueada. Fale com o administrador.';
        await FirebaseAuth.instance.signOut();
        return false;
      }

      // Não bloqueia o carregamento do app por causa disso — é só um
      // registro pro admin ver quem realmente usa o app, não algo crítico.
      unawaited(
        motoristaDoc.reference.update({'ultimoAcesso': Timestamp.now()}),
      );

      return true;
    } catch (_) {
      // Sem conseguir confirmar o status por um problema de rede, não
      // bloqueia o motorista aqui — as regras do Firestore continuam
      // protegendo os dados de qualquer forma.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _verificacao,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const HomePage();
        }

        return LoginPage(mensagemInicial: _mensagemBloqueio);
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double valorPacote = 3.0;
  bool carregando = true;

  // Criado uma vez só: um stream novo a cada build() re-assinaria o
  // Firestore e piscava os números do painel a cada rebuild.
  final Stream<List<Lancamento>> _lancamentos = LancamentosService.ouvir();
  final Stream<double?> _meta = LancamentosService.ouvirMeta();

  Future<void> _editarMeta(double? atual) async {
    final controller = TextEditingController(
      text: atual == null
          ? ''
          : atual.toStringAsFixed(2).replaceAll('.', ','),
    );

    final resultado = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta da quinzena'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quanto quer ganhar',
            prefixText: 'R\$ ',
            hintText: '3000',
          ),
        ),
        actions: [
          if (atual != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 0.0),
              child: const Text('Remover'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              // "3.000,50" (pt-BR) ou "3000.50" — só tira o ponto de
              // milhar quando há vírgula decimal.
              final texto = controller.text.trim();
              final valor = double.tryParse(
                texto.contains(',')
                    ? texto.replaceAll('.', '').replaceAll(',', '.')
                    : texto,
              );
              Navigator.pop(context, valor != null && valor > 0 ? valor : null);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    controller.dispose();

    // null = cancelou (ou valor inválido); 0 = remover a meta.
    if (resultado == null) return;

    try {
      await LancamentosService.definirMeta(resultado);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar a meta agora.')),
      );
    }
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(' ').where((e) => e.isNotEmpty).toList();

    if (partes.isEmpty) return 'U';
    if (partes.length == 1) return partes.first[0].toUpperCase();

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Widget _topoUsuario() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('configuracoes')
          .doc('app')
          .get(),
      builder: (context, configSnapshot) {
        final configDados =
            configSnapshot.data?.data() as Map<String, dynamic>?;
        final assinaturaAtiva = configDados?['assinaturaAtiva'] == true;
        final diasTeste =
            (configDados?['diasTesteGratis'] as num?)?.toInt() ?? 0;

        return _topoUsuarioConteudo(assinaturaAtiva, diasTeste);
      },
    );
  }

  Widget _topoUsuarioConteudo(bool assinaturaAtiva, int diasTeste) {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('motoristas')
          .doc(usuario.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final dados = snapshot.data!.data() as Map<String, dynamic>;

        final nome = dados['nome'] ?? '';
        final valor = dados['valorPacote'];

        if (valor is int) {
          valorPacote = valor.toDouble();
        } else if (valor is double) {
          valorPacote = valor;
        }
        final ehAdmin = dados['admin'] == true;
        final cargo = ehAdmin ? 'Administrador' : 'Motorista';
        final pagoAte = (dados['pagoAte'] as Timestamp?)?.toDate();
        final criadoEm = (dados['criadoEm'] as Timestamp?)?.toDate();
        final colors = Theme.of(context).colorScheme;

        return Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(
                _iniciais(nome),
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cargo,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),

                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (!ehAdmin && assinaturaAtiva) ...[
              const Spacer(),
              _chipAssinatura(pagoAte, criadoEm, diasTeste),
            ],
          ],
        );
      },
    );
  }

  Widget _chipAssinatura(DateTime? pagoAte, DateTime? criadoEm, int diasTeste) {
    final semanticColors = context.semanticColors;

    final emDia = pagoAte != null && pagoAte.isAfter(DateTime.now());

    Color cor;
    String texto;

    if (!emDia && diasTeste > 0 && criadoEm != null) {
      final diasRestantesTeste = criadoEm
          .add(Duration(days: diasTeste))
          .difference(DateTime.now())
          .inDays;

      if (diasRestantesTeste >= 0) {
        cor = semanticColors.info;
        texto = diasRestantesTeste == 0
            ? 'Teste grátis: termina hoje'
            : 'Teste grátis: $diasRestantesTeste dia${diasRestantesTeste == 1 ? '' : 's'}';

        return _chipConteudo(cor, texto);
      }
    }

    if (pagoAte == null) {
      cor = semanticColors.danger;
      texto = 'Assinatura pendente';
    } else {
      final dias = pagoAte.difference(DateTime.now()).inDays;

      if (dias < 0) {
        cor = semanticColors.danger;
        texto = 'Assinatura vencida';
      } else if (dias == 0) {
        cor = semanticColors.warning;
        texto = 'Vence hoje';
      } else if (dias <= 2) {
        cor = semanticColors.warning;
        texto = 'Vence em $dias dia${dias == 1 ? '' : 's'}';
      } else {
        cor = semanticColors.success;
        texto = 'Vence em $dias dias';
      }
    }

    return _chipConteudo(cor, texto);
  }

  Widget _chipConteudo(Color cor, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 11),
        textAlign: TextAlign.right,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _carregarEntregasFirebase();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarAtualizacao();
      _sincronizarFotosEmSegundoPlano();
    });
  }

  // Roda em segundo plano, sem diálogo nem snackbar: envia fotos de
  // entregas feitas offline assim que o motorista abre o app e tem
  // internet, sem precisar entrar no Menu e apertar "Sincronizar".
  Future<void> _sincronizarFotosEmSegundoPlano() async {
    final resultado = await SincronizacaoFotosService.instance.sincronizar();

    if (!mounted || resultado == null || resultado.totalEnviadas == 0) return;

    await _carregarEntregasFirebase();
  }

  Future<void> _verificarAtualizacao() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final service = AtualizacaoService();
    final info = await service.verificarAtualizacao();

    if (!mounted || info == null || !info.temAtualizacao) return;

    await AtualizacaoDialog.mostrar(context, info);
  }

  Future<void> _carregarEntregasFirebase() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario == null) {
        if (!mounted) return;
        setState(() => carregando = false);
        return;
      }
      final uid = usuario.uid;

      final snapshot = await FirebaseFirestore.instance
          .collection('entregas')
          .where('motoristaId', isEqualTo: uid)
          .orderBy('dataLeitura', descending: true)
          .get();

      listaPacotes.clear();

      for (final doc in snapshot.docs) {
        final dados = doc.data();
        final dataFirebase = dados['dataLeitura'];

        listaPacotes.add(
          Pacote(
            codigo: dados['codigo'] ?? '',
            userId: dados['motoristaId'],
            transportadora: dados['transportadora'] ?? '',
            dataLeitura: dataFirebase is Timestamp
                ? dataFirebase.toDate()
                : DateTime.now(),
            nomeRecebedor: dados['recebedor'] ?? '',
            fotoPath: dados['fotoPath'],
            fotoUrl: dados['fotoUrl'],
            fotoViewUrl: dados['fotoViewUrl'],
            fotoDownloadUrl: dados['fotoDownloadUrl'],
            fotoPath2: dados['fotoPath2'],
            fotoUrl2: dados['fotoUrl2'],
            fotoViewUrl2: dados['fotoViewUrl2'],
            fotoDownloadUrl2: dados['fotoDownloadUrl2'],
            lat: (dados['lat'] as num?)?.toDouble(),
            lng: (dados['lng'] as num?)?.toDouble(),
            entregue: dados['entregue'] ?? true,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar entregas: $e')));
    }
  }

  Future<void> _abrirScanner() async {
    final liberado = await verificarAcessoLiberado(context);
    if (!liberado || !mounted) return;

    final codigo = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );

    if (codigo != null && mounted) {
      await _carregarEntregasFirebase();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Baixa registrada: $codigo'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _abrirEntregas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EntregasPage()),
    );
  }

  void _abrirMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage()),
    );
  }

  Widget _linhaResumo({
    required IconData icon,
    required String texto,
    required Color color,
    VoidCallback? onTap,
  }) {
    final linha = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
        ],
      ),
    );

    if (onTap == null) return linha;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: linha,
    );
  }

  Future<void> _abrirLancamento({DateTime? dia}) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LancamentoPage(diaInicial: dia)),
    );

    if (salvou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lançamento salvo.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _abrirFinanceiro() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinanceiroPage()),
    );
  }

  void _abrirRelatorios() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RelatoriosPage()),
    );
  }

  Future<void> _abrirEntregaEmMassa() async {
    final liberado = await verificarAcessoLiberado(context);
    if (!liberado || !mounted) return;

    final quantidade = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const EntregaEmMassaPage()),
    );

    if (!mounted) return;

    if (quantidade != null && quantidade > 0) {
      await _carregarEntregasFirebase();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$quantidade pacote(s) registrados no lote.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  static String _dinheiro(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Chamada pra lançar o dia de hoje — ou o resumo dele, se já foi lançado.
  Widget _cartaoLancamentoHoje(Lancamento? hoje) {
    final colors = Theme.of(context).colorScheme;

    if (hoje == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hoje ainda não foi lançado',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Informe quantos pacotes entregou em cada empresa.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _abrirLancamento(),
                icon: const Icon(Icons.add),
                label: const Text('Lançar o dia de hoje'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(Icons.check_circle, color: colors.primary),
        title: Text('Hoje: ${_dinheiro(hoje.ganho)}'),
        subtitle: Text('Anjun ${hoje.anjun} • iMile ${hoje.imile}'),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _abrirLancamento(dia: hoje.dia),
      ),
    );
  }

  /// A baixa (bipar e guardar a foto/comprovante) continua aqui, mas como
  /// recurso de apoio — o ganho vem dos lançamentos diários, não dela.
  Widget _cartaoBaixas({
    required int totalBaixas,
    required int fotosPendentes,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner, color: colors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Baixas e comprovantes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bipe pacotes e guarde a foto de cada entrega.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _abrirScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _abrirEntregaEmMassa,
                    icon: const Icon(Icons.dynamic_feed),
                    label: const Text('Em massa'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _linhaResumo(
              icon: Icons.list_alt,
              texto: '$totalBaixas baixas registradas',
              color: colors.primary,
              onTap: _abrirEntregas,
            ),
            _linhaResumo(
              icon: Icons.cloud_upload_outlined,
              texto: 'Fotos pendentes: $fotosPendentes',
              color: colors.secondary,
              onTap: fotosPendentes == 0
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FotosPendentesPage(),
                        ),
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBaixas = listaPacotes.where((p) => p.entregue).length;
    final fotosPendentes = listaPacotes.where((p) {
      return p.entregue && p.fotoUrl == null;
    }).length;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _carregarEntregasFirebase,
        child: StreamBuilder<List<Lancamento>>(
          stream: _lancamentos,
          builder: (context, snapshot) {
            final lancamentos = snapshot.data ?? const <Lancamento>[];

            final agora = DateTime.now();
            final hoje = DateTime(agora.year, agora.month, agora.day);

            final resumoQuinzena = LancamentosService.somar(
              lancamentos,
              inicio: quinzena.inicioDaQuinzena(hoje),
              fim: quinzena.fimDaQuinzena(hoje),
            );
            final resumoHoje = LancamentosService.somar(
              lancamentos,
              inicio: hoje,
              fim: hoje,
            );
            final resumoMes = LancamentosService.somar(
              lancamentos,
              inicio: DateTime(hoje.year, hoje.month, 1),
              fim: DateTime(hoje.year, hoje.month + 1, 0),
            );

            Lancamento? lancamentoHoje;
            for (final l in lancamentos) {
              if (l.dia == hoje) {
                lancamentoHoje = l;
                break;
              }
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  _topoUsuario(),

                  const SizedBox(height: 20),

                  StreamBuilder<double?>(
                    stream: _meta,
                    builder: (context, metaSnapshot) => HeroQuinzena(
                      resumo: resumoQuinzena,
                      meta: metaSnapshot.data,
                      onEditarMeta: () => _editarMeta(metaSnapshot.data),
                    ),
                  ),

                  const SizedBox(height: 14),

                  LinhaMetricas(hoje: resumoHoje, mes: resumoMes),

                  const SizedBox(height: 14),

                  GraficoGanhos(lancamentos: lancamentos),

                  const SizedBox(height: 14),

                  _cartaoLancamentoHoje(lancamentoHoje),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _abrirFinanceiro,
                          icon: const Icon(Icons.account_balance_wallet),
                          label: const Text('Financeiro'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _abrirRelatorios,
                          icon: const Icon(Icons.bar_chart),
                          label: const Text('Relatórios'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _cartaoBaixas(
                    totalBaixas: totalBaixas,
                    fotosPendentes: fotosPendentes,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirLancamento(),
        icon: const Icon(Icons.add),
        label: const Text('Lançar o dia'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            _abrirMenu();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_outlined),
            selectedIcon: Icon(Icons.menu),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}
