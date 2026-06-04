import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/report_model.dart';
import '../../../data/repositories/report_repository.dart';
import '../../auth/providers/network_provider.dart';

// ── Repository Provider ───────────────────────────────────────────────────────
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ApiReportRepository(ref.read(apiClientProvider).dio),
);

// ── State ─────────────────────────────────────────────────────────────────────
class ReportState {
  final List<WeeklyReportModel>  weeklyList;
  final List<MonthlyReportModel> monthlyList;
  final bool   isLoadingWeekly;
  final bool   isLoadingMonthly;
  final String? weeklyError;
  final String? monthlyError;

  /// 현재 화면에서 선택된 인덱스 (좌우 네비게이터)
  final int weeklyIndex;
  final int monthlyIndex;

  const ReportState({
    this.weeklyList        = const [],
    this.monthlyList       = const [],
    this.isLoadingWeekly   = false,
    this.isLoadingMonthly  = false,
    this.weeklyError,
    this.monthlyError,
    this.weeklyIndex       = 0,
    this.monthlyIndex      = 0,
  });

  ReportState copyWith({
    List<WeeklyReportModel>?  weeklyList,
    List<MonthlyReportModel>? monthlyList,
    bool?   isLoadingWeekly,
    bool?   isLoadingMonthly,
    String? weeklyError,
    String? monthlyError,
    int?    weeklyIndex,
    int?    monthlyIndex,
    bool    clearWeeklyError  = false,
    bool    clearMonthlyError = false,
  }) =>
      ReportState(
        weeklyList:       weeklyList       ?? this.weeklyList,
        monthlyList:      monthlyList      ?? this.monthlyList,
        isLoadingWeekly:  isLoadingWeekly  ?? this.isLoadingWeekly,
        isLoadingMonthly: isLoadingMonthly ?? this.isLoadingMonthly,
        weeklyError:      clearWeeklyError  ? null : (weeklyError  ?? this.weeklyError),
        monthlyError:     clearMonthlyError ? null : (monthlyError ?? this.monthlyError),
        weeklyIndex:      weeklyIndex  ?? this.weeklyIndex,
        monthlyIndex:     monthlyIndex ?? this.monthlyIndex,
      );

  WeeklyReportModel?  get currentWeekly  =>
      weeklyList.isEmpty  ? null : weeklyList[weeklyIndex.clamp(0, weeklyList.length - 1)];
  MonthlyReportModel? get currentMonthly =>
      monthlyList.isEmpty ? null : monthlyList[monthlyIndex.clamp(0, monthlyList.length - 1)];
}

// ── Notifier ─────────────────────────────────────────────────────────────────
final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>(
  (ref) => ReportNotifier(ref.read(reportRepositoryProvider)),
);

class ReportNotifier extends StateNotifier<ReportState> {
  final ReportRepository _repo;
  ReportNotifier(this._repo) : super(const ReportState());

  // ── 주간 로드 ──────────────────────────────────────────────────────────────
  Future<void> loadWeekly() async {
    state = state.copyWith(isLoadingWeekly: true, clearWeeklyError: true);
    try {
      final list = await _repo.getWeeklyReport();
      // 최신 주차가 앞에 오도록 정렬
      list.sort((a, b) {
        final yearCmp = b.year.compareTo(a.year);
        if (yearCmp != 0) return yearCmp;
        return b.weekOfYear.compareTo(a.weekOfYear);
      });
      state = state.copyWith(
        weeklyList:       list,
        isLoadingWeekly:  false,
        weeklyIndex:      0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingWeekly: false,
        weeklyError:     e.toString(),
      );
    }
  }

  // ── 월간 로드 ──────────────────────────────────────────────────────────────
  Future<void> loadMonthly() async {
    state = state.copyWith(isLoadingMonthly: true, clearMonthlyError: true);
    try {
      final list = await _repo.getMonthlyReport();
      // 최신 월이 앞에 오도록 정렬
      list.sort((a, b) {
        final yearCmp = b.year.compareTo(a.year);
        if (yearCmp != 0) return yearCmp;
        return b.month.compareTo(a.month);
      });
      state = state.copyWith(
        monthlyList:      list,
        isLoadingMonthly: false,
        monthlyIndex:     0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMonthly: false,
        monthlyError:     e.toString(),
      );
    }
  }

  // ── 네비게이터 ─────────────────────────────────────────────────────────────
  void prevWeek()  { if (state.weeklyIndex  < state.weeklyList.length  - 1) state = state.copyWith(weeklyIndex:  state.weeklyIndex  + 1); }
  void nextWeek()  { if (state.weeklyIndex  > 0)                             state = state.copyWith(weeklyIndex:  state.weeklyIndex  - 1); }
  void prevMonth() { if (state.monthlyIndex < state.monthlyList.length - 1)  state = state.copyWith(monthlyIndex: state.monthlyIndex + 1); }
  void nextMonth() { if (state.monthlyIndex > 0)                             state = state.copyWith(monthlyIndex: state.monthlyIndex - 1); }
}
