import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/core/theme/app_colors.dart';
import '../../../../shared/core/theme/app_spacing.dart';

/// 6-digit pairing code input with individual digit boxes.
///
/// Each digit gets its own styled box. Auto-advances focus on input,
/// supports backspace to go back. Calls [onCompleted] when all 6 digits
/// are filled. Calls [onChanged] on every change with the current value.
class PairingCodeInput extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;

  const PairingCodeInput({
    super.key,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<PairingCodeInput> createState() => PairingCodeInputState();
}

class PairingCodeInputState extends State<PairingCodeInput> {
  static const _digitCount = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _digitCount,
      (_) => TextEditingController(),
    );
    _focusNodes = List.generate(_digitCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Get the current combined code.
  String get currentCode =>
      _controllers.map((c) => c.text).join();

  /// Clear all digit fields and focus the first one.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.first.canRequestFocus) {
      _focusNodes.first.requestFocus();
    }
    widget.onChanged('');
  }

  void _onDigitChanged(int index, String value) {
    // Only allow single digit
    if (value.length > 1) {
      _controllers[index].text = value[value.length - 1];
    }

    final code = currentCode;
    widget.onChanged(code);

    if (value.isNotEmpty && index < _digitCount - 1) {
      // Advance to next field
      _focusNodes[index + 1].requestFocus();
    }

    if (code.length == _digitCount) {
      // Unfocus last field, notify completion
      _focusNodes[index].unfocus();
      widget.onCompleted?.call(code);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      // Move back on backspace when current field is empty
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      widget.onChanged(currentCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = widget.hasError
        ? AppColors.error
        : AppColors.border;
    final focusBorderColor = widget.hasError
        ? AppColors.error
        : AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_digitCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index < _digitCount - 1 ? AppSpacing.sm : 0,
          ),
          child: SizedBox(
            width: 52,
            height: 64,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) => _onKeyEvent(index, event),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0,
                  color: AppColors.textPrimary,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: focusBorderColor,
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: borderColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                onChanged: (value) => _onDigitChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}
