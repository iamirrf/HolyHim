import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/core/widgets/lesson_artwork.dart';
import 'package:holyher/data/lessons.dart';

void shareVerseImage(BuildContext context, DailyLesson lesson) =>
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _VerseImagePreview(lesson: lesson));

class _VerseImagePreview extends StatefulWidget {
  final DailyLesson lesson;
  const _VerseImagePreview({required this.lesson});
  @override
  State<_VerseImagePreview> createState() => _VerseImagePreviewState();
}

class _VerseImagePreviewState extends State<_VerseImagePreview> {
  final _image = GlobalKey();
  bool _busy = false;
  String? _error;
  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final boundary =
          _image.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || bytes == null) return;
      final box = context.findRenderObject() as RenderBox;
      await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(bytes.buffer.asUint8List(),
                mimeType: 'image/png',
                name: 'holyher-day-${widget.lesson.day}.png')
          ],
          text:
              '${widget.lesson.verseReference} · World English Bible · HolyHer',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'The image could not be prepared. Please retry or share the text.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: ReadingWidth(
              maxWidth: 480,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('A little hope to share',
                        style: HolyTypography.section),
                    const SizedBox(height: 20),
                    RepaintBoundary(
                        key: _image,
                        child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.noScaling),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: LessonArtwork(
                                    day: widget.lesson.day,
                                    child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            30, 40, 30, 56),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const HolyMark(size: 36),
                                              const SizedBox(height: 30),
                                              Text(widget.lesson.verseText,
                                                  style: HolyTypography
                                                      .scripture
                                                      .copyWith(
                                                          color: AppColors
                                                              .textPrimary)),
                                              const SizedBox(height: 26),
                                              Text(widget.lesson.verseReference,
                                                  style: HolyTypography
                                                      .supporting
                                                      .copyWith(
                                                          color: AppColors
                                                              .accentDark)),
                                              const SizedBox(height: 34),
                                              Text('HolyHer · Walk with God',
                                                  style: HolyTypography.label
                                                      .copyWith(
                                                          color: AppColors
                                                              .textSecondary))
                                            ])))))),
                    const SizedBox(height: 22),
                    if (_error != null) InlineMessage(_error!, error: true),
                    HolyButton(
                        label: 'Share image',
                        busy: _busy,
                        onPressed: _busy ? null : _share,
                        icon: Icons.ios_share_outlined),
                  ]))));
}
