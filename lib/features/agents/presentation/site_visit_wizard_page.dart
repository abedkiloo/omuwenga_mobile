import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../../sync/domain/client_uuid.dart';
import '../application/site_visit_controllers.dart';
import '../domain/site_visit.dart';
import 'map_pin_picker.dart';

/// Wizard: Map → Photos → Customer. Cannot skip 1–2.
class SiteVisitWizardPage extends ConsumerStatefulWidget {
  const SiteVisitWizardPage({
    super.key,
    this.mapPickerBuilder,
  });

  /// Injected in tests to avoid Google Maps platform views.
  final MapPinPickerBuilder? mapPickerBuilder;

  @override
  ConsumerState<SiteVisitWizardPage> createState() => _SiteVisitWizardPageState();
}

class _SiteVisitWizardPageState extends ConsumerState<SiteVisitWizardPage> {
  late final PageController _pages;
  final _ids = ClientUuid();

  @override
  void initState() {
    super.initState();
    _pages = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(siteVisitWizardProvider.notifier).loadConfig();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncPage(SiteVisitStep step) {
    final index = step.index;
    if (_pages.hasClients && (_pages.page?.round() ?? 0) != index) {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(siteVisitWizardProvider);
    ref.listen(siteVisitWizardProvider, (prev, next) {
      if (prev?.step != next.step) _syncPage(next.step);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('New site visit')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _subtitle(state.step),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MapStep(
                  state: state,
                  mapPickerBuilder: widget.mapPickerBuilder,
                  onPin: (pin) =>
                      ref.read(siteVisitWizardProvider.notifier).setPin(pin),
                  onLandmark: (v) =>
                      ref.read(siteVisitWizardProvider.notifier).setLandmark(v),
                ),
                _PhotosStep(
                  state: state,
                  onAdd: () {
                    ref.read(siteVisitWizardProvider.notifier).addPhoto(
                          LocalSitePhoto(
                            id: _ids.next(),
                            path: '/tmp/site_${_ids.next()}.jpg',
                            bytesLength: 12000,
                          ),
                        );
                  },
                  onRemove: (id) =>
                      ref.read(siteVisitWizardProvider.notifier).removePhoto(id),
                ),
                _CustomerStep(state: state),
              ],
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.error!,
                key: const Key('site_visit_error'),
                style: const TextStyle(color: AppColors.destructive),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _PrimaryCta(state: state),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(SiteVisitStep step) {
    switch (step) {
      case SiteVisitStep.map:
        return 'Where is this place?';
      case SiteVisitStep.photos:
        return 'How will the driver recognize it?';
      case SiteVisitStep.customer:
        return 'Who is this for?';
    }
  }
}

class _PrimaryCta extends ConsumerWidget {
  const _PrimaryCta({required this.state});
  final SiteVisitWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(siteVisitWizardProvider.notifier);
    switch (state.step) {
      case SiteVisitStep.map:
        return CbPrimaryButton(
          key: const Key('site_confirm_pin'),
          label: 'Confirm location',
          onPressed: state.canConfirmMap ? notifier.confirmPin : null,
        );
      case SiteVisitStep.photos:
        return CbPrimaryButton(
          key: const Key('site_continue_photos'),
          label: 'Continue',
          onPressed: state.canContinuePhotos ? notifier.continueFromPhotos : null,
        );
      case SiteVisitStep.customer:
        return CbPrimaryButton(
          key: const Key('site_save_finalize'),
          label: state.saving ? 'Saving…' : 'Save site',
          onPressed: state.canSave
              ? () async {
                  final ok = await notifier.saveAndFinalize();
                  if (ok && context.mounted) {
                    final router = GoRouter.maybeOf(context);
                    if (router != null) {
                      context.go(AppRoutes.home);
                    }
                  }
                }
              : null,
        );
    }
  }
}

class _MapStep extends StatelessWidget {
  const _MapStep({
    required this.state,
    required this.onPin,
    required this.onLandmark,
    this.mapPickerBuilder,
  });

  final SiteVisitWizardState state;
  final ValueChanged<SitePin> onPin;
  final ValueChanged<String> onLandmark;
  final MapPinPickerBuilder? mapPickerBuilder;

  @override
  Widget build(BuildContext context) {
    final builder = mapPickerBuilder ?? defaultMapPinPickerBuilder;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          height: 280,
          child: builder(
            context,
            selected: state.pin,
            onChanged: onPin,
          ),
        ),
        const SizedBox(height: 12),
        if (state.pin != null)
          Text(
            key: const Key('site_pin_coords'),
            '${state.pin!.latitude.toStringAsFixed(5)}, ${state.pin!.longitude.toStringAsFixed(5)}',
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('site_landmark'),
          decoration: const InputDecoration(
            labelText: 'Landmark notes',
            border: OutlineInputBorder(),
          ),
          onChanged: onLandmark,
        ),
      ],
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.state,
    required this.onAdd,
    required this.onRemove,
  });

  final SiteVisitWizardState state;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Add at least ${state.config.minPhotos} photo(s).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final photo in state.photos)
              Chip(
                key: Key('site_photo_${photo.id}'),
                label: Text('Photo · ${(photo.bytesLength / 1024).toStringAsFixed(0)} KB'),
                onDeleted: () => onRemove(photo.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('site_add_photo'),
          onPressed: onAdd,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Add photo'),
        ),
        if (state.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return Container(
                  key: Key('site_thumb_$i'),
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CustomerStep extends ConsumerWidget {
  const _CustomerStep({required this.state});
  final SiteVisitWizardState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.customerName != null)
          Text(
            key: const Key('site_customer_label'),
            state.customerName!,
            style: Theme.of(context).textTheme.titleMedium,
          )
        else
          const Text('Pick a customer for this site.'),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('site_pick_customer'),
          onPressed: () {
            // Demo pick — production opens customers search (S05).
            ref.read(siteVisitWizardProvider.notifier).selectCustomer(
                  id: 1,
                  name: 'Walk-in site customer',
                );
          },
          child: const Text('Choose customer'),
        ),
      ],
    );
  }
}
