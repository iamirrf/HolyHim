import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tool'))
from verify_lessons import validate
class LessonGateTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.lessons=json.loads((ROOT/'content/first_week_review.json').read_text());cls.verses=json.loads((ROOT/'tool/scripture/verses.json').read_text())
 def errors(self,edit):
  data=copy.deepcopy(self.lessons);edit(data);return validate(data,self.verses,partial=True)
 def test_real_first_week_and_repeated_validation(self):
  for _ in range(2):self.assertEqual(validate(self.lessons,self.verses,partial=True),[])
 def test_verbatim_scripture(self):self.assertTrue(any('WEB' in e for e in self.errors(lambda d:d[0].update(verse=d[0]['verse'].replace('LORD','Lord')))))
 def test_banned_voice(self):self.assertTrue(any('banned' in e for e in self.errors(lambda d:d[0].update(heart=d[0]['heart'].replace('appointment','tapestry')))))
 def test_shared_sentences(self):self.assertTrue(any('shared' in e for e in self.errors(lambda d:d[1].update(meaning=d[0]['meaning']))))
 def test_word_bounds(self):self.assertTrue(any('words' in e for e in self.errors(lambda d:d[0].update(prayer='Help me. Amen.'))))
 def test_prayer_ending(self):self.assertTrue(any('end Amen' in e for e in self.errors(lambda d:d[0].update(prayer=d[0]['prayer'][:-5]))))
 def test_teaser_length(self):self.assertTrue(any('90' in e for e in self.errors(lambda d:d[0].update(teaser='x'*91))))
 def test_missing_day(self):self.assertTrue(self.errors(lambda d:d.pop(1)))
if __name__=='__main__':unittest.main()
