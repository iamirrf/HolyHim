"""Adapt the retained curriculum to five reading-only cards; pin WEB text exactly.

Editorial adaptation status is explicit; compilation is not editorial approval.
The authored output is content/readings.json. --check verifies it without writes.
"""
import argparse,json,hashlib,subprocess
from pathlib import Path
from build_lessons import passage,verse_keys,dart_string
ROOT=Path(__file__).resolve().parents[1]
KINDS=['scripture','meaning','encouragement','hope','prayer']
DAY_ONE=[
 None,
 "Moses spoke these words to Israel at the edge of an unfamiliar future. His leadership was ending, and Joshua would lead the people into the land ahead. There were real reasons to feel afraid.\n\nTheir courage rested on God's faithfulness, rather than on their own strength. This promise belonged to a particular people and moment; it does not guarantee that every difficult situation will unfold as we wish. It reveals a God who does not abandon his people when the way forward is hard.",
 "Perhaps there is an appointment you are dreading, a conversation you keep postponing, or a responsibility that feels too large today. You do not need to become fearless before taking an honest, wise next step.\n\nCourage can be quiet: asking for support, telling the truth gently, or simply showing up. God's presence gives you somewhere to bring your fear. Accepting help from someone trustworthy can be part of that courage, too.",
 "You can face today's difficult moment with courage because God's presence does not depend on how brave, ready, or calm you feel.\n\nThe words to carry are simple: I do not walk alone. Remembering them may not change your circumstances immediately. It can change how you meet the next moment: with room for honest fear, wise support, and a small act of trust.",
 "Faithful God, you know what feels uncertain today. Help me bring my fear to you without hiding it or rushing past it. Give me courage for the next faithful step, wisdom to receive support, and gentleness toward myself as I learn to trust you. Thank you that I do not have to walk alone. Amen.\n\nCarry this with you: God's faithfulness makes room for courage."
]
CONTEXT=[
 "Read this passage as part of the larger biblical story. Its comfort is not a promise that life will become easy or that faithful people will avoid loss. It points toward a relationship with God that can sustain honest trust within real circumstances.",
 "The setting matters: Scripture speaks into human lives, communities, questions, and struggles. Let the words keep their original meaning before making a connection to your own day. Faithfulness grows through patient attention, rather than through forcing a quick answer from a single verse.",
 "Notice where the passage places its emphasis. God's character comes before the response it invites. Receiving these words is not a test of how spiritual you feel. You can approach them with questions, uncertainty, and a willingness to keep learning within the wider story of Scripture."
]
PRACTICE=[
 "There is room for an ordinary beginning. A sincere conversation, an offer of help, or a decision to pause before responding can express faith in everyday life. You do not need to solve the whole situation before doing the next loving and responsible thing.",
 "Bring this truth into the next part of your routine. It might meet you while preparing a meal, waiting for a message, or finishing a demanding task. A small response made with care can matter even when no one else sees it.",
 "You may find that this becomes clearer through practice rather than through a sudden feeling. Let one interaction today be shaped by patience and attention. If the day is difficult, begin again gently; a hard moment does not erase the possibility of a faithful next step."
]
HOPE=[
 "This truth can travel with you beyond these few minutes. When attention scatters or the day changes unexpectedly, return to what the passage actually says. You are allowed to grow slowly, to seek wise counsel, and to hold hope without pretending to know the outcome.",
 "You do not have to manufacture certainty to receive encouragement. Hold this truth alongside the parts of your life that remain unfinished. Hope can share space with grief, questions, and practical action; it need not silence any of them before it becomes meaningful.",
 "Let this be a steady reminder rather than another demand to perform well. Remembering God's care can make space for a more patient response to yourself and to others. Today's limits are real, and there can still be something faithful and good within them."
]
PRAYERS={
 'courage':"Faithful God, meet me in what feels frightening. Give me courage to act with love, wisdom to recognize my limits, and humility to receive help. Let trust in you shape my next step, even while my feelings remain unsettled. Amen.",
 'peace':"God of peace, you know the concerns I carry. Help me receive your care without pretending that everything is resolved. Give me patience in uncertainty, clarity for what is mine to do, and the grace to pause before I react. Amen.",
 'hope':"God of hope, hold what is unfinished in my life. Help me remain open to goodness without demanding an answer on my timetable. Give me strength for today's responsibilities and companions who can share the waiting with honesty and care. Amen.",
 'rest':"Caring God, help me notice my need for rest. Give me freedom to set down what cannot be finished today, courage to ask for help, and wisdom to care for the body and life entrusted to me. Let rest become an expression of trust. Amen.",
 'wisdom':"Wise and loving God, guide my attention to what is true and good. Help me listen before deciding, consider those affected by my choices, and welcome correction without defensiveness. Give me patience to seek understanding and courage to act responsibly. Amen.",
 'community':"Loving God, help me receive and extend care with humility. Teach me to listen well, honor healthy boundaries, and recognize the needs of people near me. Give me courage to ask for support and generosity to offer the help I can. Amen.",
 'grace':"Merciful God, help me receive grace without hiding what needs to change. Give me courage to be honest, patience with the work of growth, and compassion for others who are learning too. Let your kindness shape the way I begin again today. Amen.",
 'gratitude':"Generous God, help me notice the gifts within this ordinary day. Keep gratitude honest and attentive, with room for sorrow as well as joy. Teach me to receive with humility, share with care, and recognize the people whose kindness supports my life. Amen.",
 'trust':"Faithful God, help me attend to your words with an open heart. Give me wisdom to understand, courage to live with integrity, and kindness toward the people I meet. Hold my questions as I learn to trust you through the ordinary decisions of today. Amen."
}
def build():
 verses=json.loads((ROOT/'tool/scripture/verses.json').read_text())
 authored=sum([json.loads((ROOT/f'content/{p}').read_text()) for p in ['lessons_001_183.json','lessons_184_365.json']],[])
 result=[]
 for row in authored:
  day=row['day'];theme=row['theme'].lower();scripture=passage(row['reference'],verses)
  group=next((k for k in PRAYERS if k in theme),'trust')
  body=[scripture,row['reason']+'\n\n'+CONTEXT[(day-1)%3],row['hope']+'\n\n'+PRACTICE[(day//3)%3],row['confidence']+'\n\n'+HOPE[(day//9)%3],PRAYERS[group]+'\n\nCarry this with you: '+row['confidence']]
  if day==1:body=[scripture,*DAY_ONE[1:]]
  words=sum(len(t.split()) for t in body)
  result.append({'day':day,'title':row['title'],'reference':row['reference'],'theme':row['theme'].title(),'contentVersion':'walk-v1','editorialStatus':'reviewed' if day==1 else 'adapted-awaiting-review','wordCount':words,'cards':[{'kind':k,'text':t} for k,t in zip(KINDS,body)]})
 return result

def verify(rows):
 original=build()
 assert len(rows)==365 and [x['day'] for x in rows]==list(range(1,366))
 for row,expected in zip(rows,original):
  assert (row['title'],row['reference'])==(expected['title'],expected['reference'])
  assert [c['kind'] for c in row['cards']]==KINDS
  assert row['cards'][0]['text']==expected['cards'][0]['text']
  words=sum(len(c['text'].split()) for c in row['cards'])
  assert 280<=words<=380 or len(row['cards'][0]['text'].split())>100,(row['day'],words)
  assert all(c['text'].strip() for c in row['cards'])
 review_path=ROOT/'content/reading-review.json'
 if review_path.exists():
  review=json.loads(review_path.read_text());evidence={r['day']:r for r in review['lessons']}
  for row in rows:
   if row.get('editorialStatus')=='reviewed':
    expected=hashlib.sha256(json.dumps(row['cards'],ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    assert evidence.get(row['day'],{}).get('sha256')==expected,f"Day {row['day']} needs a new editorial review after its body changed"


def outputs(rows):
 source="""// Generated from content/readings.json. Scripture is pinned, public-domain WEB.
class ReadingCard {
  final String kind, text;
  const ReadingCard(this.kind, this.text);
}
class DailyReading {
  final int day;
  final String title, reference;
  final List<ReadingCard> cards;
  const DailyReading(this.day, this.title, this.reference, this.cards);
}
const readingContentVersion = 'walk-v1';
const readings = <DailyReading>[\n"""
 for row in rows:
  source+=f"  DailyReading({row['day']}, {dart_string(row['title'])}, {dart_string(row['reference'])}, [\n"
  source+=''.join(f"    ReadingCard({dart_string(c['kind'])}, {dart_string(c['text'])}),\n" for c in row['cards'])+"  ]),\n"
 source+='];\n'
 source=subprocess.run(['dart','format','--language-version=3.0','--output=show','--summary=none'],input=source,text=True,capture_output=True,check=True).stdout
 return {ROOT/'lib/data/readings.dart':source,ROOT/'public/lesson-sample.json':json.dumps(rows[0],ensure_ascii=False,indent=2)+'\n'}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
 path=ROOT/'content/readings.json'
 rows=json.loads(path.read_text()) if path.exists() else build()
 verify(rows)
 generated=outputs(rows)
 if args.check:
  assert path.exists()
  for p,text in generated.items():assert p.read_text()==text,f'Stale {p}'
 else:
  path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
  for p,text in generated.items():p.write_text(text)
 report={'version':'walk-v1','lessons':365,'cards':1825,'verifiedScripture':365,'minWords':min(x['wordCount'] for x in rows),'maxWords':max(x['wordCount'] for x in rows),'reviewedDays':[r['day'] for r in rows if r['editorialStatus']=='reviewed'],'contentReviewComplete':all(r['editorialStatus']=='reviewed' for r in rows),'scope':'Content only; overall release acceptance is recorded in WALK_WITH_GOD_STATUS.md'}
 if not args.check:(ROOT/'store/walk-content-status.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report))
if __name__=='__main__':main()
