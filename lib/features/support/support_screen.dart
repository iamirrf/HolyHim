import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../design/design.dart';
import '../../services/auth_service.dart';
import '../common.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _form = GlobalKey<FormState>();
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
    if (_sending || !_form.currentState!.validate()) return;
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
  Widget build(BuildContext context) => Scaffold(
      extendBodyBehindAppBar: true,
      appBar:
          const GlassTopBar(title: Text('Here to help', style: HolyTypography.title)),
      body: PageBody(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 90, 24, 48),
          children: [
            const Eyebrow('You can talk to us'),
            const SizedBox(height: 14),
            Text(
                _sent
                    ? 'Your words\nhave reached us.'
                    : 'A little help\nalong the way.',
                style: HolyTypography.display),
            const SizedBox(height: 20),
            if (_sent) ...[
              Glass(
                  child: Column(children: [
                const Icon(CupertinoIcons.check_mark_circled,
                    color: rose, size: 48),
                const SizedBox(height: 18),
                const Text('Thank you for getting in touch.',
                    textAlign: TextAlign.center, style: HolyTypography.title),
                const SizedBox(height: 14),
                Text('We will reply to ${_email.text.trim()}.',
                    textAlign: TextAlign.center, style: muted(context))
              ])),
              const SizedBox(height: 24),
              ActionButton('Done', onPressed: () => Navigator.maybePop(context))
            ] else ...[
              Text(
                  'Have a question, found a problem, or want to share a thought? We would love to hear from you.',
                  style: muted(context)),
              const SizedBox(height: 26),
              Glass(
                  child: Form(
                      key: _form,
                      child: Column(children: [
                        TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            maxLength: 254,
                            decoration: const InputDecoration(
                                labelText: 'Your email', counterText: ''),
                            validator: (value) => RegExp(r'^\S+@\S+\.\S+$')
                                    .hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Enter your email address.'),
                        const SizedBox(height: 22),
                        TextFormField(
                            controller: _message,
                            minLines: 5,
                            maxLines: 12,
                            maxLength: 5000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                                labelText: 'How can we help?',
                                alignLabelWithHint: true),
                            validator: (value) => (value?.trim().length ?? 0) >=
                                    10
                                ? null
                                : 'Tell us a little more, at least 10 characters.'),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(_error!,
                                  style: ui(context).copyWith(color: rose))),
                        const SizedBox(height: 22),
                        ActionButton(
                            _sending ? 'Sending your message…' : 'Send message',
                            icon: CupertinoIcons.paperplane,
                            onPressed: _sending ? null : _send)
                      ]))),
              const SizedBox(height: 20),
              Text(
                  'Please leave passwords and sensitive personal details out of your message.',
                  style: muted(context).copyWith(fontSize: 12))
            ]
          ]));
}

class _SupportError implements Exception {
  final String message;
  const _SupportError(this.message);
}
