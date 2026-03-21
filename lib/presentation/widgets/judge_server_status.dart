import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/judge_web_server_status.dart';
import '../../localization/app_localizations.dart';

class JudgeServerStatusIndicator extends StatelessWidget {
  const JudgeServerStatusIndicator({
    super.key,
    required this.languageCode,
    required this.status,
    required this.isSetupMode,
    this.showDetails = false,
  });

  final String languageCode;
  final JudgeWebServerStatus status;
  final bool isSetupMode;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final isOnline = status.isRunning;
    final statusColor = isOnline ? Colors.greenAccent : Colors.orangeAccent;
    final statusLabel = isSetupMode
        ? AppLocalizations.tr(languageCode, 'judgeWebServerSetupStopped')
        : isOnline
            ? AppLocalizations.tr(languageCode, 'judgeWebServerRunning')
            : AppLocalizations.tr(languageCode, 'judgeWebServerStopped');

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (showDetails)
          TextButton.icon(
            onPressed: () => showJudgeServerDetailsDialog(
              context,
              languageCode: languageCode,
              status: status,
            ),
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(AppLocalizations.tr(languageCode, 'judgeWebStatusDetails')),
          ),
      ],
    );
  }
}

Future<void> showJudgeServerDetailsDialog(
  BuildContext context, {
  required String languageCode,
  required JudgeWebServerStatus status,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(AppLocalizations.tr(languageCode, 'judgeWebStatusDialogTitle')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status.urls.isEmpty)
              Text(AppLocalizations.tr(languageCode, 'judgeWebStatusDialogEmpty'))
            else
              ...status.urls.map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            url,
                            style: const TextStyle(color: Colors.lightBlueAccent),
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.tr(languageCode, 'judgeWebCopyAddress'),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!dialogContext.mounted) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.tr(languageCode, 'judgeWebAddressCopied'),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (status.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.tr(languageCode, 'judgeWebServerError')}: ${status.errorMessage}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.tr(languageCode, 'close')),
        ),
      ],
    ),
  );
}
