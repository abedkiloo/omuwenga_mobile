class AppraisalBandProgress {
  const AppraisalBandProgress({
    required this.sales,
    required this.stars,
    required this.tone,
    this.label = '',
    this.bonus = 0,
    this.progress = 0,
    this.target = 0,
    this.targetProgress = 0,
    this.amountToTarget = 0,
    this.amountToNext = 0,
    this.nextMin,
    this.nextBonus = 0,
  });

  final double sales;
  final double stars;
  final String tone;
  final String label;
  final double bonus;
  final double progress;
  final double target;
  final double targetProgress;
  final double amountToTarget;
  final double amountToNext;
  final double? nextMin;
  final double nextBonus;

  factory AppraisalBandProgress.fromJson(Map<String, dynamic> json) {
    return AppraisalBandProgress(
      sales: _d(json['sales']),
      stars: _d(json['stars']),
      tone: (json['tone'] ?? 'rose').toString(),
      label: (json['label'] ?? '').toString(),
      bonus: _d(json['bonus']),
      progress: _d(json['progress']),
      target: _d(json['target']),
      targetProgress: _d(json['target_progress']),
      amountToTarget: _d(json['amount_to_target']),
      amountToNext: _d(json['amount_to_next'] ?? json['amount_to_next_bonus']),
      nextMin: json['next_min'] == null && json['next_bonus_min'] == null
          ? null
          : _d(json['next_min'] ?? json['next_bonus_min']),
      nextBonus: _d(json['next_bonus']),
    );
  }
}

class AppraisalMonth {
  const AppraisalMonth({
    required this.officialAverage,
    required this.fourStarMonth,
    required this.progressToFourStar,
    required this.bonus,
    required this.stars,
    required this.tone,
    required this.sales,
    this.amountToNextBonus = 0,
    this.nextBonusMin,
  });

  final double officialAverage;
  final bool fourStarMonth;
  final double progressToFourStar;
  final double bonus;
  final double stars;
  final String tone;
  final double sales;
  final double amountToNextBonus;
  final double? nextBonusMin;

  factory AppraisalMonth.fromJson(Map<String, dynamic> json) {
    return AppraisalMonth(
      officialAverage: _d(json['official_average']),
      fourStarMonth: json['four_star_month'] == true,
      progressToFourStar: _d(json['progress_to_four_star']),
      bonus: _d(json['bonus']),
      stars: _d(json['stars']),
      tone: (json['tone'] ?? 'rose').toString(),
      sales: _d(json['sales']),
      amountToNextBonus: _d(json['amount_to_next_bonus']),
      nextBonusMin: json['next_bonus_min'] == null
          ? null
          : _d(json['next_bonus_min']),
    );
  }
}

class AppraisalYear {
  const AppraisalYear({
    required this.annualAverage,
    required this.ytdAverage,
    required this.fourStarMonths,
    required this.fourStarMonthsRequired,
    required this.qualifies,
    required this.newBasic,
    required this.progressToIncrement,
    required this.tone,
    required this.months,
  });

  final double annualAverage;
  final double ytdAverage;
  final int fourStarMonths;
  final int fourStarMonthsRequired;
  final bool qualifies;
  final double newBasic;
  final double progressToIncrement;
  final String tone;
  final List<AppraisalMonthSlice> months;

  factory AppraisalYear.fromJson(Map<String, dynamic> json) {
    return AppraisalYear(
      annualAverage: _d(json['annual_average']),
      ytdAverage: _d(json['ytd_average']),
      fourStarMonths: (json['four_star_months'] as num?)?.toInt() ?? 0,
      fourStarMonthsRequired:
          (json['four_star_months_required'] as num?)?.toInt() ?? 8,
      qualifies: json['qualifies'] == true,
      newBasic: _d(json['new_basic']),
      progressToIncrement: _d(json['progress_to_increment']),
      tone: (json['tone'] ?? 'rose').toString(),
      months: [
        for (final row in json['months'] as List? ?? const [])
          if (row is Map)
            AppraisalMonthSlice.fromJson(Map<String, dynamic>.from(row)),
      ],
    );
  }
}

class AppraisalMonthSlice {
  const AppraisalMonthSlice({
    required this.month,
    required this.officialAverage,
    required this.fourStarMonth,
    required this.tone,
  });

  final int month;
  final double officialAverage;
  final bool fourStarMonth;
  final String tone;

  factory AppraisalMonthSlice.fromJson(Map<String, dynamic> json) {
    return AppraisalMonthSlice(
      month: (json['month'] as num?)?.toInt() ?? 0,
      officialAverage: _d(json['official_average']),
      fourStarMonth: json['four_star_month'] == true,
      tone: (json['tone'] ?? 'rose').toString(),
    );
  }
}

class AppraisalSnapshot {
  const AppraisalSnapshot({
    required this.today,
    required this.month,
    required this.year,
    required this.headline,
    required this.detail,
    required this.greetWhenNoStickyNotes,
    required this.showOnHome,
    this.staffName = '',
    this.todayDate = '',
  });

  final AppraisalBandProgress today;
  final AppraisalMonth month;
  final AppraisalYear year;
  final String headline;
  final String detail;
  final bool greetWhenNoStickyNotes;
  final bool showOnHome;
  final String staffName;
  final String todayDate;

  factory AppraisalSnapshot.fromJson(Map<String, dynamic> json) {
    final greeting = json['greeting'] is Map
        ? Map<String, dynamic>.from(json['greeting'] as Map)
        : const <String, dynamic>{};
    final policy = json['policy'] is Map
        ? Map<String, dynamic>.from(json['policy'] as Map)
        : const <String, dynamic>{};
    final staff = json['staff'] is Map
        ? Map<String, dynamic>.from(json['staff'] as Map)
        : const <String, dynamic>{};
    final today = json['today'] is Map
        ? Map<String, dynamic>.from(json['today'] as Map)
        : const <String, dynamic>{};
    return AppraisalSnapshot(
      today: AppraisalBandProgress.fromJson(today),
      month: AppraisalMonth.fromJson(
        json['month'] is Map
            ? Map<String, dynamic>.from(json['month'] as Map)
            : const {},
      ),
      year: AppraisalYear.fromJson(
        json['year'] is Map
            ? Map<String, dynamic>.from(json['year'] as Map)
            : const {},
      ),
      headline: (greeting['headline'] ?? '').toString(),
      detail: (greeting['detail'] ?? '').toString(),
      greetWhenNoStickyNotes: policy['greet_when_no_sticky_notes'] != false,
      showOnHome: json['show_on_home'] != false && policy['show_on_home'] != false,
      staffName: (staff['name'] ?? '').toString(),
      todayDate: (today['date'] ?? '').toString(),
    );
  }
}

double _d(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String starGlyphs(double stars, {int max = 5}) {
  final filled = stars.floor().clamp(0, max);
  return '${'★' * filled}${'☆' * (max - filled)}';
}
