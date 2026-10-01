import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../utils/date_format.dart';

/// Отчёты (ТЗ §4.10) — вкладка «Отчёты» нижней навигации (4.9). Выбор
/// периода, статус авторизации Яндекс.Диска, кнопка «Сформировать и
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

  late DateTime _period;
  String? _yandexToken;
  bool _loadingToken = true;
  bool _connecting = false;
  bool _generating = false;
  String? _error;
  String? _successMessage;

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

  Future<void> _generateAndUpload() async {
    final token = _yandexToken;
    if (token == null) return;
    setState(() {
      _generating = true;
      _error = null;
      _successMessage = null;
    });
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

      final rows = <ExcelReportRow>[];
      for (final paymentRow in periodPayments) {
        final supplierRow = suppliersById[paymentRow.supplierId];
        if (supplierRow == null) continue;

        final receipts = await receiptRepo.watchForPayment(paymentRow.id).first;
        String? receiptUrl;
        if (receipts.isNotEmpty) {
          final receipt = receipts.first;
          receiptUrl = await receiptRepo.getUrl(
            Receipt(
              id: receipt.id,
              paymentId: receipt.paymentId,
              filePath: receipt.filePath,
              createdAt: receipt.createdAt,
            ),
            expiresInSeconds: 30 * 24 * 3600,
          );
        }

        rows.add(
          ExcelReportRow.fromPaymentAndSupplier(
            _supplierFromRow(supplierRow),
            _paymentFromRow(paymentRow),
            receiptUrl: receiptUrl,
          ),
        );
      }

      final excelService = ref.read(excelReportServiceProvider);
      final bytes = excelService.generate(period: _period, rows: rows);
      final fileName = excelService.suggestedFileName(_period);

      await ref.read(yandexDiskServiceProvider).uploadFile(
            accessToken: token,
            folderPath: _yandexFolderPath,
            fileName: fileName,
            bytes: bytes,
          );

      if (!mounted) return;
      setState(() => _successMessage = 'Отчёт «$fileName» выгружен на Яндекс.Диск.');
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
            Text('Яндекс.Диск', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_loadingToken)
              const CircularProgressIndicator()
            else if (_yandexToken == null)
              OutlinedButton.icon(
                onPressed: _connecting ? null : _connectYandex,
                icon: const Icon(Icons.login),
                label: Text(_connecting ? 'Вход...' : 'Войти в Яндекс.Диск'),
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  const Text('Подключён'),
                  const Spacer(),
                  TextButton(onPressed: _disconnectYandex, child: const Text('Отключить')),
                ],
              ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            if (_successMessage != null) ...[
              Text(_successMessage!, style: const TextStyle(color: Colors.green)),
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
