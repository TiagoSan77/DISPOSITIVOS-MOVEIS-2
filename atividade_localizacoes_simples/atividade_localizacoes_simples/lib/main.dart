import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(const MeuApp());

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localizações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  Database? banco;
  StreamSubscription<Position>? assinatura;
  bool coletando = false;
  String mensagem = 'Coleta parada';

  @override
  void initState() {
    super.initState();
    _abrirBanco();
  }

  Future<void> _abrirBanco() async {
    final caminho = p.join(await getDatabasesPath(), 'localizacoes.db');
    banco = await openDatabase(
      caminho,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE localizacoes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          precisao REAL NOT NULL,
          instante TEXT NOT NULL
        )
      '''),
    );
    if (mounted) setState(() {});
  }

  Future<bool> _pedirPermissao() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _avisar('Ligue o GPS do aparelho.');
      return false;
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      _avisar('Permita o acesso à localização nas configurações.');
      return false;
    }
    return true;
  }

  Future<void> _iniciar() async {
    if (coletando || banco == null) return;
    if (!await _pedirPermissao()) return;

    const configAndroid = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: Duration(seconds: 20),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'Coleta de localização ativa',
        notificationText: 'Registrando posições do aparelho',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    assinatura = Geolocator.getPositionStream(
      locationSettings: configAndroid,
    ).listen((posicao) async {
      await banco!.insert('localizacoes', {
        'latitude': posicao.latitude,
        'longitude': posicao.longitude,
        'precisao': posicao.accuracy,
        'instante': posicao.timestamp.toUtc().toIso8601String(),
      });
      if (mounted) {
        setState(() {
          mensagem = 'Última posição: ${posicao.latitude.toStringAsFixed(5)}, '
              '${posicao.longitude.toStringAsFixed(5)}';
        });
      }
    }, onError: (erro) {
      if (mounted) _avisar('Erro na coleta: $erro');
    });

    setState(() {
      coletando = true;
      mensagem = 'Coleta ativa';
    });
  }

  Future<void> _parar() async {
    await assinatura?.cancel();
    assinatura = null;
    if (mounted) {
      setState(() {
        coletando = false;
        mensagem = 'Coleta parada';
      });
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<List<Map<String, Object?>>> _lerRegistros() async {
    if (banco == null) return [];
    return banco!.query('localizacoes', orderBy: 'instante DESC', limit: 100);
  }

  Future<void> _historico() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaHistorico(
          lerRegistros: _lerRegistros,
          banco: banco!,
          avisar: _avisar,
        ),
      ),
    );
  }

  Future<void> _mapa() async {
    final registros = await _lerRegistros();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TelaMapa(registros: registros)),
    );
  }

  @override
  void dispose() {
    assinatura?.cancel();
    banco?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coleta de localizações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.location_on, size: 64),
          Text(mensagem, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: coletando ? null : _iniciar,
            child: const Text('Iniciar coleta'),
          ),
          OutlinedButton(
            onPressed: coletando ? _parar : null,
            child: const Text('Parar coleta'),
          ),
          OutlinedButton(
            onPressed: banco == null ? null : _historico,
            child: const Text('Consultar histórico'),
          ),
          OutlinedButton(
            onPressed: banco == null ? null : _mapa,
            child: const Text('Ver mapa'),
          ),
          OutlinedButton(
            onPressed: Geolocator.openAppSettings,
            child: const Text('Configurações de permissão'),
          ),
        ],
      ),
    );
  }
}

class TelaHistorico extends StatefulWidget {
  final Future<List<Map<String, Object?>>> Function() lerRegistros;
  final Database banco;
  final void Function(String) avisar;

  const TelaHistorico({
    super.key,
    required this.lerRegistros,
    required this.banco,
    required this.avisar,
  });

  @override
  State<TelaHistorico> createState() => _TelaHistoricoState();
}

class _TelaHistoricoState extends State<TelaHistorico> {
  late Future<List<Map<String, Object?>>> registros;

  @override
  void initState() {
    super.initState();
    registros = widget.lerRegistros();
  }

  void _atualizar() => setState(() => registros = widget.lerRegistros());

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todos os registros serão apagados permanentemente. '
          'Se a coleta estiver ativa, novas posições continuarão sendo salvas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar histórico'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await widget.banco.delete('localizacoes');
      if (!mounted) return;
      _atualizar();
      widget.avisar('Histórico apagado.');
    } catch (e) {
      widget.avisar('Erro ao apagar histórico: $e');
    }
  }

  String _dataLocal(String texto) {
    final d = DateTime.parse(texto).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: registros,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data!;
          if (lista.isEmpty) {
            return const Center(child: Text('Nenhuma localização salva.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _atualizar(),
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final item = lista[i];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(_dataLocal(item['instante'] as String)),
                  subtitle: Text(
                    'Lat: ${(item['latitude'] as num).toDouble().toStringAsFixed(6)} | '
                    'Long: ${(item['longitude'] as num).toDouble().toStringAsFixed(6)}\n'
                    'Precisão: ${(item['precisao'] as num).toDouble().toStringAsFixed(1)} m',
                  ),
                  isThreeLine: true,
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _atualizar, child: const Text('Atualizar'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _limpar, child: const Text('Limpar histórico'))),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaMapa extends StatelessWidget {
  final List<Map<String, Object?>> registros;

  const TelaMapa({super.key, required this.registros});

  @override
  Widget build(BuildContext context) {
    final pontos = registros.map((r) => LatLng(
      (r['latitude'] as num).toDouble(),
      (r['longitude'] as num).toDouble(),
    )).toList();
    final centro = pontos.isEmpty ? const LatLng(-23.2237, -45.9009) : pontos.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa')),
      body: pontos.isEmpty
          ? const Center(child: Text('Nenhuma localização salva.'))
          : FlutterMap(
              options: MapOptions(initialCenter: centro, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'br.com.atividade.localizacoes',
                ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < pontos.length; i++)
                      Marker(
                        point: pontos[i],
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          color: i == 0 ? Colors.red : Colors.teal,
                          size: i == 0 ? 40 : 32,
                        ),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                ),
              ],
            ),
    );
  }
}
