import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/app_database.dart';
import '../../models/receipt.dart';
import '../../providers/receipt_provider.dart';
import '../../utils/date_format.dart';

/// Прикрепление чека (ТЗ §4.5, схема §2.5: /payments/:paymentId/receipt) —
/// отдельное необязательное действие: доступно сразу после ввода оплаты
/// (кнопка на экране «Оплата», 4.4) и позже, когда появится история
/// (4.6/4.7). Можно прикрепить больше одного файла — ТЗ не ограничивает
/// количество на платёж.
///
/// Фото — с камеры или из галереи (image_picker); PDF-чек (его выдаёт
/// банковское приложение) — из файловой системы (file_picker, Этап 5.8).
/// Сжатие до ~500 КБ и загрузка в приватный бакет Storage — в
/// ReceiptRepository (Этап 3.8); PDF не сжимается (грузится как есть).
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(receiptRepositoryProvider).refresh());
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return; // пользователь отменил выбор
      final bytes = await file.readAsBytes();
      await ref.read(receiptRepositoryProvider).attach(
            paymentId: widget.paymentId,
            bytes: bytes,
          );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Прикрепление PDF-чека из файловой системы (банк выдаёт чек в PDF).
  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return; // пользователь отменил выбор
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await files.first.readAsBytes();
      await ref.read(receiptRepositoryProvider).attach(
            paymentId: widget.paymentId,
            bytes: bytes,
            isPdf: true,
          );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _open(ReceiptRow row) async {
    try {
      final url = await ref.read(receiptRepositoryProvider).getUrl(
            Receipt(
              id: row.id,
              paymentId: row.paymentId,
              filePath: row.filePath,
              createdAt: row.createdAt,
            ),
          );
      final uri = Uri.parse(url);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() => _error = 'Не удалось открыть ссылку на чек.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptRepo = ref.watch(receiptRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Чек об оплате')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Камера'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Галерея'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Файл (PDF)'),
              ),
            ),
            if (_uploading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Text('Прикреплённые чеки', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<ReceiptRow>>(
                stream: receiptRepo.watchForPayment(widget.paymentId),
                builder: (context, snapshot) {
                  final receipts = snapshot.data ?? const [];
                  if (receipts.isEmpty) {
                    return const Text('Чеков пока нет.');
                  }
                  return ListView.builder(
                    itemCount: receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      return ListTile(
                        leading: const Icon(Icons.receipt_outlined),
                        title: Text(formatDate(receipt.createdAt)),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => _open(receipt),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
