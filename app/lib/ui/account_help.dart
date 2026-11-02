import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../platform.dart';
import 'widgets.dart';

/// The help row under the sign-in forms: create a Firefox account (in
/// the system browser), and the dot method that makes many accounts
/// out of one Gmail inbox. Shown by the single sign-in dialog and the
/// sign-in dialog alike.
class AccountHelpLinks extends StatelessWidget {
  const AccountHelpLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        TextButton.icon(
          onPressed: () => openUrl(firefoxAccountSignUpUrl),
          icon: const Icon(Icons.person_add_alt_rounded, size: 18),
          label: Text(l.createAccountButton),
        ),
        TextButton.icon(
          onPressed: () => showDotMethodDialog(context),
          icon: const Icon(Icons.alternate_email_rounded, size: 18),
          label: Text(l.dotMethodEntry),
        ),
      ],
    );
  }
}

/// Explains the dot method (روش دات): Gmail ignores the dots in an
/// address, so each dotted version of one address is a fresh email for
/// a Firefox sign-up while every verification mail still lands in the
/// same single inbox.
Future<void> showDotMethodDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _DotMethodDialog(),
);

class _DotMethodDialog extends StatelessWidget {
  const _DotMethodDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = <(IconData, String)>[
      (Icons.person_add_alt_rounded, l.dotMethodStep1),
      (Icons.mark_email_read_rounded, l.dotMethodStep2),
      (Icons.done_all_rounded, l.dotMethodStep3),
    ];
    return AlertDialog(
      icon: const Icon(Icons.alternate_email_rounded, size: 32),
      title: Text(l.dotMethodTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.dotMethodIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.dotMethodPoint,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < steps.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        steps[i].$1,
                        size: 17,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          steps[i].$2,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Text(l.dotMethodExample, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'name@gmail.com',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '→  n.ame@gmail.com\n→  na.me@gmail.com\n→  nam.e@gmail.com\n→  …',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
        FilledButton.icon(
          onPressed: () => openUrl(firefoxAccountSignUpUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(l.createAccountButton),
        ),
      ],
    );
  }
}
