import 'package:flutter/material.dart';
import '../../services/vault_service.dart';
import '../../theme/fluent_theme.dart';
import 'fluent_pattern_lock.dart';

class VaultAuthDialog extends StatefulWidget {
  final bool isSetupMode;
  final String title;
  final String description;

  const VaultAuthDialog({
    super.key,
    this.isSetupMode = false,
    this.title = 'File Vault',
    this.description = 'Enter your credentials to access protected files',
  });

  static Future<bool> requestAuth(
    BuildContext context, {
    String title = 'File Vault',
    String description = 'Authenticate to access or store protected files',
  }) async {
    final vault = VaultService.instance;
    final isInit = await vault.isInitialized();

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VaultAuthDialog(
        isSetupMode: !isInit,
        title: !isInit ? 'Set up File Vault' : title,
        description: !isInit
            ? 'Create a master password or pattern to secure your private files.'
            : description,
      ),
    );

    return result ?? false;
  }

  @override
  State<VaultAuthDialog> createState() => _VaultAuthDialogState();
}

class _VaultAuthDialogState extends State<VaultAuthDialog> {
  final VaultService _vault = VaultService.instance;
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _hintController = TextEditingController();

  bool _isLoading = true;
  bool _isSetup = false;
  VaultAuthType _authType = VaultAuthType.password;
  String? _savedHint;

  String? _patternFirstStep;
  String? _errorMessage;
  bool _isError = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _isSetup = widget.isSetupMode;
    _loadState();
  }

  Future<void> _loadState() async {
    final isInit = await _vault.isInitialized();
    if (!isInit) {
      _isSetup = true;
    } else {
      _authType = await _vault.getAuthType();
      _savedHint = await _vault.getHint();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    _confirmController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _onPatternComplete(List<int> nodes) {
    if (nodes.length < 4) {
      setState(() {
        _isError = true;
        _errorMessage = 'Connect at least 4 dots';
      });
      return;
    }

    final patternStr = nodes.join(',');
    if (_isSetup) {
      if (_patternFirstStep == null) {
        setState(() {
          _patternFirstStep = patternStr;
          _isError = false;
          _errorMessage = null;
        });
      } else {
        if (_patternFirstStep == patternStr) {
          _completeSetup(patternStr);
        } else {
          setState(() {
            _isError = true;
            _errorMessage = 'Patterns do not match. Try again';
            _patternFirstStep = null;
          });
        }
      }
    } else {
      _verifyAndUnlock(patternStr);
    }
  }

  Future<void> _handlePasswordSubmit() async {
    final pass = _secretController.text.trim();
    if (pass.isEmpty) {
      setState(() {
        _isError = true;
        _errorMessage = 'Password cannot be empty';
      });
      return;
    }

    if (_isSetup) {
      if (pass.length < 4) {
        setState(() {
          _isError = true;
          _errorMessage = 'Password must be at least 4 characters';
        });
        return;
      }
      final confirm = _confirmController.text.trim();
      if (pass != confirm) {
        setState(() {
          _isError = true;
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
      await _completeSetup(pass);
    } else {
      await _verifyAndUnlock(pass);
    }
  }

  Future<void> _completeSetup(String secret) async {
    setState(() => _isLoading = true);
    await _vault.setupVault(
      authType: _authType,
      secret: secret,
      hint: _hintController.text.trim().isNotEmpty ? _hintController.text.trim() : null,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _verifyAndUnlock(String secret) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isError = false;
    });

    final success = await _vault.verifySecret(secret);
    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Incorrect credentials. Please try again.';
          _secretController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return Dialog(
      backgroundColor: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.borderSubtle, width: 1),
      ),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading
              ? const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isSetup ? Icons.shield_outlined : Icons.lock_outline,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSetup ? 'Set up File Vault' : widget.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isSetup
                                      ? (_authType == VaultAuthType.pattern
                                          ? (_patternFirstStep == null
                                              ? 'Draw an unlock pattern'
                                              : 'Draw pattern again to confirm')
                                          : 'Choose a strong password or PIN')
                                      : widget.description,
                                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Auth Mode Selector in Setup mode
                      if (_isSetup && _patternFirstStep == null) ...[
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.container,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _authType = VaultAuthType.password;
                                    _errorMessage = null;
                                    _isError = false;
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _authType == VaultAuthType.password
                                          ? colors.cardSurface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: _authType == VaultAuthType.password
                                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Password / PIN',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _authType == VaultAuthType.password
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: _authType == VaultAuthType.password
                                              ? colors.textPrimary
                                              : colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _authType = VaultAuthType.pattern;
                                    _errorMessage = null;
                                    _isError = false;
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _authType == VaultAuthType.pattern
                                          ? colors.cardSurface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: _authType == VaultAuthType.pattern
                                          ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Pattern',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _authType == VaultAuthType.pattern
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: _authType == VaultAuthType.pattern
                                              ? colors.textPrimary
                                              : colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Body based on Auth Type
                      if (_authType == VaultAuthType.pattern) ...[
                        FluentPatternLock(
                          dimension: 240,
                          isError: _isError,
                          activeColor: colors.primary,
                          onPatternComplete: _onPatternComplete,
                        ),
                        if (_isSetup && _patternFirstStep != null) ...[
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: () => setState(() {
                              _patternFirstStep = null;
                              _errorMessage = null;
                            }),
                            child: const Text('Reset Pattern', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ] else ...[
                        // Password inputs
                        TextField(
                          controller: _secretController,
                          obscureText: _obscureText,
                          autofocus: true,
                          style: TextStyle(fontSize: 14, color: colors.textPrimary),
                          decoration: InputDecoration(
                            labelText: _isSetup ? 'Master Password / PIN' : 'Password / PIN',
                            hintText: 'Enter password',
                            prefixIcon: Icon(Icons.key, size: 18, color: colors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureText = !_obscureText),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onSubmitted: (_) => _isSetup ? null : _handlePasswordSubmit(),
                        ),
                        if (_isSetup) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmController,
                            obscureText: _obscureText,
                            style: TextStyle(fontSize: 14, color: colors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password / PIN',
                              hintText: 'Re-enter password',
                              prefixIcon: Icon(Icons.check_circle_outline, size: 18, color: colors.primary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _hintController,
                            style: TextStyle(fontSize: 13, color: colors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password Hint (Optional)',
                              hintText: 'e.g. Favorite year or childhood pet',
                              prefixIcon: Icon(Icons.help_outline, size: 18, color: colors.textMuted),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ],

                      // Error message or Hint
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ] else if (_savedHint != null && !_isSetup) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lightbulb_outline, size: 13, color: colors.primary),
                            const SizedBox(width: 4),
                            Text('Hint: $_savedHint', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.textSecondary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          if (_authType == VaultAuthType.password)
                            FilledButton(
                              onPressed: _handlePasswordSubmit,
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              ),
                              child: Text(_isSetup ? 'Create Vault' : 'Unlock'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
