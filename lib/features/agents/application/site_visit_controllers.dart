import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/data/outbox_store.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../../sync/providers.dart';
import '../data/agents_api.dart';
import '../domain/site_visit.dart';

class SiteVisitWizardState {
  const SiteVisitWizardState({
    this.step = SiteVisitStep.map,
    this.pin,
    this.pinConfirmed = false,
    this.landmark = '',
    this.photos = const [],
    this.customerId,
    this.customerName,
    this.siteId,
    this.config = SiteVisitConfig.defaults,
    this.saving = false,
    this.error,
    this.finalized = false,
  });

  final SiteVisitStep step;
  final SitePin? pin;
  final bool pinConfirmed;
  final String landmark;
  final List<LocalSitePhoto> photos;
  final int? customerId;
  final String? customerName;
  final int? siteId;
  final SiteVisitConfig config;
  final bool saving;
  final String? error;
  final bool finalized;

  bool get canConfirmMap => pin != null;
  bool get canContinuePhotos => photos.length >= config.minPhotos;
  bool get canSave =>
      pinConfirmed &&
      canContinuePhotos &&
      customerId != null &&
      !saving;

  SiteVisitWizardState copyWith({
    SiteVisitStep? step,
    SitePin? pin,
    bool? pinConfirmed,
    String? landmark,
    List<LocalSitePhoto>? photos,
    int? customerId,
    String? customerName,
    int? siteId,
    SiteVisitConfig? config,
    bool? saving,
    String? error,
    bool? finalized,
    bool clearError = false,
    bool clearPin = false,
    bool clearCustomer = false,
  }) {
    return SiteVisitWizardState(
      step: step ?? this.step,
      pin: clearPin ? null : (pin ?? this.pin),
      pinConfirmed: pinConfirmed ?? this.pinConfirmed,
      landmark: landmark ?? this.landmark,
      photos: photos ?? this.photos,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      siteId: siteId ?? this.siteId,
      config: config ?? this.config,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      finalized: finalized ?? this.finalized,
    );
  }
}

class SiteVisitWizardController extends StateNotifier<SiteVisitWizardState> {
  SiteVisitWizardController(this._api, this._outbox, {ClientUuid? ids})
      : _ids = ids ?? ClientUuid(),
        super(const SiteVisitWizardState());

  final AgentsApi _api;
  final OutboxStore _outbox;
  final ClientUuid _ids;

  Future<void> loadConfig() async {
    final result = await _api.fetchConfig();
    result.when(
      success: (config) => state = state.copyWith(config: config),
      failure: (_, _) {},
    );
  }

  void setPin(SitePin pin) {
    state = state.copyWith(pin: pin, pinConfirmed: false, clearError: true);
  }

  void confirmPin() {
    if (state.pin == null) return;
    state = state.copyWith(pinConfirmed: true, step: SiteVisitStep.photos);
  }

  void setLandmark(String value) {
    state = state.copyWith(landmark: value);
  }

  void addPhoto(LocalSitePhoto photo) {
    if (state.photos.length >= state.config.maxPhotos) return;
    state = state.copyWith(photos: [...state.photos, photo], clearError: true);
  }

  void removePhoto(String id) {
    state = state.copyWith(
      photos: state.photos.where((p) => p.id != id).toList(),
    );
  }

  void continueFromPhotos() {
    if (!state.canContinuePhotos) return;
    state = state.copyWith(step: SiteVisitStep.customer);
  }

  void goToStep(SiteVisitStep step) {
    if (step == SiteVisitStep.photos && !state.pinConfirmed) return;
    if (step == SiteVisitStep.customer &&
        (!state.pinConfirmed || !state.canContinuePhotos)) {
      return;
    }
    state = state.copyWith(step: step);
  }

  void selectCustomer({required int id, required String name}) {
    state = state.copyWith(customerId: id, customerName: name, clearError: true);
  }

  Future<bool> saveAndFinalize({bool attemptFinalize = true}) async {
    final pin = state.pin;
    final customerId = state.customerId;
    if (pin == null || customerId == null || !state.canSave) return false;

    state = state.copyWith(saving: true, clearError: true);
    final create = await _api.createSite(
      pin: pin,
      landmark: state.landmark,
      label: pin.label,
      customerId: customerId,
    );
    if (create.isFailure) {
      final failure = create as Failure;
      state = state.copyWith(saving: false, error: failure.error.toString());
      return false;
    }
    final site = create.getOrThrow();
    final siteId = (site['id'] as num).toInt();
    state = state.copyWith(siteId: siteId);

    for (final photo in state.photos) {
      await _api.enqueueMediaUpload(
        outbox: _outbox,
        siteId: siteId,
        photo: photo,
        idempotencyKey: _ids.next(),
      );
    }

    if (!attemptFinalize) {
      state = state.copyWith(saving: false);
      return true;
    }

    final fin = await _api.finalizeSite(siteId);
    if (fin.isFailure) {
      final failure = fin as Failure;
      state = state.copyWith(
        saving: false,
        error:
            'Site saved (#$siteId); finalize waiting on media: ${failure.error}',
      );
      return false;
    }
    state = state.copyWith(saving: false, finalized: true);
    return true;
  }
}

final agentsApiProvider = Provider<AgentsApi>((ref) {
  return AgentsApi(ref.watch(apiClientProvider));
});

final siteVisitWizardProvider = StateNotifierProvider.autoDispose<
    SiteVisitWizardController, SiteVisitWizardState>((ref) {
  return SiteVisitWizardController(
    ref.watch(agentsApiProvider),
    ref.watch(outboxStoreProvider),
  );
});
