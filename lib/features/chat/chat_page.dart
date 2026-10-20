import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/connectivity/connectivity.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/chat/chat_models.dart';
import '../../data/chat/chat_providers.dart';
import '../../data/chat/chat_repository.dart';
import '../../data/lessons/lesson_providers.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

const _chatLangKey = 'chat_language';

/// Module chat (BACKEND_CONTRACT D, MASTER_PLAN 7.8): cached messages stay
/// readable offline; sending offline queues the message ("sending...");
/// after 3 failed tries it shows "tap to retry". Realtime brings new
/// messages, deletions and translations.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.moduleId});

  final int moduleId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  late final ChatRepository _repo;
  late final SupabaseClient? _client;
  final _input = TextEditingController();
  final _shownOriginal = <String>{};
  List<ChatMessage> _messages = const [];
  List<PendingMessage> _pending = const [];
  bool _loading = true;
  bool _loadingOlder = false;
  bool _noMoreOlder = false;
  AppFailure? _failure;
  RealtimeChannel? _channel;
  Timer? _refreshSoon;

  int get _module => widget.moduleId;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(chatRepositoryProvider);
    _client = ref.read(supabaseClientProvider);
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _refreshSoon?.cancel();
    final channel = _channel;
    final client = _client;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    _input.dispose();
    super.dispose();
  }

  Future<void> _reloadLocal() async {
    final messages = await _repo.cached(_module);
    final pending = await _repo.pending(_module);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _pending = pending;
    });
  }

  Future<void> _start() async {
    await _reloadLocal();
    if (mounted) setState(() => _loading = _messages.isEmpty);
    await _syncLanguage();
    await _refresh();
    await _flush();
    _subscribe();
  }

  /// Translations come in the profile's preferred language: keep it equal
  /// to the app language (set_language, once per change).
  Future<void> _syncLanguage() async {
    if (!mounted) return;
    final lang = Localizations.localeOf(context).languageCode;
    final prefs = ref.read(sharedPrefsProvider);
    final api = ref.read(kampusApiProvider);
    if (api == null || prefs.getString(_chatLangKey) == lang) return;
    final result = await guard(() => api.setLanguage(lang));
    if (result is Ok) await prefs.setString(_chatLangKey, lang);
  }

  Future<void> _refresh() async {
    final result = await guard(() => _repo.refresh(_module));
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case Ok(:final value):
          _messages = value;
          _failure = null;
        case Err(:final failure):
          _failure = failure;
      }
    });
  }

  void _refreshLater() {
    _refreshSoon?.cancel();
    _refreshSoon = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty || !ref.read(isOnlineProvider)) return;
    final report = await _repo.sendPending(_module);
    await _reloadLocal();
    if (report.sent > 0) await _refresh();
    if (!mounted) return;
    if (report.failure is RateLimitedFailure) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.errorRateLimited)));
    }
  }

  void _subscribe() {
    final client = _client;
    if (client == null || !mounted) return;
    final uiLang = Localizations.localeOf(context).languageCode;
    final moduleFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'module_id',
      value: _module,
    );
    _channel = client
        .channel('chat-$_module')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'module_chat_messages',
          filter: moduleFilter,
          callback: (_) => _refreshLater(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'module_chat_messages',
          filter: moduleFilter,
          callback: (payload) async {
            final id = payload.newRecord['id']?.toString();
            if (id != null && payload.newRecord['deleted_at'] != null) {
              await _repo.removeMessage(_module, id);
              await _reloadLocal();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_translations',
          callback: (payload) async {
            final r = payload.newRecord;
            if ('${r['lang']}' != uiLang) return;
            final changed = await _repo.applyTranslation(
              _module,
              '${r['message_id']}',
              '${r['lang']}',
              '${r['body'] ?? ''}',
            );
            if (changed) await _reloadLocal();
          },
        )
        .subscribe();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    HapticFeedback.selectionClick();
    await _repo.queue(_module, text);
    await _reloadLocal();
    await _flush();
  }

  Future<void> _retry(PendingMessage p) async {
    await _repo.retry(_module, p.clientId);
    await _reloadLocal();
    await _flush();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _noMoreOlder || !ref.read(isOnlineProvider)) return;
    setState(() => _loadingOlder = true);
    final result = await guard(() => _repo.loadOlder(_module));
    await _reloadLocal();
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      if (result case Ok(:final value) when value == 0) _noMoreOlder = true;
    });
  }

  Future<void> _actions(ChatMessage m) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(kampusApiProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(MaterialLocalizations.of(context).copyButtonLabel),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            if (m.isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l10n.chatDelete),
                onTap: () => Navigator.pop(context, 'delete'),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.chatReport),
                onTap: () => Navigator.pop(context, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded),
                title: Text(l10n.chatBlock(m.username)),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: m.body));
      case 'delete':
        if (api == null) return;
        final r = await guard(() => api.deleteChatMessage(m.id));
        if (r is Ok) {
          await _repo.removeMessage(_module, m.id);
          await _reloadLocal();
        } else if (r case Err(:final failure)) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureMessage(l10n, failure))),
          );
        }
      case 'report':
        if (!mounted) return;
        final report = await showDialog<(String, String)>(
          context: context,
          builder: (_) => const _ReportDialog(),
        );
        if (report == null || api == null) return;
        final r = await guard(
          () => api.report(
            targetType: 'module_message',
            targetId: m.id,
            reason: report.$1,
            details: report.$2,
          ),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (r) {
              Ok() => l10n.reportThanks,
              Err(:final failure) => failureMessage(l10n, failure),
            }),
          ),
        );
      case 'block':
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.blockConfirmTitle(m.username)),
            content: Text(l10n.blockConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.chatBlock(m.username)),
              ),
            ],
          ),
        );
        if (ok != true || api == null) return;
        final r = await guard(() => api.blockUser(m.userId));
        if (r is Ok) {
          await _repo.removeUser(_module, m.userId);
          await _reloadLocal();
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.blockDone(m.username))),
          );
        } else if (r case Err(:final failure)) {
          messenger.showSnackBar(
            SnackBar(content: Text(failureMessage(l10n, failure))),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (previous == false && next) {
        _refresh();
        _flush();
      }
    });
    final module = switch (ref.watch(moduleProvider(_module))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final uiLang = Localizations.localeOf(context).languageCode;
    final accent = moduleAccent(_module);
    final items = <Object>[..._pending.reversed, ..._messages];
    final Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (items.isEmpty) {
      body = _failure == null
          ? EmptyView(icon: Icons.forum_outlined, title: l10n.chatEmpty)
          : ErrorView(failure: _failure!, onRetry: _refresh);
    } else {
      body = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.md,
          vertical: KSpace.sm,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == items.length) {
            if (!_noMoreOlder) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadOlder());
            }
            return Padding(
              padding: const EdgeInsets.all(KSpace.md),
              child: Center(
                child: _loadingOlder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          final item = items[i];
          final Widget bubble;
          if (item is PendingMessage) {
            bubble = _PendingBubble(
              message: item,
              accent: accent,
              onRetry: () => _retry(item),
            );
          } else {
            final m = item as ChatMessage;
            final older = i + 1 < items.length ? items[i + 1] : null;
            final showName =
                !m.isMine &&
                !(older is ChatMessage && older.userId == m.userId);
            bubble = _Bubble(
              message: m,
              accent: accent,
              showName: showName,
              uiLang: uiLang,
              showOriginal: _shownOriginal.contains(m.id),
              onToggleOriginal: () => setState(() {
                if (!_shownOriginal.remove(m.id)) _shownOriginal.add(m.id);
              }),
              onLongPress: () => _actions(m),
            );
          }
          return MaxWidth(child: bubble);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chatTitle),
            if (module != null)
              Text(
                module.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.kc.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: body),
          _Composer(
            controller: _input,
            accent: accent,
            onSend: _input.text.trim().isEmpty ? null : _send,
          ),
        ],
      ),
    );
  }
}

String _time(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(t));

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.accent,
    required this.showName,
    required this.uiLang,
    required this.showOriginal,
    required this.onToggleOriginal,
    required this.onLongPress,
  });

  final ChatMessage message;
  final Color accent;
  final bool showName;
  final String uiLang;
  final bool showOriginal;
  final VoidCallback onToggleOriginal;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final m = message;
    final translated = !m.isMine && m.translatedBody != null;
    final text = translated && !showOriginal ? m.translatedBody! : m.body;
    final waiting =
        !m.isMine &&
        !translated &&
        m.lang != 'und' &&
        m.lang != uiLang &&
        DateTime.now().difference(m.createdAt) < const Duration(minutes: 3);
    final fg = m.isMine ? Colors.white : kc.textPrimary;
    final quiet = m.isMine
        ? Colors.white.withValues(alpha: 0.75)
        : kc.textSecondary;
    return Align(
      alignment: m.isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: showName ? KSpace.md : 3),
          child: Material(
            color: m.isMine ? accent : kc.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: m.isMine ? BorderSide.none : BorderSide(color: kc.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.md,
                  KSpace.sm,
                  KSpace.md,
                  KSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      Text(
                        '@${m.username}',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Directionality(
                      textDirection: guessLang(text) == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: SelectableText(
                        text,
                        style: TextStyle(color: fg, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: KSpace.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _time(context, m.createdAt),
                          style: TextStyle(color: quiet, fontSize: 11),
                        ),
                        if (translated)
                          GestureDetector(
                            onTap: onToggleOriginal,
                            child: Text(
                              showOriginal
                                  ? l10n.chatShowTranslation
                                  : '${l10n.chatTranslated} \u00b7 ${l10n.chatShowOriginal}',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (waiting)
                          Text(
                            l10n.chatTranslating,
                            style: TextStyle(
                              color: quiet,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({
    required this.message,
    required this.accent,
    required this.onRetry,
  });

  final PendingMessage message;
  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final failed = message.failed;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Material(
            color: accent.withValues(alpha: failed ? 0.25 : 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: failed ? BorderSide(color: kc.danger) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: failed ? onRetry : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KSpace.md,
                  KSpace.sm,
                  KSpace.md,
                  KSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: message.lang == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        message.body,
                        style: TextStyle(
                          color: failed ? kc.textPrimary : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          failed
                              ? Icons.error_outline_rounded
                              : Icons.schedule_rounded,
                          size: 12,
                          color: failed ? kc.danger : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          failed ? l10n.chatFailed : l10n.chatSending,
                          style: TextStyle(
                            fontSize: 11,
                            color: failed ? kc.danger : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.accent,
    required this.onSend,
  });

  final TextEditingController controller;
  final Color accent;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Material(
      color: kc.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpace.md,
            KSpace.sm,
            KSpace.sm,
            KSpace.sm,
          ),
          child: MaxWidth(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                    decoration: InputDecoration(
                      hintText: l10n.chatHint,
                      isDense: true,
                      filled: true,
                      fillColor: kc.surfaceRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: KSpace.lg,
                        vertical: KSpace.md,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KSpace.sm),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: l10n.chatSend,
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _reason = 'spam';
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = [
      ('spam', l10n.reportSpam),
      ('harassment', l10n.reportHarassment),
      ('wrong_information', l10n.reportWrong),
      ('other', l10n.reportOther),
    ];
    return AlertDialog(
      title: Text(l10n.reportTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: [
                  for (final (value, label) in reasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: value,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.reportDetails),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_reason, _details.text.trim())),
          child: Text(l10n.reportSend),
        ),
      ],
    );
  }
}
