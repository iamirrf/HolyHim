/// A short conversation, written down: what HolyHim says, what he can tap
/// in reply, and what HolyHim says back.
///
/// Lines are functions, not strings, so they are read at the moment they are
/// said. A reply to the reminder question depends on what iOS answered a
/// second ago, which no line written ahead of time could know.
library;

/// One thing he can tap in reply.
class ChatReply {
  final String id, label;

  /// Opens something of its own (a time picker) before there is an answer,
  /// so his bubble waits for what he chooses there.
  final bool deferred;

  /// Set before the label, on the pill and in his bubble.
  final String? emoji;
  const ChatReply(this.id, this.label, {this.deferred = false, this.emoji});
}

/// What was stored for a question: the saved value and the words shown in
/// his bubble.
class ChatAnswer {
  final String id, label;
  final String? emoji;
  const ChatAnswer(this.id, this.label, {this.emoji});
}

class ChatQuestion {
  /// Names the answer; the step hands it back with every reply.
  final String id;
  final List<String> Function() ask;
  final List<ChatReply> Function() replies;

  /// What HolyHim says back, given the stored answer. Null says nothing.
  final String? Function(String answerId)? react;
  const ChatQuestion(
      {required this.id, required this.ask, required this.replies, this.react});
}

class ChatScript {
  final List<String> Function() opening;
  final List<ChatQuestion> questions;
  final List<String> Function() closing;
  const ChatScript(
      {required this.opening, required this.questions, required this.closing});
}
