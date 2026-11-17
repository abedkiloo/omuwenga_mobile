/// One page of the weekly call book.
///
/// The phone asks for customers who still need a call. A recorded result
/// leaves this list until next Monday, or until a call-later time is due.
const int kCallBookPageSize = 10;

const List<String> kCallWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

/// Monday–Friday label for a weekday index.
///
/// [index] is 0–4. Any other index returns an empty string.
String callWeekdayLabel(int index) {
  if (index < 0 || index > 4) return '';
  return kCallWeekdays[index];
}

/// Counts for one weekday on the planner.
class CallDayCount {
  const CallDayCount({
    required this.weekday,
    required this.callable,
    required this.called,
    required this.notCalled,
  });

  final int weekday;
  final int callable;
  final int called;
  final int notCalled;

  factory CallDayCount.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return CallDayCount(
      weekday: asInt(json['weekday']).clamp(0, 4),
      callable: asInt(json['callable']),
      called: asInt(json['called']),
      notCalled: asInt(json['not_called']),
    );
  }
}

/// Week totals. Counts are 0 or more and do not include a phone number.
class CallBookSummary {
  const CallBookSummary({
    required this.isCallDay,
    required this.weekday,
    required this.callable,
    required this.called,
    required this.notCalled,
    required this.days,
  });

  final bool isCallDay;
  final int weekday;
  final int callable;
  final int called;
  final int notCalled;
  final List<CallDayCount> days;

  factory CallBookSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawDays = json['days'];
    return CallBookSummary(
      isCallDay: json['is_call_day'] == true,
      weekday: asInt(json['weekday']).clamp(0, 6),
      callable: asInt(json['callable']),
      called: asInt(json['called']),
      notCalled: asInt(json['not_called']),
      days: rawDays is List
          ? [
              for (final item in rawDays)
                if (item is Map)
                  CallDayCount.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

/// One customer still on the working list, or a due callback.
class CallBookRow {
  const CallBookRow({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.county,
    required this.subCounty,
    required this.ward,
    required this.weekday,
    required this.calledThisWeek,
    required this.callLaterDue,
    required this.previousSummary,
  });

  final int customerId;
  final String name;
  final String phone;
  final String county;
  final String subCounty;
  final String ward;
  final int weekday;
  final bool calledThisWeek;
  final bool callLaterDue;
  final String previousSummary;

  String get place {
    return [ward, subCounty, county].where((part) => part.isNotEmpty).join(', ');
  }

  factory CallBookRow.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return CallBookRow(
      customerId: asInt(json['customer_id']),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      county: (json['county'] ?? '').toString(),
      subCounty: (json['sub_county'] ?? '').toString(),
      ward: (json['ward'] ?? '').toString(),
      weekday: asInt(json['weekday']).clamp(0, 6),
      calledThisWeek: json['called_this_week'] == true,
      callLaterDue: json['call_later_due'] == true,
      previousSummary: (json['previous_summary'] ?? '').toString(),
    );
  }
}

/// One server page of the book.
class CallBookPageData {
  const CallBookPageData({
    required this.summary,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.results,
  });

  final CallBookSummary summary;
  final int count;
  final int page;
  final int pageSize;
  final List<CallBookRow> results;

  factory CallBookPageData.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final raw = json['results'];
    final summaryRaw = json['summary'];
    return CallBookPageData(
      summary: summaryRaw is Map
          ? CallBookSummary.fromJson(Map<String, dynamic>.from(summaryRaw))
          : const CallBookSummary(
              isCallDay: false,
              weekday: 0,
              callable: 0,
              called: 0,
              notCalled: 0,
              days: [],
            ),
      count: asInt(json['count']),
      page: asInt(json['page']) < 1 ? 1 : asInt(json['page']),
      pageSize: asInt(json['page_size']) < 1
          ? kCallBookPageSize
          : asInt(json['page_size']),
      results: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  CallBookRow.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

/// Rows that still belong on the working list.
///
/// A customer who was recorded this week stays off the list. A call-later
/// whose time has been reached stays on it. [rows] may be 0–1000.
List<CallBookRow> visibleCallRows(List<CallBookRow> rows) {
  return [
    for (final row in rows)
      if (row.callLaterDue || !row.calledThisWeek) row,
  ];
}
