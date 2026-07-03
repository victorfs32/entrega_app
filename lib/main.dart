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
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

List<Pacote> listaPacotes = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});

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
          title: 'Entrega App',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('pt', 'BR'),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const AuthCheckPage(),
        );
      },
    );
  }
}
    class AuthCheckPage extends StatelessWidget {
      const AuthCheckPage({super.key});

      @override
      Widget build(BuildContext context) {
        final usuario = FirebaseAuth.instance.currentUser;

        if (usuario != null) {
          return const HomePage();
        }

        return const LoginPage();
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
        final cargo =
            dados['admin'] == true ? 'Administrador' : 'Motorista';

        return Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue,
              child: Text(
                _iniciais(nome),
                style: const TextStyle(
                  color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.grey,
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
      });
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar entregas: $e'),
        ),
      );
    }
  }

  Future<void> _abrirScanner() async {
    final codigo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerPage(),
      ),
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
      MaterialPageRoute(
        builder: (_) => const EntregasPage(),
      ),
    );
  }

  void _abrirMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MenuPage(),
      ),
    );
  }

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

      Widget _resumoDoDia({
      required int entregasHoje,
      required double ganhoHoje,
      required int fotosPendentes,
    }) {
      const int metaDia = 80;
      final progresso = entregasHoje / metaDia;
      final porcentagem = (progresso * 100).clamp(0, 100).toInt();
      final faltam = (metaDia - entregasHoje).clamp(0, metaDia);

      return Card(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumo do dia',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text('$entregasHoje entregas'),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.green),
                  const SizedBox(width: 10),
                  Text('R\$ ${ganhoHoje.toStringAsFixed(2).replaceAll('.', ',')}'),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text('Fotos pendentes: $fotosPendentes'),
                ],
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

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progresso.clamp(0, 1),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade300,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                faltam == 0
                    ? '🎉 Meta concluída!'
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

    final ultimasEntregas =
        listaPacotes.where((p) => p.entregue).take(5).toList();

    final fotosPendentes = listaPacotes.where((p) {
      return p.entregue && p.fotoUrl == null;}).length;

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

                    const SizedBox(height: 25,),

                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF1E293B)
                                : Colors.blue.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '$totalBaixas',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Total\nBaixas',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _abrirEntregas,
                            child: Card(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.green.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      '$entregasHoje',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Entregas\nHoje',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: Card(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? const Color(0xFF1E293B)
                                : Colors.orange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'R\$ ${ganhoHoje.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'Ganho\nHoje',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Últimas Entregas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Card(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: ultimasEntregas.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text("Nenhuma baixa registrada"),
                                  )
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
                                    trailing: const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirScanner,
        backgroundColor: Colors.blue,
        elevation: 8,
        child: const Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
          size: 32,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home),
                  Text("Início"),
                ],
              ),
              const SizedBox(width: 50),
              InkWell(
                onTap: _abrirMenu,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu),
                    Text("Menu"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}