import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/excel_report_service.dart';

final excelReportServiceProvider = Provider<ExcelReportService>((ref) {
  return ExcelReportService();
});
