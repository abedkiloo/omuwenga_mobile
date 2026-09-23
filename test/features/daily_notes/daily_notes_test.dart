import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/application/daily_notes_controllers.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/data/daily_notes_api.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/domain/daily_note.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/presentation/daily_notes_page.dart';
import 'package:completebyte_pos_mobile/features/daily_notes/presentation/sticky_notes_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession _notesSession({bool viewAll = true}) {
  return AuthSession(
    user: const AuthUser(
      id: 20,
      username: 'ann',
      firstName: 'Ann',
      lastName: 'Cash',
    ),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'daily_notes', action: 'view'),
      const PermissionGrant(module: 'daily_notes', action: 'create'),
      const PermissionGrant(module: 'daily_notes', action: 'update'),
      if (viewAll)
        const PermissionGrant(module: 'daily_notes', action: 'view_all'),
    ]),
    persona: AppPersona.manager,
  );
}

Map<String, dynamic> _noteJson({
  int id = 1,
  bool sticky = true,
  bool done = false,
  int assigned = 20,
}) {
  return {
    'id': id,
    'note_date': '2026-09-24',
    'title': sticky ? 'Till' : 'Handover',
    'content': sticky ? 'Count first' : 'Quiet day',
    'is_sticky': sticky,
    'is_done': done,
    'author': 9,
    'author_name': 'Bea',
    'assigned_to': assigned,
    'assigned_to_name': 'Ann',
  };
}

Map<String, dynamic> _taskJson({int id = 3, bool done = false}) {
  return {
    'id': id,
    'task_date': '2026-09-24',
    'title': 'Restock',
    'description': 'Sugar',
    'is_done': done,
    'author': 9,
    'assigned_to': 20,
    'assigned_to_name': 'Ann',
  };
}

DailyNotesApi _api(MockClient client) {
  return DailyNotesApi(
    ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: InMemoryTokenStore(),
      httpClient: client,
    ),
  );
}

void main() {
  group('domain', () {
    test('parse helpers and payload', () {
      final sticky = DailyNote.fromJson(_noteJson());
      final general = DailyNote.fromJson(_noteJson(id: 2, sticky: false));
      expect(sticky.isSticky, isTrue);
      expect(general.isGeneral, isTrue);
      expect(sticky.kindLabel, 'Sticky');
      expect(hasBlockingStickyNotes([sticky, general]), isTrue);
      expect(unresolvedStickyNotes([sticky, general]).single.id, 1);
      expect(canToggleDailyNote(sticky, 20), isTrue);
      expect(canToggleDailyNote(sticky, 9), isTrue);
      expect(canToggleDailyNote(sticky, 99), isFalse);
      expect(canToggleDailyNote(sticky, 99, viewAll: true), isTrue);
      expect(todayIsoDate(DateTime(2026, 9, 24)), '2026-09-24');
      expect(
        createNotePayload(
          noteDate: '2026-09-24',
          content: ' x ',
          isSticky: true,
          assignedTo: 4,
        )['assigned_to'],
        4,
      );
      expect(
        createNotePayload(
          noteDate: '2026-09-24',
          content: 'All drivers',
          assignedRole: 9,
        )['assigned_role'],
        9,
      );
      expect(
        sessionCanAssignDailyNotes(viewAll: false, isAdmin: true),
        isTrue,
      );
      expect(sessionCanAssignDailyNotes(viewAll: false), isFalse);
      expect(
        noteAudienceLabel(
          DailyNote.fromJson({
            ..._noteJson(),
            'assigned_role': 3,
            'assigned_role_name': 'Sales Personnel',
          }),
        ),
        'Sales Personnel · Ann',
      );
      expect(
        noteAudienceLabel(
          const DailyNote(id: 8, noteDate: '2026-09-24', content: 'x'),
        ),
        '',
      );
      expect(
        noteAudienceLabel(
          const DailyNote(
            id: 9,
            noteDate: '2026-09-24',
            content: 'x',
            assignedRoleName: 'Delivery Driver',
          ),
        ),
        'Delivery Driver',
      );
      expect(DailyTaskItem.fromJson(_taskJson()).title, 'Restock');
      expect(
        DailyStaffOption.fromJson({'id': 1, 'username': 'a'}).displayName,
        'a',
      );
      expect(
        DailyRoleOption.fromJson({'id': 2, 'name': 'Delivery Driver'}).name,
        'Delivery Driver',
      );
      expect(DailyNotesApiException('e').toString(), 'e');
    });
  });

  group('api', () {
    test('list blocking create toggle and errors', () async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/blocking/')) {
            return http.Response(jsonEncode([_noteJson()]), 200);
          }
          if (request.url.path.contains('/staff/')) {
            return http.Response(
              jsonEncode([
                {'id': 4, 'username': 'ken', 'display_name': 'Ken'},
              ]),
              200,
            );
          }
          if (request.url.path.contains('/roles/')) {
            return http.Response(
              jsonEncode([
                {'id': 3, 'name': 'Sales Personnel'},
              ]),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.contains('/toggle-done/')) {
            return http.Response(
              jsonEncode(_noteJson(done: true)),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path.contains('/notes/')) {
            return http.Response(jsonEncode(_noteJson(id: 8, sticky: false)), 201);
          }
          if (request.url.path.contains('/tasks/') &&
              request.url.path.contains('/toggle-done/')) {
            return http.Response(jsonEncode(_taskJson(done: true)), 200);
          }
          if (request.url.path.contains('/tasks/')) {
            return http.Response(
              jsonEncode({
                'results': [_taskJson()],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'results': [_noteJson()],
            }),
            200,
          );
        }),
      );
      expect((await api.blocking()).getOrThrow().single.isSticky, isTrue);
      expect((await api.staff()).getOrThrow().single.displayName, 'Ken');
      expect((await api.roles()).getOrThrow().single.name, 'Sales Personnel');
      expect(
        (await api.listNotes(noteDate: '2026-09-24')).getOrThrow().single.id,
        1,
      );
      expect((await api.listTasks(taskDate: '2026-09-24')).getOrThrow().single.title, 'Restock');
      expect(
        (await api.createNote(
          createNotePayload(noteDate: '2026-09-24', content: 'Hi'),
        )).getOrThrow().id,
        8,
      );
      expect((await api.toggleNote(1)).getOrThrow().isDone, isTrue);
      expect((await api.toggleTask(3)).getOrThrow().isDone, isTrue);

      final bad = _api(MockClient((_) async => http.Response('no', 500)));
      expect((await bad.blocking()).isFailure, isTrue);
      expect((await bad.listNotes()).isFailure, isTrue);
      expect((await bad.createNote({'content': 'x'})).isFailure, isTrue);
      expect((await bad.toggleNote(1)).isFailure, isTrue);
    });
  });

  group('controllers', () {
    test('load create toggle and sticky gate', () async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/blocking/')) {
            return http.Response(jsonEncode([_noteJson()]), 200);
          }
          if (request.url.path.contains('/staff/')) {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path.contains('/roles/')) {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.url.path.contains('/toggle-done/') &&
              request.url.path.contains('/notes/')) {
            return http.Response(jsonEncode(_noteJson(done: true)), 200);
          }
          if (request.url.path.contains('/toggle-done/')) {
            return http.Response(jsonEncode(_taskJson(done: true)), 200);
          }
          if (request.method == 'POST') {
            return http.Response(jsonEncode(_noteJson(id: 9, sticky: true)), 201);
          }
          if (request.url.path.contains('/tasks/')) {
            return http.Response(jsonEncode([_taskJson()]), 200);
          }
          return http.Response(jsonEncode([_noteJson()]), 200);
        }),
      );
      final notes = DailyNotesController(api);
      await notes.load(date: '2026-09-24', loadStaff: true);
      expect(notes.state.notes, isNotEmpty);
      expect(notes.state.tasks, isNotEmpty);
      await notes.loadAssignees();
      expect(await notes.createNote(content: ''), isFalse);
      expect(
        await notes.createNote(content: 'Hi', isSticky: true, assignedRole: 3),
        isTrue,
      );
      expect(await notes.toggleNote(1), isTrue);
      expect(await notes.toggleTask(3), isTrue);

      final gate = StickyNotesGateController(api);
      await gate.load();
      expect(gate.state.isBlocking, isTrue);
      expect(await gate.tick(1), isTrue);
      expect(gate.state.isBlocking, isFalse);

      final failing = DailyNotesController(
        _api(MockClient((_) async => http.Response('x', 400))),
      );
      await failing.load();
      expect(failing.state.error, isNotNull);
      expect(await failing.toggleNote(1), isFalse);
      final failGate = StickyNotesGateController(
        _api(MockClient((_) async => http.Response('x', 400))),
      );
      await failGate.load();
      expect(failGate.state.isBlocking, isFalse);
    });
  });

  group('widgets', () {
    testWidgets('lists notes and ticks sticky overlay', (tester) async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/blocking/')) {
            return http.Response(jsonEncode([_noteJson()]), 200);
          }
          if (request.url.path.contains('/toggle-done/')) {
            return http.Response(jsonEncode(_noteJson(done: true)), 200);
          }
          if (request.url.path.contains('/tasks/')) {
            return http.Response(jsonEncode([_taskJson()]), 200);
          }
          if (request.method == 'POST') {
            return http.Response(jsonEncode(_noteJson(id: 11, sticky: false)), 201);
          }
          return http.Response(jsonEncode([_noteJson(), _noteJson(id: 2, sticky: false)]), 200);
        }),
      );
      final container = ProviderContainer(
        overrides: [
          authSessionSeedProvider.overrideWithValue(_notesSession()),
          dailyNotesApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DailyNotesPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily_note_1')), findsOneWidget);
      expect(find.byKey(const Key('daily_task_3')), findsOneWidget);
      await tester.tap(find.byKey(const Key('daily_note_tick_1')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(children: [StickyNotesGate()]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sticky_notes_gate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sticky_gate_tick_1')));
      await tester.pumpAndSettle();
    });

    testWidgets('saves a general note from the sheet', (tester) async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/tasks/')) {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(_noteJson(id: 12, sticky: false)),
              201,
            );
          }
          return http.Response(jsonEncode([]), 200);
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionSeedProvider.overrideWithValue(_notesSession()),
            dailyNotesApiProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(home: DailyNotesPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('daily_notes_add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('daily_note_assign_person')), findsOneWidget);
      await tester.tap(find.byKey(const Key('daily_note_assign_role')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('daily_note_content')), 'Quiet shift');
      await tester.tap(find.byKey(const Key('daily_note_save')));
      await tester.pumpAndSettle();
    });
  });
}
