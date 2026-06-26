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
          home: const HomePage(),
        );
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
  bool carregando = true;

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
      final snapshot = await FirebaseFirestore.instance
          .collection('entregas')
          .orderBy('dataLeitura', descending: true)
          .get();

      listaPacotes.clear();

      for (final doc in snapshot.docs) {
        final dados = doc.data();
        final dataFirebase = dados['dataLeitura'];

        listaPacotes.add(
          Pacote(
            codigo: dados['codigo'] ?? '',
            transportadora: dados['transportadora'] ?? '',
            dataLeitura: dataFirebase is Timestamp
                ? dataFirebase.toDate()
                : DateTime.now(),
            nomeRecebedor: dados['recebedor'] ?? '',
            fotoPath: dados['fotoPath'],
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

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();

    final entregasHoje = listaPacotes.where((p) {
      return p.entregue && _mesmoDia(p.dataLeitura, hoje);
    }).length;

    final totalBaixas = listaPacotes.where((p) => p.entregue).length;
    final ganhoHoje = entregasHoje * 3;

    final ultimasEntregas =
        listaPacotes.where((p) => p.entregue).take(5).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Entrega App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
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
                                    'R\$ $ganhoHoje',
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

                    const SizedBox(height: 25),
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
          height: 70,
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