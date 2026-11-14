import 'package:flutter/material.dart';
import '../theme/fluent_theme.dart';

enum DeleteAction { recycle, permanent }

class FluentDeleteDialog extends StatefulWidget {
  final int itemCount;
  final String? singleItemName;

  const FluentDeleteDialog({
    super.key,
    required this.itemCount,
    this.singleItemName,
  });

  static Future<DeleteAction?> show(
    BuildContext context, {
    required int itemCount,
    String? singleItemName,
  }) {
    return showDialog<DeleteAction>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FluentDeleteDialog(
        itemCount: itemCount,
        singleItemName: singleItemName,
      ),
    );
  }

  @override
  State<FluentDeleteDialog> createState() => _FluentDeleteDialogState();
}

class _FluentDeleteDialogState extends State<FluentDeleteDialog> {
  DeleteAction _selectedAction = DeleteAction.recycle;

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final isMultiple = widget.itemCount > 1;

    final titleText = isMultiple ? 'Delete ${widget.itemCount} Items' : 'Delete Item';
    final subtitleText = isMultiple
        ? 'Choose what you want to do with the selected items:'
        : 'Choose what you want to do with "${widget.singleItemName ?? 'this item'}":';

    return Dialog(
      backgroundColor: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle, width: 1),
      ),
      elevation: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (_selectedAction == DeleteAction.recycle ? colors.primary : colors.error)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _selectedAction == DeleteAction.recycle
                          ? Icons.delete_sweep_outlined
                          : Icons.delete_forever_outlined,
                      color: _selectedAction == DeleteAction.recycle ? colors.primary : colors.error,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Move to Recycle Bin (Recommended)
              _buildOptionCard(
                colors: colors,
                action: DeleteAction.recycle,
                title: 'Move to Recycle Bin',
                badgeText: 'Recommended',
                badgeColor: colors.primary,
                description: 'Files remain safe and can be restored anytime before retention expires.',
                icon: Icons.restore_from_trash_outlined,
              ),

              const SizedBox(height: 10),

              // Option 2: Permanently Delete
              _buildOptionCard(
                colors: colors,
                action: DeleteAction.permanent,
                title: 'Permanently Delete',
                badgeText: 'Irreversible',
                badgeColor: colors.error,
                description: 'Files are deleted immediately and cannot be recovered.',
                icon: Icons.delete_forever_outlined,
              ),

              const SizedBox(height: 22),

              // Action Buttons: Balanced Cancel & Confirm
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      side: BorderSide(color: colors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    icon: Icon(
                      _selectedAction == DeleteAction.recycle
                          ? Icons.delete_sweep_outlined
                          : Icons.delete_forever,
                      size: 16,
                    ),
                    label: Text(_selectedAction == DeleteAction.recycle ? 'Move to Bin' : 'Delete Now'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _selectedAction == DeleteAction.recycle ? colors.primary : colors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selectedAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required FluentColors colors,
    required DeleteAction action,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedAction == action;

    return InkWell(
      onTap: () => setState(() => _selectedAction = action),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? badgeColor.withOpacity(0.08) : colors.container,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? badgeColor : colors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Radio<DeleteAction>(
                value: action,
                groupValue: _selectedAction,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAction = val);
                },
                activeColor: badgeColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
