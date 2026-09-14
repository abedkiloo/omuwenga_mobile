/// Client-side push stub — real FCM/APNs is BACKLOG.
abstract class PushNotifier {
  Future<void> notify({
    required String title,
    required String body,
    Map<String, String>? data,
  });
}

class FakePushNotifier implements PushNotifier {
  final List<Map<String, Object?>> sent = [];

  @override
  Future<void> notify({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    sent.add({'title': title, 'body': body, 'data': data});
  }
}

class NoOpPushNotifier implements PushNotifier {
  @override
  Future<void> notify({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {}
}
