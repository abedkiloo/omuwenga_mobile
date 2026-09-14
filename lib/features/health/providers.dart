import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/result/result.dart';
import 'data/health_api.dart';

final healthApiProvider = Provider<HealthApi>((ref) {
  return HealthApi(ref.watch(apiClientProvider));
});

final healthCheckProvider = FutureProvider<Result<HealthStatus>>((ref) {
  return ref.watch(healthApiProvider).check();
});
