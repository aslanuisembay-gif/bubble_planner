import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../translations.dart' show tr, trFill;

/// Область: эта задача / все в контексте / выбранные / выбрать галочками.
enum TaskScope { anchorTask, all, selected, pickWithCheckmarks }

/// Канал отправки текста.
enum ShareChannel { whatsapp, telegram, sms, more, copy, link, qr }

String _buildShareLink(String text) {
  final encoded = Uri.encodeComponent(text.trim());
  return 'https://bubble.bostonglobal.org/share?tasks=$encoded';
}

Future<void> _showQrShareSheet(BuildContext context, String link) async {
  final lang = context.read<AppState>().languageCode;
  final bp = context.bp;
  final qrUrl =
      'https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${Uri.encodeComponent(link)}';
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom + 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bp.modalSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bp.modalBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    tr('shareQrTitle', lang: lang),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: bp.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: bp.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  qrUrl,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 220,
                    height: 220,
                    color: bp.listCardFill,
                    alignment: Alignment.center,
                    child: Icon(Icons.qr_code_rounded, size: 70, color: bp.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('shareQrHint', lang: lang),
                style: TextStyle(color: bp.textSecondary),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(tr('toastTextCopied', lang: lang))),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(tr('shareLink', lang: lang)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Set<String> _defaultUniverse(AppState state) => state.tasks.map((e) => e.id).toSet();

int _selectedCountInUniverse(AppState state, Set<String> universe) =>
    state.selectedTaskIds.where(universe.contains).length;

/// Нижний лист: что сделать с задачами (шаринг или удаление — разные [titleKey] / подписи).
Future<TaskScope?> showTaskScopeSheet(
  BuildContext context,
  AppState state, {
  required String titleKey,
  Set<String>? universeIds,
  String? anchorTaskId,
  String thisTaskKey = 'scopeThisTask',
  String allLabelKey = 'shareAllTasks',
  String selectedLabelKey = 'shareSelectedOnly',
  String pickLabelKey = 'sharePickTasks',
  bool allowPickWithCheckmarks = true,
}) async {
  final lang = state.languageCode;
  final universe = universeIds ?? _defaultUniverse(state);
  final nSel = _selectedCountInUniverse(state, universe);
  final bp = context.bp;
  final showAnchor =
      anchorTaskId != null && universe.contains(anchorTaskId);

  return showModalBottomSheet<TaskScope>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom + 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bp.modalSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bp.modalBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(titleKey, lang: lang),
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      color: bp.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (showAnchor) ...[
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, TaskScope.anchorTask),
                  child: Text(tr(thisTaskKey, lang: lang)),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: () => Navigator.pop(ctx, TaskScope.all),
                child: Text(tr(allLabelKey, lang: lang)),
              ),
              if (nSel > 0) ...[
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: bp.talkAccent,
                    foregroundColor: bp.onPrimary,
                  ),
                  onPressed: () => Navigator.pop(ctx, TaskScope.selected),
                  child: Text(trFill(selectedLabelKey, {'n': '$nSel'}, lang: lang)),
                ),
              ],
              if (allowPickWithCheckmarks) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, TaskScope.pickWithCheckmarks),
                  child: Text(tr(pickLabelKey, lang: lang)),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel', lang: lang)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<ShareChannel?> showShareChannelSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final lang = state.languageCode;
  final bp = context.bp;
  return showModalBottomSheet<ShareChannel>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom + 12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bp.modalSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bp.modalBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('shareHowTitle', lang: lang),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: bp.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                title: Text(tr('shareWhatsApp', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.whatsapp),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFF0088CC)),
                title: Text(tr('shareTelegram', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.telegram),
              ),
              ListTile(
                leading: Icon(Icons.sms_outlined, color: bp.textPrimary),
                title: Text(tr('shareSms', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.sms),
              ),
              ListTile(
                leading: Icon(Icons.ios_share_rounded, color: bp.textPrimary),
                title: Text(tr('shareMore', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.more),
              ),
              ListTile(
                leading: Icon(Icons.copy_rounded, color: bp.textSecondary),
                title: Text(tr('shareCopy', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.copy),
              ),
              ListTile(
                leading: Icon(Icons.link_rounded, color: bp.textPrimary),
                title: Text(tr('shareLink', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.link),
              ),
              ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: bp.textPrimary),
                title: Text(tr('shareQr', lang: lang), style: TextStyle(color: bp.textPrimary)),
                onTap: () => Navigator.pop(ctx, ShareChannel.qr),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> dispatchTaskShare(
  BuildContext context,
  ShareChannel channel,
  String text,
) async {
  if (text.trim().isEmpty) return;
  final lang = context.read<AppState>().languageCode;

  Future<void> copyOnly() async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('toastTextCopied', lang: lang))),
      );
    }
  }
  final shareLink = _buildShareLink(text);

  switch (channel) {
    case ShareChannel.whatsapp:
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await copyOnly();
      }
      break;
    case ShareChannel.telegram:
      final uri = Uri.parse('https://t.me/share/url?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await copyOnly();
      }
      break;
    case ShareChannel.sms:
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await copyOnly();
      }
      break;
    case ShareChannel.more:
      await SharePlus.instance.share(ShareParams(text: text));
      break;
    case ShareChannel.copy:
      await copyOnly();
      break;
    case ShareChannel.link:
      await Clipboard.setData(ClipboardData(text: shareLink));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('toastTextCopied', lang: lang))),
        );
      }
      break;
    case ShareChannel.qr:
      await _showQrShareSheet(context, shareLink);
      break;
  }
}

Iterable<String>? _idsForScope(
  AppState state,
  TaskScope scope, {
  required Set<String> universe,
  String? anchorTaskId,
}) {
  switch (scope) {
    case TaskScope.anchorTask:
      if (anchorTaskId == null || !universe.contains(anchorTaskId)) {
        return null;
      }
      return [anchorTaskId];
    case TaskScope.all:
      return universe;
    case TaskScope.selected:
      final ids = state.selectedTaskIds.where(universe.contains).toList();
      if (ids.isEmpty) return null;
      return ids;
    case TaskScope.pickWithCheckmarks:
      return null;
  }
}

Future<void> runTasksListShareFlow(
  BuildContext context, {
  required void Function(bool bulkMode) setBulkMode,
  String? anchorTaskId,
  Set<String>? universeIds,
  bool allowPickWithCheckmarks = true,
  String allLabelKey = 'shareAllTasks',
}) async {
  final state = context.read<AppState>();
  final universe = universeIds ?? _defaultUniverse(state);
  final scope = await showTaskScopeSheet(
    context,
    state,
    titleKey: 'shareSheetTitle',
    universeIds: universe,
    anchorTaskId: anchorTaskId,
    thisTaskKey: 'scopeThisTask',
    allLabelKey: allLabelKey,
    selectedLabelKey: 'shareSelectedOnly',
    pickLabelKey: 'sharePickTasks',
    allowPickWithCheckmarks: allowPickWithCheckmarks,
  );
  if (!context.mounted || scope == null) return;

  if (scope == TaskScope.pickWithCheckmarks) {
    state.clearSelection();
    setBulkMode(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('sharePickTasksHint', lang: state.languageCode))),
    );
    return;
  }

  final ids = _idsForScope(state, scope, universe: universe, anchorTaskId: anchorTaskId);
  if (ids == null) return;

  final text = state.shareTextForTasks(ids);
  if (text.trim().isEmpty) return;
  final ch = await showShareChannelSheet(context);
  if (!context.mounted || ch == null) return;
  await dispatchTaskShare(context, ch, text);
}

Future<void> runTasksListDeleteFlow(
  BuildContext context, {
  required void Function(bool bulkMode) setBulkMode,
  String? anchorTaskId,
  Set<String>? universeIds,
  bool allowPickWithCheckmarks = true,
  String allLabelKey = 'shareAllTasks',
}) async {
  final state = context.read<AppState>();
  final universe = universeIds ?? _defaultUniverse(state);
  final scope = await showTaskScopeSheet(
    context,
    state,
    titleKey: 'deleteSheetTitle',
    universeIds: universe,
    anchorTaskId: anchorTaskId,
    thisTaskKey: 'scopeThisTask',
    allLabelKey: allLabelKey,
    selectedLabelKey: 'shareSelectedOnly',
    pickLabelKey: 'sharePickTasks',
    allowPickWithCheckmarks: allowPickWithCheckmarks,
  );
  if (!context.mounted || scope == null) return;

  if (scope == TaskScope.pickWithCheckmarks) {
    state.clearSelection();
    setBulkMode(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('deletePickTasksHint', lang: state.languageCode))),
    );
    return;
  }

  final ids = _idsForScope(state, scope, universe: universe, anchorTaskId: anchorTaskId);
  if (ids == null) return;

  state.deleteTasksByIds(ids);
  state.clearSelection();
  setBulkMode(false);
}
