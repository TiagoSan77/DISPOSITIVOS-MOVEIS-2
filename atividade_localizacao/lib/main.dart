
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localizações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
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
  bool carregando = true;
  String mensagem = 'Coleta parada';

  @override
  void initState() {
    super.initState();
    _abrirBanco();
  }

  Future<void> _abrirBanco() async {
    try {
      final caminho = p.join(
        await getDatabasesPath(),
        'localizacoes.db',
      );

      banco = await openDatabase(
        caminho,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE localizacoes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              precisao REAL NOT NULL,
              instante TEXT NOT NULL
            )
          ''');
        },
      );

      if (mounted) {
        setState(() {
          carregando = false;
          mensagem = 'Banco de dados pronto. Coleta parada.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          carregando = false;
          mensagem = 'Erro ao abrir o banco: $e';
        });
      }
    }
  }

  Future<bool> _pedirPermissao() async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();

    if (!servicoAtivo) {
      _avisar('Ative o GPS do celular.');
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permissao =
        await Geolocator.checkPermission();

    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      _avisar(
        'Permita a localização nas configurações do aplicativo.',
      );

      if (permissao == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }

      return false;
    }

    return true;
  }

  Future<void> _iniciar() async {
    if (coletando || carregando || banco == null) return;

    try {
      final permitido = await _pedirPermissao();
      if (!permitido || !mounted) return;

      final configAndroid = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 20),
        foregroundNotificationConfig:
            const ForegroundNotificationConfig(
          notificationTitle: 'Coleta de localização ativa',
          notificationText: 'Registrando posições do aparelho',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

      setState(() {
        coletando = true;
        mensagem = 'Iniciando coleta de localização...';
      });

      assinatura = Geolocator.getPositionStream(
        locationSettings: configAndroid,
      ).listen(
        (Position posicao) async {
          try {
            await banco?.insert('localizacoes', {
              'latitude': posicao.latitude,
              'longitude': posicao.longitude,
              'precisao': posicao.accuracy,
              'instante': posicao.timestamp
                  .toUtc()
                  .toIso8601String(),
            });

            if (mounted) {
              setState(() {
                mensagem =
                    'Última posição:\n'
                    '${posicao.latitude.toStringAsFixed(6)}, '
                    '${posicao.longitude.toStringAsFixed(6)}\n'
                    'Precisão: ${posicao.accuracy.toStringAsFixed(1)} m';
              });
            }
          } catch (e) {
            if (mounted) {
              _avisar('Erro ao salvar posição: $e');
            }
          }
        },
        onError: (Object erro) {
          if (mounted) {
            _avisar('Erro na coleta: $erro');
            setState(() {
              coletando = false;
              mensagem = 'Erro durante a coleta.';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          coletando = false;
          mensagem = 'Não foi possível iniciar a coleta.';
        });
        _avisar('Erro ao iniciar: $e');
      }
    }
  }

  Future<void> _parar() async {
    await assinatura?.cancel();
    assinatura = null;

    if (mounted) {
      setState(() {
        coletando = false;
        mensagem = 'Coleta parada.';
      });
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  Future<List<Map<String, Object?>>> _lerRegistros() async {
    if (banco == null) return [];

    return banco!.query(
      'localizacoes',
      orderBy: 'instante DESC',
      limit: 100,
    );
  }

  Future<void> _historico() async {
    if (banco == null) return;

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
      MaterialPageRoute(
        builder: (_) => TelaMapa(registros: registros),
      ),
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
      appBar: AppBar(
        title: const Text('Coleta de localizações'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.location_on,
            size: 72,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          Text(
            mensagem,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (carregando)
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                carregando || coletando ? null : _iniciar,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar coleta'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: coletando ? _parar : null,
            icon: const Icon(Icons.stop),
            label: const Text('Parar coleta'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: carregando ? null : _historico,
            icon: const Icon(Icons.history),
            label: const Text('Consultar histórico'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: carregando ? null : _mapa,
            icon: const Icon(Icons.map),
            label: const Text('Ver mapa'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: Geolocator.openAppSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Configurações de permissão'),
          ),
        ],
      ),
    );
  }
}

class TelaHistorico extends StatefulWidget {
  final Future<List<Map<String, Object?>>> Function()
      lerRegistros;
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

  Future<void> _atualizar() async {
    setState(() {
      registros = widget.lerRegistros();
    });
    await registros;
  }

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'Todos os registros salvos serão apagados. '
          'A coleta ativa continuará registrando novas posições.',
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

      await _atualizar();
      widget.avisar('Histórico apagado.');
    } catch (e) {
      widget.avisar('Erro ao apagar histórico: $e');
    }
  }

  String _dataLocal(String texto) {
    final data = DateTime.parse(texto).toLocal();

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year} '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}:'
        '${data.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: registros,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar histórico: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final lista = snapshot.data!;

          if (lista.isEmpty) {
            return const Center(
              child: Text('Nenhuma localização salva.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _atualizar,
            child: ListView.builder(
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final item = lista[i];

                final latitude =
                    (item['latitude'] as num).toDouble();
                final longitude =
                    (item['longitude'] as num).toDouble();
                final precisao =
                    (item['precisao'] as num).toDouble();

                return ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Colors.teal,
                  ),
                  title: Text(
                    _dataLocal(item['instante'] as String),
                  ),
                  subtitle: Text(
                    'Latitude: ${latitude.toStringAsFixed(6)}\n'
                    'Longitude: ${longitude.toStringAsFixed(6)}\n'
                    'Precisão: ${precisao.toStringAsFixed(1)} m',
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
              Expanded(
                child: OutlinedButton(
                  onPressed: _atualizar,
                  child: const Text('Atualizar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _limpar,
                  child: const Text('Limpar histórico'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaMapa extends StatelessWidget {
  final List<Map<String, Object?>> registros;

  const TelaMapa({
    super.key,
    required this.registros,
  });

  @override
  Widget build(BuildContext context) {
    final pontos = registros.map((registro) {
      return LatLng(
        (registro['latitude'] as num).toDouble(),
        (registro['longitude'] as num).toDouble(),
      );
    }).toList();

    final centro = pontos.isEmpty
        ? const LatLng(-23.2237, -45.9009)
        : pontos.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de localizações'),
      ),
      body: pontos.isEmpty
          ? const Center(
              child: Text('Nenhuma localização salva.'),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: centro,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'br.com.atividade.localizacoes',
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
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
