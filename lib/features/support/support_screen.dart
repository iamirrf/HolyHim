import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String? _emailError, _messageError;
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false, _sent = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _email.text = ref.read(authProvider).user?.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _emailError = RegExp(r'^\S+@\S+\.\S+$').hasMatch(_email.text.trim())
          ? null
          : 'Enter an email address so we can reply.';
      _messageError = _message.text.trim().length < 3
          ? 'Tell us a little about what happened.'
          : null;
    });
    if (_emailError != null || _messageError != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await http
          .post(Uri.parse('${AppConstants.websiteUrl}/api/support'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': _email.text.trim(),
                'message': _message.text.trim(),
                'purpose': 'support',
                'website': '',
                'appVersion': AppConstants.wireVersion
              }))
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          body is! Map ||
          body['received'] != true) {
        throw _SupportError(body is Map && body['error'] is String
            ? body['error']
            : 'Your message could not be sent. Please try again.');
      }
      if (mounted) setState(() => _sent = true);
    } on _SupportError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'That took longer than expected. Your message is still here. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'We could not connect. Check your connection and try again. Your message is still here.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = HolyThemeScope.of(context);
    return KeyboardLift(
        footer: _sent
            ? HolyButton('Done', onPressed: () => Navigator.of(context).maybePop())
            : HolyButton('Send message', loading: _sending, onPressed: _send),
        builder: (context, keyboard) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.fromLTRB(HolySpace.gutter - 6, 6, 0, 0),
                      child: BackControl()),
                  Expanded(
                      child: FitColumn(children: [
                    SizedBox(height: keyboard ? 6 : 14),
                    Semantics(
                        header: true,
                        child: Text(_sent ? 'Thank you' : 'Help and feedback',
                            style: HolyTypography.title.copyWith(
                                color: t.ink, fontSize: keyboard ? 28 : 34))),
                    if (!keyboard) ...[
                      const SizedBox(height: 6),
                      Text(
                          _sent
                              ? 'Your message reached us. We usually reply within two days.'
                              : 'A person reads every message. Tell us what is working, what is not, or what you wish HolyHim did.',
                          style: HolyTypography.body.copyWith(color: t.muted)),
                    ],
                    const SizedBox(height: 18),
                    if (!_sent) ...[
                      HolyField(
                          controller: _email,
                          label: 'Your email',
                          error: _emailError,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email]),
                      const SizedBox(height: 12),
                      HolyField(
                          controller: _message,
                          label: 'Message',
                          error: _messageError,
                          maxLines: 6,
                          maxLength: 2000,
                          capitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          keyboardType: TextInputType.multiline),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: HolyTypography.caption
                                .copyWith(color: t.accent)),
                      ],
                    ],
                    const Spacer(),
                  ])),
                ]));
  }
}

class _SupportError implements Exception {
  final String message;
  const _SupportError(this.message);
}
