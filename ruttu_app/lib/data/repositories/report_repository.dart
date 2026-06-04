import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../models/report_model.dart';

// ── Abstract ─────────────────────────────────────────────────────────────────
abstract class ReportRepository {
  Future<List<WeeklyReportModel>>  getWeeklyReport();
  Future<List<MonthlyReportModel>> getMonthlyReport();
}

// ── API 구현체 ─────────────────────────────────────────────────────────────────
class ApiReportRepository implements ReportRepository {
  final Dio _dio;
  ApiReportRepository(this._dio);

  @override
  Future<List<WeeklyReportModel>> getWeeklyReport() async {
    final res = await _dio.get(ApiConstants.weeklyReport);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => WeeklyReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<MonthlyReportModel>> getMonthlyReport() async {
    final res = await _dio.get(ApiConstants.monthlyReport);
    final list = res.data as List<dynamic>;
    return list
        .map((e) => MonthlyReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
