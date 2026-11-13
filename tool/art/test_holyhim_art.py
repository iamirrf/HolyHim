"""Paid-request guards, resume fingerprints, selection, and alpha packaging."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC=importlib.util.spec_from_file_location('holyhim_art',Path(__file__).with_name('holyhim_art.py'))
ART=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(ART)

class ArtWorkshopTests(unittest.TestCase):
    def test_inventory_is_complete_and_distinct(self):
        items=ART.inventory()
        self.assertEqual(len(items),392)
        self.assertEqual(len({i['id'] for i in items}),392)
        self.assertEqual(len({i['prompt'] for i in items}),392)
        self.assertEqual(sum(i['kind']=='lessons' for i in items),365)
        self.assertEqual(sum(i['kind']=='badges' for i in items),19)
        self.assertEqual(sum(i['kind']=='scenes' for i in items),8)
    def test_ranges_and_invalid_input(self):
        self.assertEqual(ART.selected_numbers('1-3,8,12-13',365),{1,2,3,8,12,13})
        for value in ['0','366','5-2','1-5,','abc','2;3']:
            with self.assertRaises(ValueError):ART.selected_numbers(value,365)
    def test_style_and_model_change_fingerprint(self):
        item=ART.inventory()[0]
        original=ART.prompt_hash(item,ART.DEFAULT_MODEL,'style-a')
        self.assertNotEqual(original,ART.prompt_hash(item,ART.DEFAULT_MODEL,'style-b'))
        self.assertNotEqual(original,ART.prompt_hash(item,'draft-model','style-a'))
    def test_generate_dry_run_cannot_call_service(self):
        with patch.object(ART,'request_image',side_effect=AssertionError('paid call')):
            self.assertEqual(ART.main(['generate','--kind','lessons','--range','1-5','--dry-run']),0)
    def test_generate_batch_requires_reviewed_style(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            with patch.object(ART,'MANIFEST',root/'manifest.json'),patch.object(ART,'request_image',side_effect=AssertionError('paid call')):
                args=ART.parser().parse_args(['generate','--kind','lessons','--range','1-5'])
                with self.assertRaisesRegex(ValueError,'Approve a Day 1'):
                    ART.generate(args)
    def test_unreviewed_assets_are_never_packaged(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);art=root/'art';art.mkdir()
            item=ART.inventory()[0]
            source=art/'raw.png';Image.new('RGB',(10,20),'pink').save(source)
            manifest={'version':2,'items':{item['id']:{**item,'path':'art/raw.png','status':'generated','approved':False}}}
            with patch.object(ART,'ROOT',root),patch.object(ART,'ART',art),patch.object(ART,'MANIFEST',art/'manifest.json'),patch.object(ART,'choose',return_value=[item]):
                ART.save_manifest(manifest)
                self.assertEqual(ART.package(ART.parser().parse_args(['package','--kind','lessons','--range','1'])),0)
                self.assertFalse((root/'public/art/v2/lessons/day-001.webp').exists())
    def test_approval_rejects_style_path_outside_project(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)/'project';root.mkdir()
            outside=Path(folder)/'outside.png';outside.write_bytes(b'not secret')
            with patch.object(ART,'ROOT',root),patch.object(ART,'MANIFEST',root/'art/manifest.json'):
                args=ART.parser().parse_args(['review','--style-ref',str(root/'../outside.png')])
                with self.assertRaisesRegex(ValueError,'inside this project'):
                    ART.review(args)
    def test_stale_approved_hash_cannot_be_packaged(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);art=root/'art';art.mkdir()
            item=ART.inventory()[0]
            source=art/'raw.png';Image.new('RGB',(10,20),'pink').save(source)
            manifest={'version':2,'items':{item['id']:{**item,'path':'art/raw.png','status':'generated','approved':True,'approvedSha256':'stale'}}}
            with patch.object(ART,'ROOT',root),patch.object(ART,'ART',art),patch.object(ART,'MANIFEST',art/'manifest.json'),patch.object(ART,'choose',return_value=[item]):
                ART.save_manifest(manifest)
                with self.assertRaisesRegex(ValueError,'changed'):
                    ART.package(ART.parser().parse_args(['package','--kind','lessons','--range','1']))
                self.assertFalse((root/'public/art/v2/lessons/day-001.webp').exists())
    def test_badge_key_retains_porcelain_and_removes_green(self):
        from PIL import Image
        image=Image.new('RGB',(20,20),(0,255,0))
        for x in range(5,15):
            for y in range(5,15):image.putpixel((x,y),(245,228,220))
        keyed=ART.key_badge(image)
        self.assertLess(keyed.getpixel((0,0))[3],5)
        self.assertGreater(keyed.getpixel((10,10))[3],250)

if __name__=='__main__':unittest.main()
