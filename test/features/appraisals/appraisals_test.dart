import 'package:completebyte_pos_mobile/features/appraisals/application/appraisals_controller.dart';
import 'package:completebyte_pos_mobile/features/appraisals/domain/appraisal.dart';
import 'package:completebyte_pos_mobile/features/appraisals/presentation/appraisal_progress_card.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/application/daily_notes_controllers.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/domain/daily_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _snapshotJson({double stars = 3, String tone = 'amber'}) {
  return {
    'staff': {'id': 20, 'name': 'Ann Cash'},
    'show_on_home': true,
    'policy': {'greet_when_no_sticky_notes': true, 'show_on_home': true},
    'greeting': {
      'headline': '3-Star day — KES 1,500 to hit the daily target',
      'detail': 'Monthly average 3.00/5',
      'tone': tone,
    },
    'today': {
      'date': '2026-09-29',
      'sales': 18500,
      'stars': stars,
      'tone': tone,
      'target': 20000,
      'target_progress': 0.925,
      'amount_to_target': 1500,
      'label': '',
    },
    'month': {
      'sales': 18500,
      'official_average': 3.0,
      'four_star_month': false,
      'progress_to_four_star': 0.29,
      'bonus': 0,
      'stars': 1,
      'tone': 'rose',
    },
    'year': {
      'annual_average': 0.25,
      'ytd_average': 3.0,
      'four_star_months': 0,
      'four_star_months_required': 8,
      'qualifies': false,
      'new_basic': 15000,
      'progress_to_increment': 0,
      'tone': 'rose',
      'months': [
        {'month': 9, 'official_average': 3.0, 'four_star_month': false, 'tone': 'amber'},
      ],
    },
  };
}

void main() {
  test('star glyphs and snapshot parse', () {
    expect(starGlyphs(4), '★★★★☆');
    expect(starGlyphs(5), '★★★★★');
    final snap = AppraisalSnapshot.fromJson(_snapshotJson());
    expect(snap.today.stars, 3);
    expect(snap.today.amountToTarget, 1500);
    expect(snap.headline.contains('3-Star'), isTrue);
    expect(snap.showOnHome, isTrue);
  });

  test('greeting hides when sticky notes are open', () {
    final appraisals = AppraisalsState(
      snapshot: AppraisalSnapshot.fromJson(_snapshotJson()),
    );
    const openNotes = StickyNotesGateState(
      notes: [
        DailyNote(
          id: 1,
          noteDate: '2026-09-29',
          title: 'Till',
          content: 'Count',
          isSticky: true,
          isDone: false,
          authorId: 9,
        ),
      ],
    );
    expect(appraisalGreetingVisible(appraisals, openNotes), isFalse);
    expect(appraisalGreetingVisible(appraisals, const StickyNotesGateState()), isTrue);
    expect(
      appraisalGreetingVisible(
        AppraisalsState(
          snapshot: AppraisalSnapshot.fromJson(_snapshotJson()),
          dismissedDate: '2026-09-29',
        ),
        const StickyNotesGateState(),
      ),
      isFalse,
    );
  });

  testWidgets('progress card uses star color coding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppraisalProgressCard(
            snapshot: AppraisalSnapshot.fromJson(_snapshotJson(stars: 4, tone: 'emerald')),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('appraisal_progress_card')), findsOneWidget);
    expect(find.textContaining('Today KES'), findsOneWidget);
    expect(find.textContaining('Month avg'), findsOneWidget);
    expect(find.text('★★★★☆'), findsOneWidget);
  });
}
