import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reading_provider.dart';
import '../../providers/receipt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../services/backup_service.dart';
import '../../services/settings_service.dart';
import '../../utils/error_messages.dart';

/// Настройки (ТЗ §4.8) — вкладка «Настройки» нижней навигации (4.9).
///
/// Валюта и формат даты — только сохраняются и показываются здесь (по
/// решению Олега на этом пункте плана): вывод сумм/дат по всему остальному
/// приложению не переписан под них, там всё так же жёстко «₽» и
/// дд.мм.гггг — как раз выбраны значениями по умолчанию.
///
/// Включение/выключение локальных напоминаний о показаниях из ТЗ §4.8 —
/// сама эта функция ещё не реализована (Этап 7, п. 7.4, опционально),
/// поэтому переключатель показан отключённым с пояснением, а не спрятан
/// и не притворяется рабочим.
///
/// «Выход из аккаунта» — signOut(), дальше go_router сам уводит на /login
/// (redirect слушает authStateChanges, см. router.dart). «Очистка кеша» —
/// AppDatabase.clearCache() (удаляет строки, не таблицы) и затем refresh()
/// у всех репозиториев, чтобы кеш не остался пустым до следующего открытия
/// экранов.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _working = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить локальный кеш?'),
        content: const Text(
          'Локальные данные будут удалены и заново загружены из облака. '
          'Сами данные в облаке не затрагиваются.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await ref.read(appDatabaseProvider).clearCache();
      await Future.wait([
        ref.read(supplierRepositoryProvider).refresh(),
        ref.read(channelRepositoryProvider).refresh(),
        ref.read(readingRepositoryProvider).refresh(),
        ref.read(paymentRepositoryProvider).refresh(),
        ref.read(receiptRepositoryProvider).refresh(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Кеш очищен, данные загружены заново.')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Экспорт резервной копии (ТЗ §4.9): читает данные из Supabase, собирает
  /// JSON и предлагает сохранить/отправить файл через системное «Поделиться».
  Future<void> _exportBackup() async {
    setState(() => _working = true);
    try {
      final data = await ref.read(backupRepositoryProvider).exportData();
      if (data.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для экспорта.')),
        );
        return;
      }
      final json = buildBackup(
        suppliers: data.suppliers,
        channels: data.channels,
        readings: data.readings,
        payments: data.payments,
        exportedAt: DateTime.now(),
      );
      final stamp = _fileStamp(DateTime.now());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: 'kommunalka_backup_$stamp.json',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать: ${describeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Импорт резервной копии (ТЗ §4.9): выбор JSON-файла, разбор, подтверждение
  /// и запись в Supabase с последующей перезагрузкой локального кеша.
  Future<void> _importBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return; // пользователь отменил выбор
    final BackupData data;
    try {
      final bytes = await picked.first.readAsBytes();
      data = parseBackup(utf8.decode(bytes, allowMalformed: true));
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прочитать файл: ${describeError(e)}')),
      );
      return;
    }
    if (data.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В файле нет данных для импорта.')),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импортировать данные?'),
        content: Text(
          'Будет добавлено/обновлено: поставщиков — ${data.suppliers.length}, '
          'каналов — ${data.channels.length}, показаний — ${data.readings.length}, '
          'платежей — ${data.payments.length}.\n\n'
          'Записи с теми же идентификаторами перезапишут существующие.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Импортировать')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      final result = await ref.read(backupRepositoryProvider).importData(data);
      // Догружаем локальный кеш, чтобы изменения сразу отразились на экранах.
      await Future.wait([
        ref.read(supplierRepositoryProvider).refresh(),
        ref.read(channelRepositoryProvider).refresh(),
        ref.read(readingRepositoryProvider).refresh(),
        ref.read(paymentRepositoryProvider).refresh(),
        ref.read(receiptRepositoryProvider).refresh(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импорт завершён: записей — ${result.total}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось импортировать: ${describeError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Метка времени для имени файла: 20261007_1235.
  String _fileStamp(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
        data: (settings) => ListView(
          children: [
            ListTile(
              title: const Text('Валюта'),
              trailing: DropdownButton<String>(
                value: settings.currency,
                items: [
                  for (final c in SettingsService.currencyOptions)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  await settings.setCurrency(value);
                  setState(() {});
                },
              ),
            ),
            ListTile(
              title: const Text('Формат даты'),
              trailing: DropdownButton<String>(
                value: settings.dateFormat,
                items: [
                  for (final f in SettingsService.dateFormatOptions)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  await settings.setDateFormat(value);
                  setState(() {});
                },
              ),
            ),
            SwitchListTile(
              value: false,
              onChanged: null,
              title: const Text('Напоминания о внесении показаний'),
              subtitle: const Text('Появятся, когда будут реализованы локальные уведомления.'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Экспорт данных (JSON)'),
              subtitle: const Text('Сохранить резервную копию поставщиков, показаний и платежей'),
              enabled: !_working,
              onTap: _exportBackup,
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Импорт данных (JSON)'),
              subtitle: const Text('Восстановить данные из файла резервной копии'),
              enabled: !_working,
              onTap: _importBackup,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Очистить локальный кеш'),
              subtitle: const Text('Удалить локальные данные и загрузить их заново из облака'),
              enabled: !_working,
              onTap: _clearCache,
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Выйти из аккаунта'),
              enabled: !_working,
              onTap: _signOut,
            ),
            if (_working) const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
