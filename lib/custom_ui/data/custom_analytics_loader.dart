import '../../data/db.dart' as db;
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../../utils/analytics_average.dart';
import '../../utils/month_range.dart';

/// 扩展支持 vivo 钱包式 4 种维度的洞察报表数据加载器 (CustomAnalyticsLoader)
///
/// 涵盖：
/// 1. 'week' (周报：周一至周日 7 天走势与分类构成)；
/// 2. 'month' (月报：自然月/账本周期 走势与分类构成)；
/// 3. 'year' (年报：12 个月走势与分类构成)；
/// 4. 'custom' (自定义：快捷区间或任意指定日期走势与构成)；
///
/// 遵循核心原则：不破坏原有核心数据库与代码，复用 Riverpod 与 StatisticsRepository。
Future<Map<String, AnalyticsResult>> loadCustomAnalyticsViews(
  dynamic repo, {
  required int ledgerId,
  required String scope, // 'week', 'month', 'year', 'custom'
  required DateTime weekMonday,
  required DateTime selMonth,
  required int selYear,
  required DateTime customStart,
  required DateTime customEnd,
  required int startDay,
  DateTime? clock,
}) async {
  const types = ['expense', 'income', 'balance'];
  final results = await Future.wait(
    types.map((type) => _loadScopeData(
          repo,
          ledgerId: ledgerId,
          scope: scope,
          type: type,
          weekMonday: weekMonday,
          selMonth: selMonth,
          selYear: selYear,
          customStart: customStart,
          customEnd: customEnd,
          startDay: startDay,
          clock: clock,
        )),
  );

  return Map.unmodifiable({
    for (var i = 0; i < types.length; i++) types[i]: results[i],
  });
}

Future<AnalyticsResult> _loadScopeData(
  dynamic repo, {
  required int ledgerId,
  required String scope,
  required String type,
  required DateTime weekMonday,
  required DateTime selMonth,
  required int selYear,
  required DateTime customStart,
  required DateTime customEnd,
  required int startDay,
  DateTime? clock,
}) async {
  late DateTime start;
  late DateTime end;
  final now = clock ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (scope == 'week') {
    start = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    end = start.add(const Duration(days: 7));
  } else if (scope == 'month') {
    final range = periodForLabel(selMonth.year, selMonth.month, startDay);
    start = range.start;
    final nowLabel = labelForDate(now, startDay);
    final isCurrentPeriod =
        selMonth.year == nowLabel.year && selMonth.month == nowLabel.month;
    end = isCurrentPeriod ? today.add(const Duration(days: 1)) : range.end;
  } else if (scope == 'year') {
    final range = yearRangeFor(selYear, startDay);
    start = range.start;
    final isCurrentYear = !now.isBefore(range.start) && now.isBefore(range.end);
    end = isCurrentYear ? today.add(const Duration(days: 1)) : range.end;
  } else {
    // custom
    start = DateTime(customStart.year, customStart.month, customStart.day);
    end = DateTime(customEnd.year, customEnd.month, customEnd.day)
        .add(const Duration(days: 1));
  }

  Future<dynamic> seriesFuture;
  Future<dynamic>? incomeSeriesFuture;
  Future<dynamic>? expenseSeriesFuture;

  if (type == 'balance') {
    if (scope == 'year') {
      incomeSeriesFuture = repo.totalsByMonth(
          ledgerId: ledgerId, type: 'income', year: selYear);
      expenseSeriesFuture = repo.totalsByMonth(
          ledgerId: ledgerId, type: 'expense', year: selYear);
      seriesFuture = Future.value([]);
    } else {
      incomeSeriesFuture = repo.totalsByDay(
          ledgerId: ledgerId, type: 'income', start: start, end: end);
      expenseSeriesFuture = repo.totalsByDay(
          ledgerId: ledgerId, type: 'expense', start: start, end: end);
      seriesFuture = Future.value([]);
    }
  } else {
    if (scope == 'year') {
      seriesFuture = repo.totalsByMonth(
          ledgerId: ledgerId, type: type, year: selYear);
    } else {
      seriesFuture = repo.totalsByDay(
          ledgerId: ledgerId, type: type, start: start, end: end);
    }
  }

  final list = type == 'balance'
      ? await _loadBalanceData(
          repo, ledgerId, start, end, seriesFuture, incomeSeriesFuture!, expenseSeriesFuture!)
      : await _loadCategoryData(repo, ledgerId, type, start, end, seriesFuture);

  dynamic seriesRaw;
  final catData = list[0] as List<AnalyticsCategory>;
  final int txCount;
  final double sum;

  if (type == 'balance') {
    seriesRaw = _calculateBalanceSeries(list[3], list[4]);
    txCount = (list[2] as int) + (list[5] as int);
    sum = _getSumFromSeries(list[3]) - _getSumFromSeries(list[4]);
  } else {
    seriesRaw = list[1];
    txCount = list[2] as int;
    sum = catData.fold<double>(0, (a, b) => a + b.total);
  }

  final rawValues = analyticsSeriesValues(seriesRaw);
  final empty = txCount == 0 ||
      (sum == 0 && (rawValues.isEmpty || rawValues.every((v) => v == 0)));

  if (seriesRaw is List<({DateTime month, double total})>) {
    final label = labelForDate(now, startDay);
    if (selYear == label.year) {
      seriesRaw = seriesRaw.where((e) => e.month.month <= label.month).toList();
    }
  }

  return AnalyticsResult(
    categories: catData,
    series: seriesRaw,
    start: start,
    end: end,
    count: txCount,
    total: sum,
    average: computeSeriesAverage(seriesRaw),
    incomeTotal: type == 'balance'
        ? _getSumFromSeries(list[3])
        : type == 'income'
            ? sum
            : 0,
    expenseTotal: type == 'balance'
        ? _getSumFromSeries(list[4])
        : type == 'expense'
            ? sum
            : 0,
    empty: empty,
  );
}

Future<List<dynamic>> _loadCategoryData(
  dynamic repo,
  int ledgerId,
  String type,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: type, start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: type, start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[3] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [aggregated, results[1], results[2]];
}

Future<List<dynamic>> _loadBalanceData(
  dynamic repo,
  int ledgerId,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
  Future<dynamic> incomeSeriesFuture,
  Future<dynamic> expenseSeriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    incomeSeriesFuture,
    expenseSeriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'income', start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[6] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [
    aggregated,
    results[1],
    results[2],
    results[3],
    results[4],
    results[5],
  ];
}

Future<List<AnalyticsCategory>> _aggregateTopLevelCategories(
  List<
          ({
            int? id,
            String name,
            String? icon,
            int? parentId,
            int level,
            double total
          })>
      hierarchyData,
  dynamic repo,
  Map<int, db.Category> sharedSynthetic,
) async {
  final topLevelInfo = <int, db.Category>{};
  final topLevelNames = <int?, String>{};
  final topLevelIcons = <int?, String?>{};

  for (final item in hierarchyData) {
    if (item.level == 1) {
      topLevelNames[item.id] = item.name;
      topLevelIcons[item.id] = item.icon;
      if (item.id != null && item.id! > 0) {
        final category = await repo.getCategoryById(item.id!);
        if (category != null) {
          topLevelInfo[item.id!] = category;
        }
      } else if (item.id != null && item.id! < 0) {
        final synthetic = sharedSynthetic[item.id!];
        if (synthetic != null) {
          topLevelInfo[item.id!] = synthetic;
        }
      }
    }
  }

  final parentIdsToQuery = <int>{};
  for (final item in hierarchyData) {
    if (item.level == 2 &&
        item.parentId != null &&
        !topLevelInfo.containsKey(item.parentId!)) {
      parentIdsToQuery.add(item.parentId!);
    }
  }

  for (final parentId in parentIdsToQuery) {
    if (parentId < 0 && sharedSynthetic.containsKey(parentId)) {
      final synthetic = sharedSynthetic[parentId]!;
      topLevelInfo[parentId] = synthetic;
      topLevelNames[parentId] = synthetic.name;
      topLevelIcons[parentId] = synthetic.icon;
      continue;
    }
    final category = await repo.getCategoryById(parentId);
    if (category != null) {
      topLevelInfo[parentId] = category;
    }
  }

  final topLevelMap = <int?, double>{};
  final subCategoriesMap = <int?,
      List<({int id, db.Category category, String name, double total})>>{};

  for (final item in hierarchyData) {
    if (item.level == 1) {
      topLevelMap.update(item.id, (v) => v + item.total,
          ifAbsent: () => item.total);
    } else if (item.level == 2 && item.parentId != null) {
      topLevelMap.update(item.parentId, (v) => v + item.total,
          ifAbsent: () => item.total);
      if (item.id != null) {
        db.Category? subCategory;
        if (item.id! < 0) {
          subCategory = sharedSynthetic[item.id!];
        } else {
          subCategory = await repo.getCategoryById(item.id!);
        }
        if (subCategory != null) {
          subCategoriesMap.putIfAbsent(item.parentId, () => []);
          subCategoriesMap[item.parentId]!.add((
            id: item.id!,
            category: subCategory,
            name: item.name,
            total: item.total,
          ));
        }
      }
    }
  }

  for (final subs in subCategoriesMap.values) {
    subs.sort((a, b) => b.total.compareTo(a.total));
  }

  final result = topLevelMap.entries.map((e) {
    final id = e.key;
    final total = e.value;
    final subs = subCategoriesMap[id] ??
        <({int id, db.Category category, String name, double total})>[];

    if (id != null && topLevelInfo.containsKey(id)) {
      final category = topLevelInfo[id]!;
      return (
        id: id,
        name: category.name,
        category: category,
        total: total,
        subCategories: subs,
      );
    } else if (topLevelNames.containsKey(id)) {
      return (
        id: id,
        name: topLevelNames[id]!,
        category: null,
        total: total,
        subCategories: subs,
      );
    } else {
      return (
        id: id,
        name: '未分类',
        category: null,
        total: total,
        subCategories: subs,
      );
    }
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return result;
}

dynamic _calculateBalanceSeries(dynamic incomeData, dynamic expenseData) {
  if (incomeData is List<({DateTime day, double total})> &&
      expenseData is List<({DateTime day, double total})>) {
    final Map<DateTime, double> incomeMap = {
      for (var e in incomeData) e.day: e.total
    };
    final Map<DateTime, double> expenseMap = {
      for (var e in expenseData) e.day: e.total
    };
    final allDays = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allDays.map((day) {
      final income = incomeMap[day] ?? 0.0;
      final expense = expenseMap[day] ?? 0.0;
      return (day: day, total: income - expense);
    }).toList();
  }
  if (incomeData is List<({DateTime month, double total})> &&
      expenseData is List<({DateTime month, double total})>) {
    final Map<DateTime, double> incomeMap = {
      for (var e in incomeData) e.month: e.total
    };
    final Map<DateTime, double> expenseMap = {
      for (var e in expenseData) e.month: e.total
    };
    final allMonths = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allMonths.map((month) {
      final income = incomeMap[month] ?? 0.0;
      final expense = expenseMap[month] ?? 0.0;
      return (month: month, total: income - expense);
    }).toList();
  }
  if (incomeData is List<({int year, double total})> &&
      expenseData is List<({int year, double total})>) {
    final Map<int, double> incomeMap = {
      for (var e in incomeData) e.year: e.total
    };
    final Map<int, double> expenseMap = {
      for (var e in expenseData) e.year: e.total
    };
    final allYears = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allYears.map((year) {
      final income = incomeMap[year] ?? 0.0;
      final expense = expenseMap[year] ?? 0.0;
      return (year: year, total: income - expense);
    }).toList();
  }
  return [];
}

double _getSumFromSeries(dynamic seriesData) {
  if (seriesData is List<({DateTime day, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  if (seriesData is List<({DateTime month, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  if (seriesData is List<({int year, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  return 0.0;
}
