import 'package:flutter/material.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/glass_button.dart';
import 'package:holyher/data/lessons.dart';

/// Learning cards for one lesson, mirroring Cognein's card-based lesson
/// craft in HolyHer's pink/white design. One card per field, swiped in
/// order: Verse, Confidence, Reason, Hope, Carry. Completing happens
/// only on the last card, through the caller's onComplete.
class LessonCards extends StatefulWidget {
  final DailyLesson lesson;
  final bool done;
  final bool saving;
  final Future<void> Function() onComplete;

  const LessonCards({
    super.key,
    required this.lesson,
    required this.done,
    required this.saving,
    required this.onComplete,
  });

  @override
  State<LessonCards> createState() => _LessonCardsState();
}

class _LessonCardsState extends State<LessonCards> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_CardData> get _cards {
    final lesson = widget.lesson;
    return [
      _CardData(
        label: 'Verse',
        title: lesson.verseReference,
        body: lesson.verseText,
        italic: true,
      ),
      _CardData(
        label: 'Confidence',
        title: 'God is on your side',
        body: lesson.confidence,
      ),
      _CardData(
        label: 'Reason',
        title: 'Why this is certain',
        body: lesson.reason,
      ),
      _CardData(
        label: 'Hope',
        title: 'Hope for today',
        body: lesson.hope,
      ),
      _CardData(
        label: 'Carry',
        title: 'Carry this',
        body: lesson.reflection,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final last = _page == cards.length - 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: cards.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final card = cards[index];
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1} · ${card.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          card.body,
                          style: TextStyle(
                            fontSize: 17,
                            fontStyle:
                                card.italic ? FontStyle.italic : FontStyle.normal,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _page ? AppColors.accent : AppColors.divider,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GlassButton(
            label: last
                ? (widget.done ? 'Completed' : "Complete today's message")
                : 'Next card',
            onPressed: last
                ? (widget.done || widget.saving ? null : widget.onComplete)
                : () {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _CardData {
  final String label;
  final String title;
  final String body;
  final bool italic;

  const _CardData({
    required this.label,
    required this.title,
    required this.body,
    this.italic = false,
  });
}
