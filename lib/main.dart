import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'scanner_page.dart';
import 'model/pacote.dart';
import 'entregas_page.dart';
import 'menu_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/atualizacao_service.dart';
import 'services/atualizacao_dialog.dart';
import 'services/sincronizacao_fotos_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'login_page.dart';
import 'manutencao_page.dart';

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
        _mensagemBloqueio = 'Sua conta está bloqueada. Fale com o administrador.';
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
  String _iniciais(String nome) {
    final partes = nome.trim().split(' ').where((e) => e.isNotEmpty).toList();

    if (partes.isEmpty) return 'U';
    if (partes.length == 1) return partes.first[0].toUpperCase();

    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  Widget _topoUsuario() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('motoristas')
          .doc(FirebaseAuth.instance.currentUser!.uid)
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
        final cargo = dados['admin'] == true ? 'Administrador' : 'Motorista';
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
          ],
        );
      },
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
      final uid = FirebaseAuth.instance.currentUser!.uid;

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

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  Widget _cardEstatistica({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color backgroundColor,
    required Color foregroundColor,
    VoidCallback? onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  valor,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(color: foregroundColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaResumo({
    required IconData icon,
    required String texto,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  Widget _resumoDoDia({
    required int entregasHoje,
    required double ganhoHoje,
    required int fotosPendentes,
  }) {
    const int metaDia = 80;
    final colors = Theme.of(context).colorScheme;
    final progresso = entregasHoje / metaDia;
    final progressoLimitado = progresso.clamp(0.0, 1.0).toDouble();
    final porcentagem = (progresso * 100).clamp(0, 100).toInt();
    final faltam = (metaDia - entregasHoje).clamp(0, metaDia);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo do dia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 16),

            _linhaResumo(
              icon: Icons.inventory_2_outlined,
              texto: '$entregasHoje entregas',
              color: colors.primary,
            ),

            const SizedBox(height: 10),

            _linhaResumo(
              icon: Icons.payments_outlined,
              texto:
                  'R\$ ${ganhoHoje.toStringAsFixed(2).replaceAll('.', ',')}',
              color: colors.tertiary,
            ),

            const SizedBox(height: 10),

            _linhaResumo(
              icon: Icons.cloud_upload_outlined,
              texto: 'Fotos pendentes: $fotosPendentes',
              color: colors.secondary,
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meta: $entregasHoje/$metaDia'),
                Text('$porcentagem%'),
              ],
            ),

            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: progressoLimitado,
              minHeight: 12,
              borderRadius: BorderRadius.circular(20),
            ),

            const SizedBox(height: 10),

            Text(
              faltam == 0
                  ? 'Meta concluída!'
                  : 'Faltam $faltam entregas para bater a meta',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();

    final entregasHoje = listaPacotes.where((p) {
      return p.entregue && _mesmoDia(p.dataLeitura, hoje);
    }).length;

    final totalBaixas = listaPacotes.where((p) => p.entregue).length;
    final ganhoHoje = entregasHoje * valorPacote;

    final ultimasEntregas = listaPacotes
        .where((p) => p.entregue)
        .take(5)
        .toList();

    final fotosPendentes = listaPacotes.where((p) {
      return p.entregue && p.fotoUrl == null;
    }).length;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarEntregasFirebase,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    _topoUsuario(),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        Expanded(
                          child: _cardEstatistica(
                            icon: Icons.done_all_outlined,
                            titulo: 'Total\nBaixas',
                            valor: '$totalBaixas',
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                          ),
                        ),
                        Expanded(
                          child: _cardEstatistica(
                            icon: Icons.inventory_2_outlined,
                            titulo: 'Entregas\nHoje',
                            valor: '$entregasHoje',
                            backgroundColor: colors.secondaryContainer,
                            foregroundColor: colors.onSecondaryContainer,
                            onTap: _abrirEntregas,
                          ),
                        ),
                        Expanded(
                          child: _cardEstatistica(
                            icon: Icons.payments_outlined,
                            titulo: 'Ganho\nHoje',
                            valor:
                                'R\$ ${ganhoHoje.toStringAsFixed(2).replaceAll('.', ',')}',
                            backgroundColor: colors.tertiaryContainer,
                            foregroundColor: colors.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      "Últimas Entregas",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: ultimasEntregas.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text("Nenhuma baixa registrada"),
                                  ),
                                ]
                              : ultimasEntregas.map((pacote) {
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.check_circle),
                                    title: Text(pacote.codigo),
                                    subtitle: Text(
                                      pacote.transportadora ??
                                          "Sem transportadora",
                                    ),
                                    trailing: Icon(
                                      Icons.check_circle,
                                      color: colors.primary,
                                    ),
                                  );
                                }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _resumoDoDia(
                      entregasHoje: entregasHoje,
                      ganhoHoje: ganhoHoje,
                      fotosPendentes: fotosPendentes,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear'),
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
