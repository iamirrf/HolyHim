import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../themes.dart';
import '../tokens.dart';
import '../typography.dart';

/// The app's only text input: one surface, a floating label, a hairline that
/// warms to the accent with a soft ring on focus, and an inline message.
class HolyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? error;
  final String? hint;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool password;
  final bool autofocus;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;
  final bool enabled;
  final int maxLines;
  const HolyField(
      {super.key,
      required this.controller,
      required this.label,
      this.error,
      this.hint,
      this.focusNode,
      this.keyboardType = TextInputType.text,
      this.textInputAction = TextInputAction.next,
      this.autofillHints,
      this.password = false,
      this.autofocus = false,
      this.capitalization = TextCapitalization.none,
      this.onChanged,
      this.onSubmitted,
      this.maxLength,
      this.enabled = true,
      this.maxLines = 1});
  @override
  State<HolyField> createState() => _HolyFieldState();
}

class _HolyFieldState extends State<HolyField> {
  late FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(HolyField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (old.focusNode != widget.focusNode) {
      _focus.removeListener(_changed);
      if (old.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    widget.controller.removeListener(_changed);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    final focused = _focus.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;
    final floating = focused || hasText;
    final error = widget.error;
    final edge = error != null
        ? const Color(0xFFB3261E)
        : focused
            ? t.accent
            : t.hairline;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced ? Duration.zero : const Duration(milliseconds: 180);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
              onTap: () => _focus.requestFocus(),
              child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  constraints: const BoxConstraints(minHeight: 60),
                  decoration: ShapeDecoration(
                      color: t.surface,
                      shape: RoundedSuperellipseBorder(
                          borderRadius:
                              BorderRadius.circular(HolyRadius.field),
                          side: BorderSide(
                              color: edge, width: focused ? 1.4 : 1)),
                      shadows: [
                        if (focused)
                          BoxShadow(
                              color: (error != null
                                      ? const Color(0xFFB3261E)
                                      : t.accent)
                                  .withValues(alpha: .14),
                              blurRadius: 0,
                              spreadRadius: 4),
                      ]),
                  padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
                  child: Row(children: [
                    Expanded(
                        child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                          Positioned.fill(
                              child: IgnorePointer(
                                  child: AnimatedAlign(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              alignment: floating || widget.maxLines > 1
                                  ? Alignment.topLeft
                                  : Alignment.centerLeft,
                              child: AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: floating
                                      ? HolyTypography.caption.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: error != null
                                              ? const Color(0xFFB3261E)
                                              : focused
                                                  ? t.accent
                                                  : t.muted)
                                      : HolyTypography.ui
                                          .copyWith(color: t.muted),
                                  child: Text(widget.label))))),
                          Padding(
                              padding: const EdgeInsets.only(top: 17),
                              child: TextField(
                                  controller: widget.controller,
                                  focusNode: _focus,
                                  enabled: widget.enabled,
                                  autofocus: widget.autofocus,
                                  keyboardType: widget.keyboardType,
                                  textInputAction: widget.textInputAction,
                                  autofillHints: widget.autofillHints,
                                  textCapitalization: widget.capitalization,
                                  obscureText: widget.password && _obscured,
                                  maxLines: widget.password ? 1 : widget.maxLines,
                                  minLines: widget.maxLines > 1 ? 3 : 1,
                                  autocorrect: !widget.password &&
                                      widget.keyboardType !=
                                          TextInputType.emailAddress,
                                  enableSuggestions: !widget.password &&
                                      widget.keyboardType !=
                                          TextInputType.emailAddress,
                                  onChanged: widget.onChanged,
                                  onSubmitted: widget.onSubmitted,
                                  inputFormatters: widget.maxLength == null
                                      ? null
                                      : [
                                          LengthLimitingTextInputFormatter(
                                              widget.maxLength)
                                        ],
                                  cursorColor: t.accent,
                                  cursorWidth: 1.6,
                                  style: HolyTypography.ui.copyWith(
                                      color: t.ink, fontSize: 17),
                                  decoration: InputDecoration(
                                      isCollapsed: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.only(
                                              top: 4, bottom: 2),
                                      hintText: floating ? widget.hint : null,
                                      hintStyle: HolyTypography.ui.copyWith(
                                          color:
                                              t.muted.withValues(alpha: .6),
                                          fontSize: 17)))),
                        ])),
                    if (widget.password)
                      Semantics(
                          button: true,
                          label: _obscured ? 'Show password' : 'Hide password',
                          excludeSemantics: true,
                          child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  setState(() => _obscured = !_obscured),
                              child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(
                                      _obscured
                                          ? CupertinoIcons.eye
                                          : CupertinoIcons.eye_slash,
                                      size: 20,
                                      color: t.muted))))
                    else
                      const SizedBox(width: 10),
                  ]))),
          AnimatedSize(
              duration: duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(error,
                              style: HolyTypography.caption.copyWith(
                                  color: t.isDark
                                      ? const Color(0xFFF2B8B5)
                                      : const Color(0xFFB3261E)))))),
        ]);
  }
}
