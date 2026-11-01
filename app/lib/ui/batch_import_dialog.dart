import 'dart:async';

import 'package:flutter/material.dart';

import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'account_help.dart';
import 'widgets.dart';

/// One account read from a pasted line.
class BatchEntry {
  const BatchEntry(this.line, this.email, this.password);

  /// The line's number in the pasted text, from 1.
  final int line;
  final String email;
  final String password;
}

/// Splits one line into its email and password, on the first separator
/// that leaves a bare address (an `@`, no spaces and no other separator)
/// before it and a password after it: `----`, `:`, `,`, `;`, `|` or
/// whitespace. Requiring a bare address keeps "email,password:with:colons"
/// and "email:pass,word" parsing on their first separator only.
(String, String)? _splitLine(String line) {
  for (final sep in ['----', ':', ',', ';', '|']) {
    final i = line.indexOf(sep);
    if (i <= 0) continue;
    final email = line.substring(0, i).trim();
    final password = line.substring(i + sep.length).trim();
    if (email.contains('@') &&
        !email.contains(' ') &&
        !email.contains(':') &&
        !email.contains(',') &&
        !email.contains(';') &&
        !email.contains('|') &&
        password.isNotEmpty) {
      return (email, password);
    }
  }
  final ws = RegExp(r'\s+').firstMatch(line);
  if (ws != null) {
    final email = line.substring(0, ws.start).trim();
    final password = line.substring(ws.end).trim();
    if (email.contains('@') && password.isNotEmpty) return (email, password);
  }
  return null;
}

/// Reads the pasted [text]: one account per non-empty line (see
/// [_splitLine]); the lines that are not accounts come back by number.
({List<BatchEntry> entries, List<int> badLines}) parseBatchImport(String text) {
  final entries = <BatchEntry>[];
  final bad = <int>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final split = _splitLine(line);
    if (split == null) {
      bad.add(i + 1);
    } else {
      entries.add(BatchEntry(i + 1, split.$1, split.$2));
    }
  }
  return (entries: entries, badLines: bad);
}

/// Adds many accounts from pasted text, strictly one at a time: the
/// dialog of the Foxy accounts page's Batch import button. Each account
/// signs in through the core exactly like the single sign-in form, and
/// when Mozilla asks for a sign-in confirmation — which it now does
/// server-side for unverified sessions, in every client — the import
/// PAUSES on that account instead of failing it: an emailed code is
/// typed right in the account's line, and for a confirmation link the
/// line waits while the core polls the session's verification state
/// (the link click finishes the sign-in by itself). Either pause can be
/// skipped, which moves to the next account. A core session is NEVER
/// cancelled from here, not even by skipping: cancelling throws away a
/// sign-in the core could still finish and makes the next attempt
/// start over as a fresh, stricter Mozilla login. A skipped session is
/// simply left to the core, which keeps it for minutes and ends it on
/// its own (if a skipped link is clicked meanwhile, that account can
/// still complete and appear in the list). The run ends with a summary:
/// added, skipped, and failed with the reason on each failed line.
Future<void> showBatchImportDialog(BuildContext context, CoreController core) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BatchImportDialog(core: core),
    );

enum _LineState {
  waiting,
  adding,
  added,
  failed,
  skipped,
  invalid,
  awaitingCode,
  awaitingLink,
}

class _Line {
  _Line(this.number, this.label);

  final int number;

  /// The account's email; the pasted line itself for an unreadable one.
  final String label;
  _LineState state = _LineState.waiting;
  String detail = '';

  /// The confirmation step the line is paused on.
  String step = '';

  /// The paused line's inline code entry.
  final codeText = TextEditingController();

  /// Completed by the paused line's Verify (with the code) or Skip
  /// (with null) button, releasing the import's pause.
  Completer<String?>? completer;

  /// Set by a link-paused line's Skip button.
  bool skipRequested = false;
}

class _BatchImportDialog extends StatefulWidget {
  const _BatchImportDialog({required this.core});

  final CoreController core;

  @override
  State<_BatchImportDialog> createState() => _BatchImportDialogState();
}

class _BatchImportDialogState extends State<_BatchImportDialog> {
  final _text = TextEditingController();
  List<_Line> _lines = const [];
  List<BatchEntry> _entries = const [];
  bool _running = false;
  bool _cancelled = false;
  bool _done = false;
  String? _error;
  int _current = 0;

  @override
  void dispose() {
    _text.dispose();
    for (final line in _lines) {
      line.codeText.dispose();
    }
    super.dispose();
  }

  void _start() {
    final l = AppLocalizations.of(context);
    final parsed = parseBatchImport(_text.text);
    if (parsed.entries.isEmpty && parsed.badLines.isEmpty) {
      setState(() => _error = l.batchImportEmpty);
      return;
    }
    setState(() {
      _error = null;
      for (final line in _lines) {
        line.codeText.dispose();
      }
      _entries = parsed.entries;
      final raw = _text.text.split('\n');
      _lines = [
        for (final e in parsed.entries) _Line(e.line, e.email),
        for (final n in parsed.badLines)
          _Line(n, raw[n - 1].trim())..state = _LineState.invalid,
      ]..sort((a, b) => a.number.compareTo(b.number));
      _running = true;
      _cancelled = false;
      _done = false;
      _current = 0;
    });
    unawaited(_run());
  }

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    for (var i = 0; i < _entries.length; i++) {
      if (_cancelled) break;
      final entry = _entries[i];
      final line = _lines.firstWhere((x) => x.number == entry.line);
      setState(() {
        _current = i + 1;
        line.state = _LineState.adding;
      });
      final (state, detail) = await _importOne(l, entry, line);
      if (!mounted) return;
      setState(() {
        line.state = state;
        line.detail = detail;
      });
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
    });
    widget.core.refresh(accountsToo: true);
  }

  /// Stops the run: releases any pause the current line is sitting on
  /// (its session is left to the core, never cancelled) and prevents
  /// the next line from starting.
  void _cancelRun() {
    setState(() => _cancelled = true);
    for (final line in _lines) {
      line.skipRequested = true;
      final completer = line.completer;
      if (completer != null && !completer.isCompleted) {
        completer.complete(null);
      }
    }
  }

  /// Signs one account in through the core and follows it, pausing for
  /// the person where Mozilla demands a confirmation. Working steps
  /// poll every second under a generous budget — one FxA call alone
  /// may take ninety seconds through a slow route, and the budget is a
  /// working bound, not a hair trigger — but a pause itself is not
  /// budgeted: the person needs as long as the email takes, and the
  /// core session's own fifteen minutes are the real limit.
  Future<(_LineState, String)> _importOne(
    AppLocalizations l,
    BatchEntry entry,
    _Line line,
  ) async {
    final api = widget.core.api;
    if (api == null) {
      final problem = widget.core.unavailable;
      return (
        _LineState.failed,
        problem == null ? '' : describeProblem(l, problem),
      );
    }
    SignInState s;
    try {
      s = await api.startSignIn(entry.email, entry.password);
    } on CoreApiException catch (e) {
      return (_LineState.failed, e.message);
    } on CoreUnavailable catch (e) {
      return (_LineState.failed, describeProblem(l, e));
    }
    var deadline = DateTime.now().add(const Duration(minutes: 5));
    var current = s;
    while (true) {
      switch (current.step) {
        case SignInStep.done:
          return (_LineState.added, '');
        case SignInStep.failed:
          return (_LineState.failed, _reason(l, current));
        case SignInStep.cancelled:
          return (_LineState.failed, l.signInCancelled);
      }
      if (current.step == SignInStep.needEmailCode ||
          current.step == SignInStep.needUnblockCode) {
        line.step = current.step;
        line.detail = current.error;
        final code = await _pauseForCode(line);
        if (_cancelled) return (_LineState.failed, l.signInCancelled);
        if (code == null) return (_LineState.skipped, '');
        try {
          current = await api.answerSignIn(current.id, code);
        } on Exception {
          // The next poll re-reads the state; the core may be busy.
        }
        deadline = DateTime.now().add(const Duration(minutes: 5));
        continue;
      }
      if (current.step == SignInStep.needEmailLink) {
        // The core polls the session's verification state itself, so
        // this line just waits with it — or is skipped.
        line.skipRequested = false;
        if (mounted) setState(() => line.state = _LineState.awaitingLink);
        while (current.step == SignInStep.needEmailLink) {
          if (_cancelled) return (_LineState.failed, l.signInCancelled);
          if (line.skipRequested) return (_LineState.skipped, '');
          await Future<void>.delayed(const Duration(seconds: 1));
          try {
            current = await api.signInState(current.id);
          } on Exception {
            // The next tick retries; the core may be busy.
          }
        }
        deadline = DateTime.now().add(const Duration(minutes: 5));
        continue;
      }
      if (current.needsAnswer) {
        // A CAPTCHA or an authenticator code: the guided pause covers
        // emailed codes only, so this one fails with its reason.
        return (_LineState.failed, l.batchNeedsManual);
      }
      if (_cancelled) {
        // The person stopped the import: stop watching, but leave the
        // session to the core like every other exit from this loop.
        return (_LineState.failed, l.signInCancelled);
      }
      if (DateTime.now().isAfter(deadline)) {
        return (_LineState.failed, l.signInTimedOut);
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        current = await api.signInState(current.id);
      } on Exception {
        // The next tick retries; the core may be busy.
      }
    }
  }

  /// Parks the import on [line] until its Verify button completes the
  /// pause with the typed code, or its Skip button (or a run cancel)
  /// completes it with null.
  Future<String?> _pauseForCode(_Line line) async {
    final completer = Completer<String?>();
    line.completer = completer;
    if (mounted) setState(() => line.state = _LineState.awaitingCode);
    final code = await completer.future;
    line.completer = null;
    if (mounted) setState(() => line.state = _LineState.adding);
    return code;
  }

  void _submitCode(_Line line) {
    final code = line.codeText.text.trim();
    final completer = line.completer;
    if (code.isEmpty || completer == null || completer.isCompleted) return;
    completer.complete(code);
  }

  void _skipLine(_Line line) {
    line.skipRequested = true;
    final completer = line.completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
  }

  /// Why a sign-in failed, in the app's language where it knows the code;
  /// the core's own text otherwise.
  String _reason(AppLocalizations l, SignInState s) => switch (s.errorCode) {
    SignInError.noAccount => l.signInNoAccount,
    SignInError.wrongPassword => l.signInWrongPassword,
    SignInError.noPassword => l.signInNoPassword,
    SignInError.tooManyAttempts => l.signInTooManyAttempts,
    SignInError.unblockCodeRejected => l.signInUnblockRejected,
    SignInError.wrongCode => l.signInWrongCode,
    SignInError.wrongTotp => l.signInWrongTotp,
    SignInError.tooManyCodes => l.signInTooManyCodes,
    SignInError.timedOut => l.signInTimedOut,
    SignInError.network => l.signInNetwork,
    _ => s.error.isNotEmpty ? s.error : l.signInFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final added = _lines.where((x) => x.state == _LineState.added).length;
    final skipped = _lines.where((x) => x.state == _LineState.skipped).length;
    final failed = _lines.where((x) => x.state == _LineState.failed).length;
    return AlertDialog(
      title: Text(l.batchImport),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.batchImportHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            const AccountHelpLinks(),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              enabled: !_running,
              minLines: 5,
              maxLines: 8,
              textDirection: TextDirection.ltr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'email@example.com:password',
                hintTextDirection: TextDirection.ltr,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: StatusColors.bad,
                ),
              ),
            ],
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final line in _lines) _lineRow(theme, l, line),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _running
                    ? l.batchProgress(_current, _entries.length)
                    : '${l.batchSummary(added, failed)}'
                          '${skipped > 0 ? ', ${l.batchSkipped(skipped)}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? _cancelRun : () => Navigator.of(context).pop(),
          child: Text(_running || !_done ? l.cancel : l.close),
        ),
        if (!_done)
          FilledButton(
            onPressed: _running ? null : _start,
            child: Text(l.batchImportAction),
          ),
      ],
    );
  }

  Widget _lineRow(ThemeData theme, AppLocalizations l, _Line line) {
    final (icon, color, note) = switch (line.state) {
      _LineState.waiting => (Icons.schedule_rounded, StatusColors.idle, ''),
      _LineState.adding => (Icons.sync_rounded, StatusColors.busy, ''),
      _LineState.added => (
        Icons.check_circle_rounded,
        StatusColors.good,
        l.batchAdded,
      ),
      _LineState.failed => (Icons.error_rounded, StatusColors.bad, line.detail),
      _LineState.skipped => (
        Icons.skip_next_rounded,
        StatusColors.idle,
        l.batchLineSkipped,
      ),
      _LineState.invalid => (
        Icons.warning_amber_rounded,
        StatusColors.busy,
        l.batchLineInvalid,
      ),
      _LineState.awaitingCode => (
        Icons.mark_email_unread_rounded,
        StatusColors.busy,
        '',
      ),
      _LineState.awaitingLink => (
        Icons.mark_email_unread_rounded,
        StatusColors.busy,
        '',
      ),
    };
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (line.state == _LineState.adding)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.label.isEmpty ? '${line.number}' : line.label,
              textDirection: line.label.contains('@')
                  ? TextDirection.ltr
                  : null,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                note,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ],
      ),
    );
    if (line.state == _LineState.awaitingLink) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.stepEmailLink(line.label),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: StatusColors.busy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _skipLine(line),
                  child: Text(l.batchSkip),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (line.state == _LineState.awaitingCode) {
      final prompt = line.step == SignInStep.needUnblockCode
          ? l.stepUnblockCode(line.label)
          : l.stepEmailCode(line.label);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28, bottom: 4),
            child: Text(
              line.detail.isNotEmpty ? line.detail : prompt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StatusColors.busy,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 28, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.codeText,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '123456',
                      hintTextDirection: TextDirection.ltr,
                    ),
                    onSubmitted: (_) => _submitCode(line),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _submitCode(line),
                  child: Text(l.continueLabel),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _skipLine(line),
                  child: Text(l.batchSkip),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return row;
  }
}
