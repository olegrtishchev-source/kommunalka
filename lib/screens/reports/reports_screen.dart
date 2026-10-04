import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/app_database.dart';
import '../../models/payment.dart';
import '../../models/receipt.dart';
import '../../models/supplier.dart';
import '../../providers/excel_report_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/receipt_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/yandex_disk_provider.dart';
import '../../services/excel_report_service.dart';
import '../../services/yandex_disk_service.dart';
import '../../utils/date_format.dart';

/// Отчёты (ТЗ §4.10) — вкладка «Отчёты» нижней навигации (4.9). Выбор
/// периода, статус авторизации Яндекс Диска, кнопка «Сформировать и
/// выгрузить».
///
/// Сборка данных отчёта (Supplier/Payment из PaymentRow/SupplierRow,
/// ссылка на чек — ReceiptRepository.getUrl с длинным сроком действия,
/// 30 дней, отчёт может пролежать нескачанным дольше, чем обычная
/// ссылка в приложении) — как раз то, что ExcelReportService (3.10) по
/// своему doc-комментарию сознательно оставил экрану Этапа 4.
///
/// Папка на Диске — '/Коммуналка' (по имени приложения) — в ТЗ имя
/// папки не зафиксировано, выбрано как разумное значение по умолчанию.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  static const _yandexFolderPath = '/Коммуналка';

  static const _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
  ];

  /// Папка периода на Диске — «/Коммуналка/<Месяц>_<Год>», напр.
  /// «/Коммуналка/Октябрь_2026» (Этап 5.7).
  String get _periodFolderPath =>
      '$_yandexFolderPath/${_monthNames[_period.month - 1]}_${_period.year}';

  late DateTime _period;
  String? _yandexToken;
  bool _loadingToken = true;
  bool _connecting = false;
  bool _generating = false;
  String? _error;
  String? _successMessage;
  /// Прогресс копирования чеков на Диск (Этап 5.7) — показывается во время
  /// выгрузки: «Копирую чеки: N из M».
  String? _copyProgress;

  /// Публичная ссылка на файл последнего выгруженного отчёта — по нажатию
  /// на запись об отчёте открывается в браузере/приложении Яндекс Диска.
  String? _lastReportUrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTime(now.year, now.month, 1);
    _loadToken();
  }

  Future<void> _loadToken() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!mounted) return;
    setState(() {
      _yandexToken = settings.yandexAccessToken;
      _loadingToken = false;
    });
  }

  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Выберите любой день нужного месяца',
    );
    if (picked != null) {
      setState(() => _period = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _connectYandex() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final token = await ref.read(yandexDiskServiceProvider).authorize();
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setYandexAccessToken(token);
      if (!mounted) return;
      setState(() => _yandexToken = token);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnectYandex() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.clearYandexAccessToken();
    if (!mounted) return;
    setState(() => _yandexToken = null);
  }

  Payment _paymentFromRow(PaymentRow r) {
    final snapshotJson = r.readingSnapshot;
    return Payment(
      id: r.id,
      userId: r.userId,
      supplierId: r.supplierId,
      period: r.period,
      readingSnapshot: snapshotJson == null
          ? null
          : (jsonDecode(snapshotJson) as List<dynamic>)
              .map((e) => ReadingSnapshotEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
      consumption: r.consumption,
      calculatedAmount: r.calculatedAmount,
      actualAmount: r.actualAmount,
      status: PaymentStatus.fromDb(r.status),
      paymentDate: r.paymentDate,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  Supplier _supplierFromRow(SupplierRow r) {
    return Supplier(
      id: r.id,
      userId: r.userId,
      name: r.name,
      category: r.category,
      type: SupplierType.fromDb(r.type),
      archivedAt: r.archivedAt,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }

  /// Подтверждение «Закрытия месяца» (п. 5.7): если по части активных
  /// поставщиков за период нет платежа, показать их список и спросить,
  /// формировать ли отчёт без них. true — продолжить, false — отмена.
  Future<bool?> _confirmCloseMonth(List<String> missingNames) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Не все поставщики оплачены'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('За выбранный период нет платежа по поставщикам:'),
            const SizedBox(height: 8),
            ...missingNames.map((name) => Text('• $name')),
            const SizedBox(height: 8),
            const Text('Сформировать отчёт без них?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  /// Очищает имя поставщика от символов, недопустимых в имени файла.
  String _safeFileName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  /// Открывает ссылку во внешнем браузере/приложении (Яндекс Диск и т.п.).
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Пытается получить публичную ссылку на файл (publish + public_url — она
  /// открывает сам файл). Если у токена нет прав на чтение метаданных
  /// (403 Forbidden — приложению не выдано «Чтение всего Диска»), откатывается
  /// на клиентскую ссылку (открывает файл в приложении Диска у владельца).
  Future<String> _publicOrFallbackUrl(
    YandexDiskService yandex,
    String token,
    String remotePath,
  ) async {
    try {
      return await yandex.getPublicUrl(
        accessToken: token,
        remotePath: remotePath,
      );
    } catch (e) {
      debugPrint('[Отчёт] публичная ссылка недоступна ($e), '
          'использую клиентскую ссылку');
      return yandex.fileClientUrl(remotePath);
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _generateAndUpload() async {
    final token = _yandexToken;
    if (token == null) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    // _successMessage НЕ сбрасываем здесь: если пользователь нажмёт
    // «Отмена» в диалоге закрытия месяца, прежняя запись об отчёте должна
    // остаться на экране (баг 2.2).
    try {
      final supplierRepo = ref.read(supplierRepositoryProvider);
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final receiptRepo = ref.read(receiptRepositoryProvider);

      await supplierRepo.refresh();
      await paymentRepo.refresh();

      final suppliers = await supplierRepo.watchAll().first;
      final suppliersById = {for (final s in suppliers) s.id: s};

      final allPayments = await paymentRepo.watchAll().first;
      final periodPayments = allPayments
          .where((p) => p.period.year == _period.year && p.period.month == _period.month)
          .toList();

      // «Закрытие месяца» (п. 5.7): проверка, что по всем активным
      // поставщикам за период есть платёж. Если есть «дыры» — показать
      // список и дать выбор (сформировать без них или отменить).
      final activeSuppliers = await supplierRepo.watchActive().first;
      final missing = activeSuppliers
          .where((s) => !periodPayments.any((p) => p.supplierId == s.id))
          .toList();
      if (missing.isNotEmpty) {
        final proceed = await _confirmCloseMonth(
          missing.map((s) => s.name).toList(),
        );
        if (proceed != true) {
          // Отмена — не трогаем прежнюю запись об отчёте и не запускаем
          // выгрузку.
          if (mounted) setState(() => _generating = false);
          return;
        }
      }

      // Пользователь подтвердил выгрузку — теперь можно сбросить прежнее
      // сообщение об отчёте.
      if (mounted) setState(() => _successMessage = null);

      // Сначала соберём чеки периода (для копирования на Диск) и строки
      // отчёта. Чеки скачиваются из Supabase Storage, копируются в папку
      // периода на Диске (Этап 5.7); ссылка в Excel ведёт на Диск (постоянная).
      final validPayments = periodPayments
          .where((p) => suppliersById[p.supplierId]?.archivedAt == null)
          .toList();

      // Все чеки выбранных платежей (можно несколько на платёж).
      final rows = <ExcelReportRow>[];
      var copiedCount = 0;
      for (final paymentRow in validPayments) {
        final supplierRow = suppliersById[paymentRow.supplierId]!;
        final supplier = _supplierFromRow(supplierRow);
        final payment = _paymentFromRow(paymentRow);

        final receipts =
            await receiptRepo.watchForPayment(paymentRow.id).first;
        String? receiptUrl;
        // Копируем чеки на Диск в папку периода и берём публичную ссылку
        // (на файл, а не на папку) для отчёта. Если чеков несколько —
        // предпочитаем PDF. Ошибка копирования одного чека не срывает отчёт.
        final yandex = ref.read(yandexDiskServiceProvider);
        for (var i = 0; i < receipts.length; i++) {
          final receipt = receipts[i];
          final isPdf = receipt.filePath.toLowerCase().endsWith('.pdf');
          final ext = isPdf ? 'pdf' : 'jpg';
          final suffix = receipts.length > 1 ? '_${i + 1}' : '';
          final fileName =
              'Чек_${_safeFileName(supplierRow.name)}_'
              '${_two(paymentRow.paymentDate?.day ?? paymentRow.period.day)}.'
              '${_two(paymentRow.paymentDate?.month ?? paymentRow.period.month)}.'
              '${paymentRow.paymentDate?.year ?? paymentRow.period.year}'
              '$suffix.$ext';
          final remotePath = '$_periodFolderPath/$fileName';
          try {
            final bytes = await receiptRepo.download(
              Receipt(
                id: receipt.id,
                paymentId: receipt.paymentId,
                filePath: receipt.filePath,
                createdAt: receipt.createdAt,
              ),
            );
            await yandex.uploadFile(
              accessToken: token,
              folderPath: _periodFolderPath,
              fileName: fileName,
              bytes: bytes,
            );
            final publicUrl = await _publicOrFallbackUrl(
              yandex,
              token,
              remotePath,
            );
            copiedCount++;
            if (mounted) {
              setState(() => _copyProgress = 'Копирую чеки: $copiedCount');
            }
            // PDF-чек приоритетнее для ссылки в отчёте.
            if (receiptUrl == null || isPdf) {
              receiptUrl = publicUrl;
            }
          } catch (e) {
            // копирование чека не критично для отчёта — пропускаем, но
            // пишем причину в лог.
            debugPrint('[Отчёт] ОШИБКА копирования чека '
                '(${supplierRow.name}, $fileName): $e');
          }
        }

        rows.add(
          ExcelReportRow.fromPaymentAndSupplier(
            supplier,
            payment,
            receiptUrl: receiptUrl,
          ),
        );
      }

      final excelService = ref.read(excelReportServiceProvider);
      final bytes = excelService.generate(period: _period, rows: rows);
      final fileName = excelService.suggestedFileName(_period);

      final yandexSvc = ref.read(yandexDiskServiceProvider);
      await yandexSvc.uploadFile(
            accessToken: token,
            folderPath: _periodFolderPath,
            fileName: fileName,
            bytes: bytes,
          );

      // Ссылка на сам файл отчёта (кликабельна на экране).
      final reportUrl = await _publicOrFallbackUrl(
        yandexSvc,
        token,
        '$_periodFolderPath/$fileName',
      );

      if (!mounted) return;
      setState(() {
        _copyProgress = null;
        _lastReportUrl = reportUrl;
        _successMessage = 'Отчёт «$fileName» выгружен на Яндекс Диск';
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Период', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(formatPeriod(_period)),
                TextButton(onPressed: _pickPeriod, child: const Text('Изменить')),
              ],
            ),
            const SizedBox(height: 20),
            Text('Яндекс Диск', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loadingToken)
              const CircularProgressIndicator()
            else if (_yandexToken == null)
              OutlinedButton.icon(
                onPressed: _connecting ? null : _connectYandex,
                icon: const Icon(Icons.login),
                label: Text(_connecting ? 'Вход...' : 'Войти в Яндекс Диск'),
              )
            else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  const Text('Подключён'),
                  const Spacer(),
                  TextButton(
                    onPressed: _disconnectYandex,
                    child: const Text('Отключить'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Кликабельная ссылка на папку периода на Диске (открывается
              // во внешнем приложении/браузере Яндекс Диска).
              OutlinedButton.icon(
                onPressed: () => _openUrl(
                  ref.read(yandexDiskServiceProvider).fileClientUrl(_periodFolderPath),
                ),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Открыть папку на Диске'),
              ),
            ],
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            if (_successMessage != null) ...[
              if (_lastReportUrl != null)
                InkWell(
                  onTap: () => _openUrl(_lastReportUrl!),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(
                      color: Colors.green,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.green,
                    ),
                  ),
                )
              else
                Text(_successMessage!, style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
            ],
            if (_copyProgress != null) ...[
              Text(_copyProgress!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: (_yandexToken == null || _generating) ? null : _generateAndUpload,
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_generating ? 'Формирование...' : 'Сформировать и выгрузить'),
            ),
          ],
        ),
      ),
    );
  }
}
