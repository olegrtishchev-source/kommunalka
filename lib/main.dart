import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database/app_database.dart';

/// Спайк Этапа 1 — проверка связи Flutter ↔ Supabase (облако) и
/// Flutter ↔ drift (локальная БД) на Android.
/// Publishable key безопасен для клиентского кода (не секрет).
const supabaseUrl = 'https://jvroshiynvwrjzzztfsx.supabase.co';
const supabasePublishableKey = 'sb_publishable_IpDeMNLn5LQjl8DqBUw5Dw_yHPeTWzx';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const SpikeApp());
}

final supabase = Supabase.instance.client;
final database = AppDatabase();

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase + drift spike',
      home: const SpikeScreen(),
    );
  }
}

class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await supabase
          .from('spike_test')
          .select()
          .order('created_at');
      setState(() {
        _rows = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addRow() async {
    await supabase.from('spike_test').insert({
      'note': 'запись с ${Platform.operatingSystem} · ${DateTime.now()}',
    });
    await _refresh();
  }

  Future<void> _addLocalRow() async {
    await database.into(database.spikeLocal).insert(
          SpikeLocalCompanion.insert(
            note: 'локальная запись · ${DateTime.now()}',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase + drift spike')),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text('Ошибка: $_error'))
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _rows.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Supabase: записей нет. Нажмите + или потяните вниз.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                itemCount: _rows.length,
                                itemBuilder: (context, index) {
                                  final row = _rows[index];
                                  return ListTile(
                                    leading: const Icon(Icons.cloud),
                                    title: Text(row['note']?.toString() ?? ''),
                                    subtitle:
                                        Text(row['created_at']?.toString() ?? ''),
                                  );
                                },
                              ),
                      ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Локально (drift)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addLocalRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить локально'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<SpikeLocalData>>(
                    stream: database.select(database.spikeLocal).watch(),
                    builder: (context, snapshot) {
                      final rows = snapshot.data ?? [];
                      if (rows.isEmpty) {
                        return const Center(child: Text('Локальных записей нет.'));
                      }
                      return ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return ListTile(
                            leading: const Icon(Icons.storage),
                            title: Text(row.note),
                            subtitle: Text(row.createdAt.toString()),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        tooltip: 'Добавить запись в Supabase',
        child: const Icon(Icons.cloud_upload),
      ),
    );
  }
}
