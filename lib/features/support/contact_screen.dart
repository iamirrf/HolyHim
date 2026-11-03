import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/theme/app_theme.dart';

class ContactScreen extends StatefulWidget {
  final bool feedback;
  final Future<void> Function(String email, String message, bool feedback)?
      submit;
  const ContactScreen({super.key, this.feedback = false, this.submit});
  @override
  State<ContactScreen> createState() => _ContactState();
}

class _ContactState extends State<ContactScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _message = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = http.Client();
    try {
      if (widget.submit != null) {
        await widget.submit!(
            _email.text.trim(), _message.text.trim(), widget.feedback);
      } else {
        final response = await client
            .post(Uri.parse('${AppConstants.websiteUrl}/api/support'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': _email.text.trim(),
                  'message': _message.text.trim(),
                  'purpose': widget.feedback ? 'feedback' : 'support',
                  'appVersion': AppConstants.wireVersion
                }))
            .timeout(const Duration(seconds: 20));
        final body = jsonDecode(response.body);
        if (response.statusCode != 200 || body['received'] != true) {
          throw StateError(response.statusCode == 429
              ? 'Please wait a little before sending another message.'
              : 'Your message could not be sent. Please retry.');
        }
      }
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError
            ? error.message.toString()
            : 'Your message has not been sent. Check your connection and retry.');
      }
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => useHolyPalette(
      context,
      () => HolyScaffold(
          title: widget.feedback ? 'Send feedback' : 'Contact support',
          body: ReadingWidth(
              maxWidth: 600,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _sent
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              const Icon(Icons.check_circle_outline, size: 44),
                              const SizedBox(height: 20),
                              Text(
                                  widget.feedback
                                      ? 'Thank you for your feedback.'
                                      : 'Your message was received.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                              const SizedBox(height: 16),
                              const Text(
                                  'Your message has been delivered to HolyHer. You can return to your journey.'),
                              const SizedBox(height: 24),
                              HolyButton(
                                  label: 'Done',
                                  onPressed: () => Navigator.of(context).pop())
                            ])
                      : Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                    widget.feedback
                                        ? 'Help shape HolyHer.'
                                        : 'How can we help?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: 16),
                                Text(
                                    widget.feedback
                                        ? 'Tell us what feels useful, or what could be better.'
                                        : 'A question about your journey, or something that needs a fix.',
                                    style: HolyTypography.body.copyWith(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 24),
                                TextFormField(
                                    controller: _email,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    decoration: const InputDecoration(
                                        labelText: 'Your email'),
                                    validator: (v) => v != null &&
                                            RegExp(r'^\S+@\S+\.\S+$')
                                                .hasMatch(v.trim()) &&
                                            v.length <= 254
                                        ? null
                                        : 'Enter a valid email address.'),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _message,
                                    enabled: !_busy,
                                    minLines: 5,
                                    maxLines: 12,
                                    maxLength: 5000,
                                    decoration: const InputDecoration(
                                        labelText: 'Your message'),
                                    validator: (v) => v == null ||
                                            v.trim().length < 10
                                        ? 'Write at least 10 characters.'
                                        : v.length > 5000
                                            ? 'Use 5,000 characters or fewer.'
                                            : null),
                                if (_error != null)
                                  InlineMessage(_error!, error: true),
                                const SizedBox(height: 20),
                                HolyButton(
                                    label: 'Send message',
                                    busy: _busy,
                                    onPressed: _busy ? null : _send)
                              ]))))));
}
