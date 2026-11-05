import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../theme/fluent_theme.dart';

class FluentTransferBar extends StatelessWidget {
  const FluentTransferBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();

    if (!explorer.isTransferring) {
      return const SizedBox.shrink();
    }

    final percent = (explorer.transferProgress * 100).clamp(0, 100).toInt();

    return InkWell(
      onTap: () => TransferDetailsSheet.show(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.08),
          border: Border(
            bottom: BorderSide(color: colors.primary.withOpacity(0.25), width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.sync, size: 16, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          explorer.transferTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        explorer.transferSpeed.isNotEmpty ? '$percent%  ${explorer.transferSpeed}' : '$percent%',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: explorer.transferProgress > 0 ? explorer.transferProgress : null,
                      minHeight: 3.5,
                      backgroundColor: colors.containerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'Cancel Operation',
              child: InkWell(
                onTap: () => explorer.cancelTransfer(),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.close, size: 14, color: colors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransferDetailsSheet extends StatelessWidget {
  const TransferDetailsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TransferDetailsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();

    final percent = (explorer.transferProgress * 100).clamp(0, 100).toInt();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.sync, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Operation Progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: colors.textSecondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explorer.transferTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                explorer.transferSpeed.isNotEmpty ? 'Speed: ${explorer.transferSpeed}' : 'Status: ${explorer.isTransferring ? "In Progress" : "Idle"}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textSecondary),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: explorer.transferProgress > 0 ? explorer.transferProgress : null,
              minHeight: 6,
              backgroundColor: colors.containerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: explorer.isTransferring
                    ? () {
                        explorer.cancelTransfer();
                        Navigator.pop(context);
                      }
                    : null,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Operation'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
