/// One daily message. Every lesson carries exactly one confidence, the
/// reason for it, hope for the day, and a reflection to carry.
/// Scripture text comes only from public-domain translations (KJV or WEB).
class DailyLesson {
  final int day;
  final String title;
  final String verseReference;
  final String verseText;
  final String confidence;
  final String reason;
  final String hope;
  final String reflection;

  const DailyLesson({
    required this.day,
    required this.title,
    required this.verseReference,
    required this.verseText,
    required this.confidence,
    required this.reason,
    required this.hope,
    required this.reflection,
  });
}

/// FUTURE SEAM: v1 ships Days 1-10. The list grows toward 365; lessonForDay returns null
/// past the end so the UI never shows a day that does not exist yet.
const lessons = <DailyLesson>[
  DailyLesson(
    day: 1,
    title: 'You Are Not Facing This Alone',
    verseReference: 'Deuteronomy 31:6 (KJV)',
    verseText:
        'Be strong and of a good courage, fear not, nor be afraid of them: '
        'for the LORD thy God, he it is that doth go with thee; '
        'he will not fail thee, nor forsake thee.',
    confidence: 'God is with you in this, right now.',
    reason: 'He promised to go with you and never leave you. His presence is '
        'not a feeling that comes and goes; it is a promise that stands '
        'whether you feel it or not.',
    hope: 'Whatever today holds, you do not walk into it alone. The same God '
        'who went with His people before you goes with you today.',
    reflection: 'Carry one sentence today: He goes with me.',
  ),
  DailyLesson(
    day: 2,
    title: 'Held Up by His Right Hand',
    verseReference: 'Isaiah 41:10 (KJV)',
    verseText: 'Fear thou not; for I am with thee: be not dismayed; '
        'for I am thy God: I will strengthen thee; yea, I will help thee; '
        'yea, I will uphold thee with the right hand of my righteousness.',
    confidence: 'God Himself will hold you up today.',
    reason: 'He does not only tell you to be strong; He promises to be the '
        'strength. Strengthen, help, uphold — three promises in one verse, '
        'all done by Him, not by you.',
    hope: 'You do not have to carry today on your own grip. When your '
        'strength runs out, His hand is already underneath you.',
    reflection: 'Carry one sentence today: He upholds me.',
  ),
  DailyLesson(
    day: 3,
    title: 'A Refuge You Can Run To',
    verseReference: 'Psalm 46:1 (KJV)',
    verseText:
        'God is our refuge and strength, a very present help in trouble.',
    confidence: 'God is your refuge, right in the middle of trouble.',
    reason: 'A refuge is not a place you visit after the storm; it is where '
        'you hide during it. And He is called a very present help — '
        'present, not distant, not delayed.',
    hope: 'Today, trouble does not have to be faced out in the open. You '
        'can step into His shelter first, and face the day from there.',
    reflection: 'Carry one sentence today: He is my refuge.',
  ),
  DailyLesson(
    day: 4,
    title: 'If God Is for You',
    verseReference: 'Romans 8:31 (KJV)',
    verseText: 'What shall we then say to these things? '
        'If God be for us, who can be against us?',
    confidence: 'God is for you — and no opposition outranks Him.',
    reason: 'The question is not whether opposition exists; it is who stands '
        'on your side. If the God who made all things is for you, then '
        'whatever is against you is smaller than the One who is with you.',
    hope: 'Today, you can stop measuring the size of the problem and start '
        'measuring the size of the God who is for you.',
    reflection: 'Carry one sentence today: God is for me.',
  ),
  DailyLesson(
    day: 5,
    title: 'His Thoughts Toward You Are Peace',
    verseReference: 'Jeremiah 29:11 (KJV)',
    verseText:
        'For I know the thoughts that I think toward you, saith the LORD, '
        'thoughts of peace, and not of evil, to give you an expected end.',
    confidence:
        "God's plans for you are good, even when today looks uncertain.",
    reason: 'He says His thoughts toward you are peace, not evil — and He '
        'says it while His people are still in exile, before anything has '
        'changed. The promise comes before the proof.',
    hope: 'Today does not have to look finished for you to trust where it '
        'is headed. A good end is already in His thoughts for you.',
    reflection: 'Carry one sentence today: His thoughts toward me are peace.',
  ),
  DailyLesson(
    day: 6,
    title: "Peace Before Things Are Settled",
    verseReference: "John 14:27 (KJV)",
    verseText:
        "Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you. Let not your heart be troubled, neither let it be afraid.",
    confidence:
        "You can receive Christ's peace while today's worry is still unresolved.",
    reason:
        "Jesus calls this peace His gift to you. He does not describe it as something the world must provide first. His promise gives you somewhere to rest your heart even before your circumstances change.",
    hope:
        "While you wait for news about money, work, or someone you love, you can pause before chasing another answer. You can bring that unsettled moment to Jesus without pretending the worry has disappeared.",
    reflection:
        "Where could you make room for His peace in an unresolved moment today?",
  ),
  DailyLesson(
    day: 7,
    title: "Strength You Can Receive",
    verseReference: "Isaiah 40:31 (KJV)",
    verseText:
        "But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.",
    confidence:
        "You do not have to generate the strength God promises to renew.",
    reason:
        "This verse says that those who wait upon the LORD shall renew their strength. The picture includes ordinary walking as well as soaring and running. His promised help reaches the slow, tired parts of life too.",
    hope:
        "If work and caring for others have left you tired, you can stop demanding that you feel strong before asking for help. You can turn to God for strength for the next ordinary task, without proving you can carry the whole day alone.",
    reflection: "I can receive strength for this next ordinary moment.",
  ),
  DailyLesson(
    day: 8,
    title: "Known From the Beginning",
    verseReference: "Psalm 139:13-14 (KJV)",
    verseText:
        "For thou hast possessed my reins: thou hast covered me in my mother's womb. I will praise thee; for I am fearfully and wonderfully made: marvellous are thy works; and that my soul knoweth right well.",
    confidence: "Your life matters to the God who formed you.",
    reason:
        "The psalm names the hidden beginning of a life: God at work in the womb. The writer calls His works marvellous, including the life He has made. His care began before anyone could notice an achievement or offer approval.",
    hope:
        "When your effort at work or home goes unseen, you can let that silence be something other than a verdict on your worth. You can enter the next conversation as someone whose life already matters to her Maker.",
    reflection:
        "What might change today if being unnoticed did not mean being unvalued?",
  ),
  DailyLesson(
    day: 9,
    title: "Light for Your Next Step",
    verseReference: "Psalm 119:105 (KJV)",
    verseText: "Thy word is a lamp unto my feet, and a light unto my path.",
    confidence:
        "You can take your next step with the light God gives you in His word.",
    reason:
        "A lamp lights the ground near your feet; it does not reveal every mile ahead. The psalm calls God's word that lamp and that light. His help gives you a way to walk without requiring a complete picture of the future.",
    hope:
        "Before sending a difficult message, you can choose one honest, gentle sentence instead of trying to settle the entire relationship. You can take that small step in the light you have and leave the unseen road with God.",
    reflection: "What is one small step you can see clearly enough to take?",
  ),
  DailyLesson(
    day: 10,
    title: "You Can Rest Here",
    verseReference: "Matthew 11:28 (KJV)",
    verseText:
        "Come unto me, all ye that labour and are heavy laden, and I will give you rest.",
    confidence: "You can bring your weariness to Jesus and receive His rest.",
    reason:
        "Jesus addresses people who labour and are heavy laden, not people who have everything under control. His invitation is to come to Him, and His promise is that He will give rest. Rest begins with His welcome rather than with your finishing every task.",
    hope:
        "When the list is still unfinished tonight, you can set it down for a while without treating rest as failure. You can bring what remains to Jesus and let His invitation be enough for this moment.",
    reflection: "I can come to Him with what is still unfinished.",
  ),
];

DailyLesson? lessonForDay(int day) {
  if (day < 1 || day > lessons.length) {
    return null;
  }
  return lessons[day - 1];
}
