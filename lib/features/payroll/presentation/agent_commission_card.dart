import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../application/agent_commission_controller.dart';

/// Field sales home card: daily band commission + previous-day navigation.
class AgentCommissionCard extends ConsumerStatefulWidget {
  const AgentCommissionCard({super.key});

  @override
  ConsumerState<AgentCommissionCard> createState() =>
      _AgentCommissionCardState();
}

class _AgentCommissionCardState extends ConsumerState<AgentCommissionCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(agentCommissionProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentCommissionProvider);
    final theme = Theme.of(context);
    final day = state.day;
    final today = agentCommissionTodayLocal();

    return Card(
      key: const Key('agent_commission_card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily commission',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('agent_commission_prev'),
                  tooltip: 'Previous day',
                  onPressed: state.loading
                      ? null
                      : () =>
                            ref.read(agentCommissionProvider.notifier).shiftDay(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  state.date.isEmpty ? today : state.date,
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  key: const Key('agent_commission_next'),
                  tooltip: 'Next day',
                  onPressed: state.loading || state.date.compareTo(today) >= 0
                      ? null
                      : () =>
                            ref.read(agentCommissionProvider.notifier).shiftDay(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (state.error != null)
              Text(
                state.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else if (day == null || !day.enabled)
              Text(
                'Sales commission is turned off for this store.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Text(
                'Qualifying sales',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                formatKes(day.qualifyingSales),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (day.excludedLines > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${formatKes(day.excludedLines)} in product lines that do not '
                  'qualify (still on your sales)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      theme,
                      'Commission',
                      formatKes(day.commission),
                      emphasis: true,
                    ),
                  ),
                  Expanded(
                    child: _metric(
                      theme,
                      'Transport',
                      formatKes(day.transportAmount),
                    ),
                  ),
                ],
              ),
              if (day.nextBandSalesToGo != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${formatKes(day.nextBandSalesToGo!)} to next band'
                  '${day.nextBandCommission == null ? '' : ' (${formatKes(day.nextBandCommission!)})'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (day.transportNote.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  day.transportNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (day.bands.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Award bands',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ...List.generate(day.bands.length, (idx) {
                  final band = day.bands[idx];
                  final active = idx == day.bandIndex;
                  final maxLabel =
                      band.max == null ? 'and above' : '– ${band.max}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      key: Key('agent_commission_band_$idx'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : AppColors.mutedForeground.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${band.min} $maxLabel'
                              '${active ? ' · your band' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight:
                                    active ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          Text(
                            formatKes(_asBandMoney(band.commission)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  double _asBandMoney(String raw) =>
      double.tryParse(raw.replaceAll(',', '')) ?? 0;

  Widget _metric(
    ThemeData theme,
    String label,
    String value, {
    bool emphasis = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: emphasis ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}
