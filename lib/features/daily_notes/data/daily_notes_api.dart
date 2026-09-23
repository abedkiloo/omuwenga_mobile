import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/daily_note.dart';

class DailyNotesApiException implements Exception {
  DailyNotesApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DailyNotesApi {
  DailyNotesApi(this._client);
  final ApiClient _client;

  Future<Result<List<DailyNote>>> listNotes({String? noteDate}) {
    final query = noteDate == null || noteDate.isEmpty
        ? ''
        : '?note_date=${Uri.encodeQueryComponent(noteDate)}&page_size=50';
    return _getList('daily-notes/notes/$query', DailyNote.fromJson);
  }

  Future<Result<List<DailyTaskItem>>> listTasks({String? taskDate}) {
    final query = taskDate == null || taskDate.isEmpty
        ? ''
        : '?task_date=${Uri.encodeQueryComponent(taskDate)}&page_size=50';
    return _getList('daily-notes/tasks/$query', DailyTaskItem.fromJson);
  }

  Future<Result<List<DailyNote>>> blocking() {
    return _getList('daily-notes/notes/blocking/', DailyNote.fromJson);
  }

  Future<Result<List<DailyStaffOption>>> staff() {
    return _getList('daily-notes/notes/staff/', DailyStaffOption.fromJson);
  }

  Future<Result<DailyNote>> createNote(Map<String, dynamic> body) {
    return _postMap('daily-notes/notes/', body, DailyNote.fromJson, 'Save note failed');
  }

  Future<Result<DailyNote>> toggleNote(int id) {
    return _postMap(
      'daily-notes/notes/$id/toggle-done/',
      const {},
      DailyNote.fromJson,
      'Tick note failed',
    );
  }

  Future<Result<DailyTaskItem>> toggleTask(int id) {
    return _postMap(
      'daily-notes/tasks/$id/toggle-done/',
      const {},
      DailyTaskItem.fromJson,
      'Tick task failed',
    );
  }

  Future<Result<List<T>>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final res = await _client.get(path);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(DailyNotesApiException('Load failed (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      final rows = data is Map ? data['results'] : data;
      if (rows is! List) {
        return Failure(DailyNotesApiException('Invalid notes payload'));
      }
      return Success([
        for (final row in rows)
          if (row is Map) parse(Map<String, dynamic>.from(row)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<T>> _postMap<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
    String label,
  ) async {
    final res = await _client.post(path, body: body);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(DailyNotesApiException(_errorMessage(response.body, label)));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(DailyNotesApiException('Invalid payload'));
      }
      return Success(parse(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        if (data['error'] != null) return data['error'].toString();
        if (data['detail'] != null) return data['detail'].toString();
        final first = data.values.expand((v) => v is List ? v : [v]).firstWhere(
          (v) => v != null,
          orElse: () => fallback,
        );
        return first.toString();
      }
    } on Object {
      /* ignore */
    }
    return fallback;
  }
}
