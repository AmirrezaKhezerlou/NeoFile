import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_item.dart';
import '../theme/fluent_theme.dart';
import 'fluent_file_icons.dart';

class FilePropertiesSheet extends StatefulWidget {
  final FileItem item;

  const FilePropertiesSheet({super.key, required this.item});

  static void show(BuildContext context, FileItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilePropertiesSheet(item: item),
    );
  }

  @override
  State<FilePropertiesSheet> createState() => _FilePropertiesSheetState();
}

class _FilePropertiesSheetState extends State<FilePropertiesSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late bool _isReadOnly;
  late bool _isHidden;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isReadOnly = false;
    _isHidden = widget.item.isHidden;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final dateFormat = DateFormat('EEEE, MMM d, yyyy, hh:mm:ss a');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(
              children: [
                FluentFileIcon(item: widget.item, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.item.name} Properties',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: colors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Windows Style Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Security'),
              Tab(text: 'Details'),
            ],
          ),

          // Tab Views
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralTab(colors, dateFormat),
                    _buildSecurityTab(colors),
                    _buildDetailsTab(colors, dateFormat),
                  ],
                ),
              ),
            ),
          ),

          // Dialog Buttons (OK, Cancel, Apply)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colors.container,
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text('Cancel', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(FluentColors colors, DateFormat dateFormat) {
    final item = widget.item;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Icon + Name
        Row(
          children: [
            FluentFileIcon(item: item, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDivider(colors),
        const SizedBox(height: 10),

        _buildPropRow('Type of file:', item.typeDescription, colors),
        _buildPropRow('Location:', item.path, colors),
        _buildPropRow('Size:', '${item.formatSize()} (${item.size} bytes)', colors),
        _buildPropRow('Size on disk:', '${item.formatSize()} (${item.size} bytes)', colors),

        const SizedBox(height: 6),
        _buildDivider(colors),
        const SizedBox(height: 6),

        _buildPropRow('Modified:', dateFormat.format(item.modified), colors),
        if (item.accessed != null)
          _buildPropRow('Accessed:', dateFormat.format(item.accessed!), colors),

        const SizedBox(height: 6),
        _buildDivider(colors),
        const SizedBox(height: 4),

        // Attributes
        Row(
          children: [
            Text('Attributes:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(width: 16),
            Row(
              children: [
                Checkbox(
                  value: _isReadOnly,
                  onChanged: (val) => setState(() => _isReadOnly = val ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text('Read-only', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
              ],
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Checkbox(
                  value: _isHidden,
                  onChanged: (val) => setState(() => _isHidden = val ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text('Hidden', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTab(FluentColors colors) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text(
          'Group or user names:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserRow(Icons.person, 'Owner (You)', colors),
              _buildUserRow(Icons.groups, 'Users (Local Access)', colors),
              _buildUserRow(Icons.security, 'SYSTEM', colors),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Permissions for Owner:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
        const SizedBox(height: 6),
        _buildPermCheck('Full control', true, colors),
        _buildPermCheck('Modify', true, colors),
        _buildPermCheck('Read & execute', true, colors),
        _buildPermCheck('Read', true, colors),
        _buildPermCheck('Write', true, colors),
      ],
    );
  }

  Widget _buildDetailsTab(FluentColors colors, DateFormat dateFormat) {
    final item = widget.item;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Text(
          'Property Information:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        _buildPropRow('Name:', item.name, colors),
        _buildPropRow('Item type:', item.typeDescription, colors),
        _buildPropRow('Folder path:', item.path, colors),
        _buildPropRow('Date modified:', dateFormat.format(item.modified), colors),
        _buildPropRow('Size:', item.formatSize(), colors),
        _buildPropRow('Extension:', item.extension.isNotEmpty ? '.${item.extension}' : '(none)', colors),
        _buildPropRow('Offline Storage:', 'Direct Local Android Storage', colors),
      ],
    );
  }

  Widget _buildUserRow(IconData icon, String name, FluentColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildPermCheck(String title, bool allowed, FluentColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: colors.textPrimary))),
          Icon(allowed ? Icons.check : Icons.close, size: 14, color: allowed ? colors.success : colors.error),
          const SizedBox(width: 4),
          Text(allowed ? 'Allow' : 'Deny', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPropRow(String label, String value, FluentColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(FluentColors colors) {
    return Container(
      height: 1,
      color: colors.borderSubtle,
    );
  }
}
