import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/reminders/reminder_state.dart';
import '../../l10n/app_localizations.dart';

/// Short day name for an ISO day (1 = Monday), in the app language.
String reminderDayName(BuildContext context, int isoDay) {
  try {
    final locale = Localizations.localeOf(context).languageCode;
    // 1 January 2024 was a Monday.
    return DateFormat.E(locale).format(DateTime(2024, 1, isoDay));
  } catch (_) {
    return MaterialLocalizations.of(context).narrowWeekdays[isoDay % 7];
  }
}

/// "19:00" shown the way the phone shows times (24 h or AM/PM).
String reminderTimeText(BuildContext context, String time) {
  final t = normalizeTime(time);
  return TimeOfDay(
    hour: int.parse(t.substring(0, 2)),
    minute: int.parse(t.substring(3, 5)),
  ).format(context);
}

/// Study time + days. Used by onboarding and Profile > Reminders.
class ReminderForm extends StatelessWidget {
  const ReminderForm({
    super.key,
    required this.time,
    required this.days,
    required this.onTime,
    required this.onDays,
  });

  final String time;
  final List<int> days;
  final ValueChanged<String> onTime;
  final ValueChanged<List<int>> onDays;

  Future<void> _pick(BuildContext context) async {
    final t = normalizeTime(time);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(t.substring(0, 2)),
        minute: int.parse(t.substring(3, 5)),
      ),
    );
    if (picked != null) {
      onTime(normalizeTime('${picked.hour}:${picked.minute}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.schedule_rounded, color: kc.accentText),
          title: Text(l10n.reminderTimeLabel),
          trailing: Text(
            reminderTimeText(context, time),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          onTap: () => _pick(context),
        ),
        const SizedBox(height: KSpace.sm),
        Text(l10n.reminderDaysLabel, style: TextStyle(color: kc.textSecondary)),
        const SizedBox(height: KSpace.sm),
        Wrap(
          spacing: KSpace.sm,
          runSpacing: KSpace.sm,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(reminderDayName(context, d)),
                selected: days.contains(d),
                onSelected: (on) {
                  final next = {...days};
                  if (on) {
                    next.add(d);
                  } else if (next.length > 1) {
                    next.remove(d);
                  }
                  onDays(normalizeDays(next.toList()));
                },
              ),
          ],
        ),
      ],
    );
  }
}
