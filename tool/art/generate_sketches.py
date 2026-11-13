#!/usr/bin/env python3
"""Generates HolyHim custom transparent minimalistic sketch illustrations and paywall artwork.
Creates:
1. assets/artwork/sketch_jesus_back.png
2. assets/artwork/sketch_jesus_child_path.png
3. assets/artwork/sketch_bible_open.png
4. assets/artwork/sketch_bible_dove.png
5. assets/artwork/paywall_bible_mountain.jpg
"""
import math
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/artwork"
OUT.mkdir(parents=True, exist_ok=True)

# Brand colors
INK = (24, 20, 26)         # Deep warm charcoal / black sketch lines
ROSE = (200, 138, 156)     # Soft blush rose
ROSE_PALE = (235, 195, 206)# Very pale rose
CHAMPAGNE = (242, 230, 218)# Cream / champagne
GOLD = (212, 175, 100)     # Warm holy gold
SAGE = (142, 164, 139)     # Gentle olive sage

def bezier(p0, p1, p2, p3, steps=40):
    """Generate points along a cubic Bezier curve."""
    pts = []
    for i in range(steps + 1):
        t = i / float(steps)
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts

def quad_bezier(p0, p1, p2, steps=30):
    """Generate points along a quadratic Bezier curve."""
    pts = []
    for i in range(steps + 1):
        t = i / float(steps)
        u = 1 - t
        x = u**2 * p0[0] + 2 * u * t * p1[0] + t**2 * p2[0]
        y = u**2 * p0[1] + 2 * u * t * p1[1] + t**2 * p2[1]
        pts.append((x, y))
    return pts

def apply_radial_feather(img, power=1.6, margin=0.08):
    """Feather the outer edges smoothly to 0 alpha so there are zero sharp boundaries."""
    arr = np.array(img, dtype=np.float32)
    h, w, _ = arr.shape
    y_idx, x_idx = np.ogrid[:h, :w]
    cx, cy = w / 2.0, h / 2.0
    rx, ry = (w / 2.0) * (1.0 - margin), (h / 2.0) * (1.0 - margin)
    dist = np.sqrt(((x_idx - cx) / rx) ** 2 + ((y_idx - cy) / ry) ** 2)
    
    # Cosine falloff from 0.6 to 1.0
    mask = np.clip((1.0 - dist) / 0.45, 0.0, 1.0)
    feather = 0.5 * (1.0 - np.cos(np.pi * mask))
    feather = np.power(feather, power)
    
    arr[:, :, 3] = arr[:, :, 3] * feather
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


# =========================================================================
# 1. Sketch: Jesus from the Back (Minimalistic, black line, brand watercolor)
# =========================================================================
def generate_sketch_jesus_back():
    W, H = 1000, 1200
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    
    draw_wash = ImageDraw.Draw(wash)
    draw_line = ImageDraw.Draw(line)
    
    # Center coordinates
    cx = 500
    head_y = 260
    
    # Subtle halo behind head (gentle watercolor aura)
    for r in range(130, 20, -5):
        alpha = int(45 * (1.0 - r / 130.0))
        draw_wash.ellipse([cx - r, head_y - r - 20, cx + r, head_y + r - 20], fill=(*GOLD, alpha))
        draw_wash.ellipse([cx - r * 0.7, head_y - r * 0.7 - 20, cx + r * 0.7, head_y + r * 0.7 - 20], fill=(*ROSE_PALE, alpha // 2))

    # Robe watercolor washes inside silhouette
    # Main mantle wash (blush rose / champagne)
    mantle_poly = [
        (cx - 30, head_y + 40), (cx + 30, head_y + 40),
        (cx + 120, head_y + 110), (cx + 210, head_y + 350),
        (cx + 250, head_y + 650), (cx + 180, head_y + 750),
        (cx - 180, head_y + 750), (cx - 250, head_y + 650),
        (cx - 210, head_y + 350), (cx - 120, head_y + 110)
    ]
    draw_wash.polygon(mantle_poly, fill=(*CHAMPAGNE, 150))
    
    # Rose blush accent wash on shoulders & drapery
    rose_poly = [
        (cx - 110, head_y + 110), (cx + 110, head_y + 110),
        (cx + 180, head_y + 320), (cx + 90, head_y + 550),
        (cx - 70, head_y + 520), (cx - 170, head_y + 300)
    ]
    draw_wash.polygon(rose_poly, fill=(*ROSE, 110))
    
    # Sage watercolor shadows in deep folds
    sage_fold1 = quad_bezier((cx - 40, head_y + 220), (cx - 90, head_y + 450), (cx - 110, head_y + 720))
    sage_fold2 = quad_bezier((cx + 50, head_y + 240), (cx + 100, head_y + 480), (cx + 130, head_y + 730))
    for pt in sage_fold1 + sage_fold2:
        draw_wash.circle(pt, radius=24, fill=(*SAGE, 40))
        
    wash = wash.filter(ImageFilter.GaussianBlur(radius=18))
    
    # Minimal black ink sketch line drawing
    # Head & hair (viewed from back, soft shoulder-length waves)
    draw_line.arc([cx - 42, head_y - 65, cx + 42, head_y + 25], 180, 360, fill=(*INK, 220), width=3)
    # Hair locks falling down
    for offset, curve_pts in [
        (-25, quad_bezier((cx - 30, head_y - 30), (cx - 48, head_y + 20), (cx - 35, head_y + 75))),
        (-10, quad_bezier((cx - 12, head_y - 20), (cx - 18, head_y + 35), (cx - 15, head_y + 85))),
        (10, quad_bezier((cx + 12, head_y - 20), (cx + 18, head_y + 35), (cx + 15, head_y + 85))),
        (25, quad_bezier((cx + 30, head_y - 30), (cx + 48, head_y + 20), (cx + 35, head_y + 75))),
    ]:
        draw_line.line(curve_pts, fill=(*INK, 210), width=2)

    # Shoulders & outer robe contours
    left_shoulder = bezier((cx - 38, head_y + 60), (cx - 110, head_y + 90), (cx - 175, head_y + 150), (cx - 215, head_y + 290))
    right_shoulder = bezier((cx + 38, head_y + 60), (cx + 110, head_y + 90), (cx + 175, head_y + 150), (cx + 215, head_y + 290))
    draw_line.line(left_shoulder, fill=(*INK, 240), width=4)
    draw_line.line(right_shoulder, fill=(*INK, 240), width=4)
    
    # Torso and flowing robe sides
    left_side = bezier((cx - 215, head_y + 290), (cx - 240, head_y + 470), (cx - 230, head_y + 630), (cx - 185, head_y + 760))
    right_side = bezier((cx + 215, head_y + 290), (cx + 240, head_y + 470), (cx + 230, head_y + 630), (cx + 185, head_y + 760))
    draw_line.line(left_side, fill=(*INK, 230), width=3)
    draw_line.line(right_side, fill=(*INK, 230), width=3)
    
    # Bottom hem with gentle wave folds
    hem = bezier((cx - 185, head_y + 760), (cx - 70, head_y + 775), (cx + 70, head_y + 775), (cx + 185, head_y + 760))
    draw_line.line(hem, fill=(*INK, 220), width=3)

    # Internal vertical robe drapery folds (minimalist sketched)
    folds = [
        bezier((cx - 15, head_y + 95), (cx - 30, head_y + 250), (cx - 25, head_y + 510), (cx - 20, head_y + 768)),
        bezier((cx + 15, head_y + 95), (cx + 35, head_y + 250), (cx + 40, head_y + 510), (cx + 45, head_y + 768)),
        bezier((cx - 95, head_y + 160), (cx - 130, head_y + 350), (cx - 135, head_y + 560), (cx - 110, head_y + 762)),
        bezier((cx + 95, head_y + 160), (cx + 130, head_y + 350), (cx + 135, head_y + 560), (cx + 110, head_y + 762)),
        bezier((cx - 55, head_y + 280), (cx - 75, head_y + 460), (cx - 70, head_y + 660), (cx - 65, head_y + 765)),
        bezier((cx + 55, head_y + 280), (cx + 80, head_y + 460), (cx + 85, head_y + 660), (cx + 90, head_y + 765)),
    ]
    for f in folds:
        draw_line.line(f, fill=(*INK, 185), width=2)
        
    # Gentle subtle cross-hatch shading on side shadow
    for y_s in range(head_y + 320, head_y + 640, 28):
        draw_line.line([(cx - 180 + (y_s % 15), y_s), (cx - 130 + (y_s % 15), y_s + 18)], fill=(*INK, 90), width=1)
        draw_line.line([(cx + 140 - (y_s % 15), y_s), (cx + 185 - (y_s % 15), y_s + 20)], fill=(*INK, 90), width=1)

    # Composite wash + line art
    base.alpha_composite(wash)
    base.alpha_composite(line)
    
    # Apply soft radial feathering to eliminate any edge cuts
    feathered = apply_radial_feather(base, power=1.4, margin=0.04)
    feathered.save(OUT / "sketch_jesus_back.png", "PNG")
    print("Generated:", OUT / "sketch_jesus_back.png")


# =========================================================================
# 2. Sketch: Jesus & Female Child Walking Hand-in-Hand on Path
# =========================================================================
def generate_sketch_jesus_child_path():
    W, H = 1000, 1100
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    
    draw_wash = ImageDraw.Draw(wash)
    draw_line = ImageDraw.Draw(line)
    
    # Path coordinates (curving away into background)
    path_left = bezier((280, 950), (370, 780), (430, 580), (480, 420))
    path_right = bezier((720, 950), (630, 780), (570, 580), (520, 420))
    
    # Path soft watercolor wash
    path_poly = path_left + list(reversed(path_right))
    draw_wash.polygon(path_poly, fill=(*CHAMPAGNE, 120))
    
    # Flora along the path (sage and rose sprigs)
    for px, py in [(260, 910), (310, 830), (370, 730), (740, 910), (680, 820), (620, 710)]:
        draw_wash.circle((px, py), radius=35, fill=(*SAGE, 60))
        draw_wash.circle((px + 10, py - 10), radius=20, fill=(*ROSE_PALE, 55))
        
    # Jesus coordinates (Left figure, taller, viewed from back/three-quarter)
    jx = 430
    jy = 310
    
    # Child coordinates (Right figure, smaller female child, walking beside Him)
    cx = 585
    cy = 500
    
    # Washes for Jesus's robe (champagne, soft rose, sage)
    j_poly = [
        (jx - 25, jy + 30), (jx + 25, jy + 30),
        (jx + 80, jy + 110), (jx + 110, jy + 320), (jx + 80, jy + 520),
        (jx - 80, jy + 520), (jx - 110, jy + 320), (jx - 80, jy + 110)
    ]
    draw_wash.polygon(j_poly, fill=(*CHAMPAGNE, 150))
    draw_wash.polygon([(jx - 70, jy + 110), (jx + 40, jy + 110), (jx + 70, jy + 420), (jx - 40, jy + 480)], fill=(*ROSE, 110))
    
    # Washes for Child's dress (soft blush rose & pale gold)
    c_poly = [
        (cx - 18, cy + 20), (cx + 18, cy + 20),
        (cx + 45, cy + 90), (cx + 65, cy + 240),
        (cx - 65, cy + 240), (cx - 45, cy + 90)
    ]
    draw_wash.polygon(c_poly, fill=(*ROSE, 160))
    draw_wash.polygon([(cx - 15, cy + 25), (cx + 15, cy + 25), (cx + 35, cy + 180), (cx - 20, cy + 200)], fill=(*ROSE_PALE, 140))
    
    # Soft warm glow between them
    draw_wash.ellipse([470, 480, 560, 570], fill=(*GOLD, 85))
    wash = wash.filter(ImageFilter.GaussianBlur(radius=15))

    # ================= Line Art: Jesus =================
    # Head & hair
    draw_line.arc([jx - 30, jy - 55, jx + 30, jy + 15], 180, 360, fill=(*INK, 220), width=3)
    for pts in [
        quad_bezier((jx - 22, jy - 20), (jx - 35, jy + 20), (jx - 25, jy + 60)),
        quad_bezier((jx - 8, jy - 10), (jx - 12, jy + 25), (jx - 10, jy + 65)),
        quad_bezier((jx + 12, jy - 10), (jx + 15, jy + 25), (jx + 12, jy + 65)),
        quad_bezier((jx + 24, jy - 20), (jx + 32, jy + 20), (jx + 22, jy + 60)),
    ]:
        draw_line.line(pts, fill=(*INK, 200), width=2)
        
    # Shoulders & Robe
    draw_line.line(bezier((jx - 28, jy + 45), (jx - 75, jy + 80), (jx - 110, jy + 140), (jx - 120, jy + 260)), fill=(*INK, 240), width=3)
    draw_line.line(bezier((jx + 28, jy + 45), (jx + 65, jy + 80), (jx + 90, jy + 130), (jx + 105, jy + 240)), fill=(*INK, 230), width=3)
    # Robe down to feet
    draw_line.line(bezier((jx - 120, jy + 260), (jx - 130, jy + 390), (jx - 115, jy + 480), (jx - 75, jy + 535)), fill=(*INK, 230), width=3)
    draw_line.line(bezier((jx + 105, jy + 240), (jx + 95, jy + 380), (jx + 80, jy + 470), (jx + 55, jy + 535)), fill=(*INK, 230), width=3)
    draw_line.line(bezier((jx - 75, jy + 535), (jx - 10, jy + 545), (jx + 25, jy + 545), (jx + 55, jy + 535)), fill=(*INK, 210), width=2)
    # Folds
    for f in [
        bezier((jx - 15, jy + 75), (jx - 35, jy + 230), (jx - 25, jy + 410), (jx - 20, jy + 538)),
        bezier((jx + 15, jy + 75), (jx + 30, jy + 230), (jx + 25, jy + 410), (jx + 20, jy + 538)),
        bezier((jx - 65, jy + 150), (jx - 85, jy + 320), (jx - 75, jy + 470), (jx - 60, jy + 535)),
    ]:
        draw_line.line(f, fill=(*INK, 175), width=2)
        
    # Right arm reaching down to hold child's hand
    j_arm = bezier((jx + 85, jy + 135), (jx + 95, jy + 240), (jx + 80, jy + 330), (508, 515))
    draw_line.line(j_arm, fill=(*INK, 220), width=3)

    # ================= Line Art: Female Child =================
    # Head & braided / gentle wavy hair
    draw_line.arc([cx - 20, cy - 42, cx + 20, cy + 10], 180, 360, fill=(*INK, 220), width=2)
    # Hair braid / ribbons
    draw_line.line(quad_bezier((cx, cy - 10), (cx + 12, cy + 25), (cx + 8, cy + 60)), fill=(*INK, 210), width=2)
    draw_line.line(quad_bezier((cx - 8, cy - 5), (cx - 15, cy + 20), (cx - 12, cy + 45)), fill=(*INK, 190), width=2)
    
    # Child's shoulders and little dress
    draw_line.line(bezier((cx - 15, cy + 18), (cx - 35, cy + 38), (cx - 45, cy + 70), (cx - 52, cy + 130)), fill=(*INK, 220), width=2)
    draw_line.line(bezier((cx + 15, cy + 18), (cx + 35, cy + 38), (cx + 45, cy + 70), (cx + 52, cy + 130)), fill=(*INK, 220), width=2)
    # Dress flare and hem
    draw_line.line(bezier((cx - 52, cy + 130), (cx - 58, cy + 190), (cx - 62, cy + 235), (cx - 55, cy + 250)), fill=(*INK, 220), width=2)
    draw_line.line(bezier((cx + 52, cy + 130), (cx + 58, cy + 190), (cx + 62, cy + 235), (cx + 55, cy + 250)), fill=(*INK, 220), width=2)
    draw_line.line(bezier((cx - 55, cy + 250), (cx, cy + 255), (cx + 30, cy + 255), (cx + 55, cy + 250)), fill=(*INK, 200), width=2)
    # Little legs walking forward
    draw_line.line([(cx - 20, cy + 250), (cx - 22, cy + 285)], fill=(*INK, 200), width=2)
    draw_line.line([(cx + 18, cy + 250), (cx + 25, cy + 290)], fill=(*INK, 200), width=2)
    
    # Left arm reaching up to hold Jesus's hand
    c_arm = bezier((cx - 35, cy + 40), (cx - 45, cy + 85), (cx - 48, cy + 125), (512, 515))
    draw_line.line(c_arm, fill=(*INK, 220), width=2)
    
    # Clasping hands (warm, gentle sketched clasp)
    draw_line.arc([502, 506, 518, 524], 0, 360, fill=(*INK, 230), width=3)
    
    # Path lines (minimal dashed/pebble sketch)
    draw_line.line(path_left, fill=(*INK, 100), width=2)
    draw_line.line(path_right, fill=(*INK, 100), width=2)
    
    # Composite wash + lines
    base.alpha_composite(wash)
    base.alpha_composite(line)
    
    feathered = apply_radial_feather(base, power=1.4, margin=0.04)
    feathered.save(OUT / "sketch_jesus_child_path.png", "PNG")
    print("Generated:", OUT / "sketch_jesus_child_path.png")


# =========================================================================
# 3. Sketch: Open Bible Book with Floral / Olive Sprigs
# =========================================================================
def generate_sketch_bible_open():
    W, H = 1000, 900
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    
    draw_wash = ImageDraw.Draw(wash)
    draw_line = ImageDraw.Draw(line)
    
    cx = 500
    cy = 440
    
    # Soft background glow behind Bible
    for r in range(260, 60, -15):
        alpha = int(40 * (1.0 - r / 260.0))
        draw_wash.ellipse([cx - r * 1.3, cy - r * 0.9, cx + r * 1.3, cy + r * 0.9], fill=(*GOLD, alpha))
        draw_wash.ellipse([cx - r * 0.9, cy - r * 0.7, cx + r * 0.9, cy + r * 0.7], fill=(*ROSE_PALE, alpha // 2))

    # Pages watercolor fill (cream champagne with subtle rose edges)
    left_page_poly = [
        (cx - 10, cy - 80), (cx - 160, cy - 130), (cx - 340, cy - 85),
        (cx - 365, cy + 90), (cx - 180, cy + 135), (cx - 10, cy + 95)
    ]
    right_page_poly = [
        (cx + 10, cy - 80), (cx + 160, cy - 130), (cx + 340, cy - 85),
        (cx + 365, cy + 90), (cx + 180, cy + 135), (cx + 10, cy + 95)
    ]
    draw_wash.polygon(left_page_poly, fill=(*CHAMPAGNE, 180))
    draw_wash.polygon(right_page_poly, fill=(*CHAMPAGNE, 180))
    draw_wash.polygon([(cx - 340, cy - 85), (cx - 365, cy + 90), (cx - 240, cy + 115), (cx - 230, cy - 105)], fill=(*ROSE_PALE, 90))
    draw_wash.polygon([(cx + 340, cy - 85), (cx + 365, cy + 90), (cx + 240, cy + 115), (cx + 230, cy - 105)], fill=(*ROSE_PALE, 90))
    
    # Silk ribbon bookmark wash draping down center
    ribbon_wash = bezier((cx, cy - 60), (cx - 25, cy + 80), (cx + 35, cy + 220), (cx + 10, cy + 310))
    for pt in ribbon_wash:
        draw_wash.circle(pt, radius=18, fill=(*ROSE, 140))
        
    # Olive sprigs & floral watercolor wash around edges
    for ox, oy in [
        (cx - 360, cy - 40), (cx - 320, cy - 150), (cx - 240, cy - 170),
        (cx + 360, cy - 40), (cx + 320, cy - 150), (cx + 240, cy - 170),
        (cx - 280, cy + 180), (cx + 280, cy + 180)
    ]:
        draw_wash.circle((ox, oy), radius=28, fill=(*SAGE, 85))
        draw_wash.circle((ox + 12, oy - 12), radius=16, fill=(*ROSE, 75))
        
    wash = wash.filter(ImageFilter.GaussianBlur(radius=12))

    # ================= Line Art: Open Bible =================
    # Top curve of pages fanning open
    left_top = bezier((cx - 10, cy - 80), (cx - 140, cy - 145), (cx - 260, cy - 135), (cx - 340, cy - 85))
    right_top = bezier((cx + 10, cy - 80), (cx + 140, cy - 145), (cx + 260, cy - 135), (cx + 340, cy - 85))
    draw_line.line(left_top, fill=(*INK, 240), width=3)
    draw_line.line(right_top, fill=(*INK, 240), width=3)

    # Outer page edges
    draw_line.line(quad_bezier((cx - 340, cy - 85), (cx - 355, cy + 5), (cx - 365, cy + 90)), fill=(*INK, 240), width=3)
    draw_line.line(quad_bezier((cx + 340, cy - 85), (cx + 355, cy + 5), (cx + 365, cy + 90)), fill=(*INK, 240), width=3)

    # Bottom curve of pages
    left_bottom = bezier((cx - 10, cy + 95), (cx - 140, cy + 50), (cx - 260, cy + 60), (cx - 365, cy + 90))
    right_bottom = bezier((cx + 10, cy + 95), (cx + 140, cy + 50), (cx + 260, cy + 60), (cx + 365, cy + 90))
    draw_line.line(left_bottom, fill=(*INK, 240), width=3)
    draw_line.line(right_bottom, fill=(*INK, 240), width=3)

    # Spine center gutter
    draw_line.line([(cx, cy - 78), (cx, cy + 98)], fill=(*INK, 220), width=3)
    
    # Layered book page block (page depth under the book)
    draw_line.line([(cx - 365, cy + 90), (cx - 365, cy + 115)], fill=(*INK, 200), width=2)
    draw_line.line([(cx + 365, cy + 90), (cx + 365, cy + 115)], fill=(*INK, 200), width=2)
    draw_line.line(bezier((cx - 10, cy + 120), (cx - 140, cy + 75), (cx - 260, cy + 85), (cx - 365, cy + 115)), fill=(*INK, 190), width=2)
    draw_line.line(bezier((cx + 10, cy + 120), (cx + 140, cy + 75), (cx + 260, cy + 85), (cx + 365, cy + 115)), fill=(*INK, 190), width=2)

    # Minimal text lines (scriptural layout, gentle grey lines)
    for row in range(cy - 60, cy + 75, 18):
        # Left page two-column text hints
        draw_line.line([(cx - 310, row), (cx - 185, row)], fill=(*INK, 100), width=2)
        draw_line.line([(cx - 165, row), (cx - 40, row)], fill=(*INK, 100), width=2)
        # Right page two-column text hints
        draw_line.line([(cx + 40, row), (cx + 165, row)], fill=(*INK, 100), width=2)
        draw_line.line([(cx + 185, row), (cx + 310, row)], fill=(*INK, 100), width=2)

    # Silk ribbon marker hanging down
    ribbon_pts = bezier((cx, cy - 65), (cx - 20, cy + 70), (cx + 30, cy + 200), (cx + 8, cy + 300))
    draw_line.line(ribbon_pts, fill=(*INK, 230), width=3)
    ribbon_pts2 = bezier((cx + 6, cy - 65), (cx - 14, cy + 70), (cx + 36, cy + 200), (cx + 14, cy + 300))
    draw_line.line(ribbon_pts2, fill=(*INK, 230), width=3)
    # V-cut end of ribbon
    draw_line.line([(cx + 8, cy + 300), (cx + 11, cy + 290), (cx + 14, cy + 300)], fill=(*INK, 230), width=2)

    # Olive sprigs & botanical line art framing the Bible
    for side in (-1, 1):
        stem = bezier((cx + side * 220, cy - 140), (cx + side * 310, cy - 170), (cx + side * 380, cy - 120), (cx + side * 410, cy - 40))
        draw_line.line(stem, fill=(*INK, 210), width=2)
        # Leaves
        for t_val in [0.25, 0.5, 0.75, 0.95]:
            p = stem[int(len(stem) * t_val)]
            leaf_end = (p[0] + side * 30, p[1] - 20)
            draw_line.line(quad_bezier(p, (p[0] + side * 15, p[1] - 25), leaf_end), fill=(*INK, 190), width=2)
            draw_line.line(quad_bezier(leaf_end, (p[0] + side * 20, p[1] - 5), p), fill=(*INK, 190), width=2)
            
    base.alpha_composite(wash)
    base.alpha_composite(line)
    
    feathered = apply_radial_feather(base, power=1.4, margin=0.04)
    feathered.save(OUT / "sketch_bible_open.png", "PNG")
    print("Generated:", OUT / "sketch_bible_open.png")


# =========================================================================
# 4. Sketch: Heirloom Bible with Peaceful Dove & Light Rays
# =========================================================================
def generate_sketch_bible_dove():
    W, H = 1000, 1100
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    
    draw_wash = ImageDraw.Draw(wash)
    draw_line = ImageDraw.Draw(line)
    
    cx = 500
    bible_y = 650
    dove_y = 330
    
    # Heavenly light rays expanding from dove down to Bible
    for angle_deg in range(-55, 60, 10):
        rad = math.radians(angle_deg)
        ray_end = (cx + math.sin(rad) * 450, dove_y + math.cos(rad) * 450)
        draw_wash.line([(cx, dove_y), ray_end], fill=(*GOLD, 35), width=22)
        
    # Dove soft glowing aura
    for r in range(160, 30, -10):
        draw_wash.ellipse([cx - r, dove_y - r * 0.8, cx + r, dove_y + r * 0.8], fill=(*GOLD, int(30 * (1 - r/160))))
        draw_wash.ellipse([cx - r*0.7, dove_y - r*0.5, cx + r*0.7, dove_y + r*0.5], fill=(*ROSE_PALE, int(25 * (1 - r/160))))

    # Bible cover wash (warm rose leather & champagne edges)
    b_poly = [
        (cx - 220, bible_y - 80), (cx + 180, bible_y - 140),
        (cx + 250, bible_y + 110), (cx - 150, bible_y + 170)
    ]
    draw_wash.polygon(b_poly, fill=(*ROSE, 140))
    draw_wash.polygon([(cx - 220, bible_y - 80), (cx - 150, bible_y + 170), (cx - 150, bible_y + 200), (cx - 220, bible_y - 50)], fill=(*CHAMPAGNE, 170))
    
    # Ribbon wash
    draw_wash.polygon([(cx + 20, bible_y - 120), (cx + 40, bible_y - 120), (cx + 60, bible_y + 220), (cx + 40, bible_y + 220)], fill=(*GOLD, 180))

    wash = wash.filter(ImageFilter.GaussianBlur(radius=14))

    # ================= Line Art: Dove in Flight =================
    # Body and head
    draw_line.arc([cx - 20, dove_y - 45, cx + 20, dove_y - 5], 180, 360, fill=(*INK, 240), width=3)
    # Beak carrying olive sprig
    draw_line.line([(cx + 18, dove_y - 25), (cx + 34, dove_y - 20)], fill=(*INK, 230), width=2)
    # Olive twig in beak
    draw_line.line([(cx + 28, dove_y - 22), (cx + 48, dove_y - 32)], fill=(*INK, 210), width=2)
    draw_line.arc([cx + 38, dove_y - 38, cx + 52, dove_y - 24], 0, 360, fill=(*INK, 190), width=2)
    
    # Wings gracefully fanning outward and upward
    # Left wing
    left_wing_top = bezier((cx - 10, dove_y - 25), (cx - 110, dove_y - 140), (cx - 190, dove_y - 130), (cx - 240, dove_y - 70))
    draw_line.line(left_wing_top, fill=(*INK, 240), width=3)
    left_wing_feathers = bezier((cx - 240, dove_y - 70), (cx - 180, dove_y - 20), (cx - 110, dove_y + 5), (cx - 15, dove_y + 15))
    draw_line.line(left_wing_feathers, fill=(*INK, 230), width=3)
    # Primary feather details
    for f_pts in [
        bezier((cx - 190, dove_y - 100), (cx - 170, dove_y - 50), (cx - 140, dove_y - 10), (cx - 30, dove_y + 10)),
        bezier((cx - 150, dove_y - 80), (cx - 130, dove_y - 40), (cx - 100, dove_y - 5), (cx - 25, dove_y + 12)),
    ]:
        draw_line.line(f_pts, fill=(*INK, 180), width=2)

    # Right wing
    right_wing_top = bezier((cx + 10, dove_y - 25), (cx + 110, dove_y - 140), (cx + 190, dove_y - 130), (cx + 240, dove_y - 70))
    draw_line.line(right_wing_top, fill=(*INK, 240), width=3)
    right_wing_feathers = bezier((cx + 240, dove_y - 70), (cx + 180, dove_y - 20), (cx + 110, dove_y + 5), (cx + 15, dove_y + 15))
    draw_line.line(right_wing_feathers, fill=(*INK, 230), width=3)
    for f_pts in [
        bezier((cx + 190, dove_y - 100), (cx + 170, dove_y - 50), (cx + 140, dove_y - 10), (cx + 30, dove_y + 10)),
        bezier((cx + 150, dove_y - 80), (cx + 130, dove_y - 40), (cx + 100, dove_y - 5), (cx + 25, dove_y + 12)),
    ]:
        draw_line.line(f_pts, fill=(*INK, 180), width=2)
        
    # Tail feathers
    tail = bezier((cx - 12, dove_y + 15), (cx - 25, dove_y + 75), (cx, dove_y + 85), (cx + 12, dove_y + 15))
    draw_line.line(tail, fill=(*INK, 220), width=2)

    # ================= Line Art: Closed Heirloom Bible =================
    # Top leather cover
    draw_line.line([(cx - 220, bible_y - 80), (cx + 180, bible_y - 140)], fill=(*INK, 240), width=3)
    draw_line.line([(cx + 180, bible_y - 140), (cx + 250, bible_y + 110)], fill=(*INK, 240), width=3)
    draw_line.line([(cx + 250, bible_y + 110), (cx - 150, bible_y + 170)], fill=(*INK, 240), width=3)
    draw_line.line([(cx - 150, bible_y + 170), (cx - 220, bible_y - 80)], fill=(*INK, 240), width=3)
    
    # Spine and page thickness
    draw_line.line([(cx - 220, bible_y - 80), (cx - 220, bible_y - 45)], fill=(*INK, 220), width=3)
    draw_line.line([(cx - 150, bible_y + 170), (cx - 150, bible_y + 205)], fill=(*INK, 220), width=3)
    draw_line.line([(cx + 250, bible_y + 110), (cx + 250, bible_y + 145)], fill=(*INK, 220), width=3)
    # Bottom rim of cover
    draw_line.line([(cx - 220, bible_y - 45), (cx - 150, bible_y + 205)], fill=(*INK, 220), width=3)
    draw_line.line([(cx - 150, bible_y + 205), (cx + 250, bible_y + 145)], fill=(*INK, 220), width=3)

    # Embossed gold cross on Bible cover
    cross_cx = cx + 15
    cross_cy = bible_y + 15
    draw_line.line([(cross_cx, cross_cy - 65), (cross_cx, cross_cy + 65)], fill=(*INK, 220), width=3)
    draw_line.line([(cross_cx - 40, cross_cy - 25), (cross_cx + 40, cross_cy - 25)], fill=(*INK, 220), width=3)
    
    # Gold ribbon draped across
    draw_line.line([(cx + 30, bible_y - 130), (cx + 45, bible_y + 230)], fill=(*INK, 220), width=3)
    draw_line.line([(cx + 45, bible_y - 130), (cx + 60, bible_y + 230)], fill=(*INK, 220), width=3)

    base.alpha_composite(wash)
    base.alpha_composite(line)
    
    feathered = apply_radial_feather(base, power=1.4, margin=0.04)
    feathered.save(OUT / "sketch_bible_dove.png", "PNG")
    print("Generated:", OUT / "sketch_bible_dove.png")


# =========================================================================
# 5. Paywall Header Image: Open Bible with Inspiring Pink Nature
# =========================================================================
def generate_paywall_bible_mountain():
    # Target size: 1080 x 1920 (9:16 high resolution)
    W, H = 1080, 1920
    
    # 1. Load pink nature landscape from unit-01/landscape.png or library
    landscape_src = ROOT / "art/generated/chapters/unit-01/landscape.png"
    if not landscape_src.exists():
        landscape_src = ROOT / "art/generated/library/sky-dawn.png"
    landscape = Image.open(landscape_src).convert("RGBA")
    landscape = ImageOps.fit(landscape, (W, H), method=Image.Resampling.LANCZOS)
    
    # Tint landscape with ethereal blush-pink sunrise glow
    pink_veil = Image.new("RGBA", (W, H), (235, 175, 195, 75))
    landscape.alpha_composite(pink_veil)
    
    # 2. Load open Bible from scripture-morning.png or scripture-garden.png
    bible_src = ROOT / "art/generated/library/scripture-morning.png"
    if not bible_src.exists():
        bible_src = ROOT / "art/generated/library/scripture-garden.png"
    bible = Image.open(bible_src).convert("RGBA")
    
    # Crop the Bible subject neatly
    bw, bh = bible.size
    # Focus on the Bible resting in the lower-middle region
    bible_crop = bible.crop((int(bw * 0.05), int(bh * 0.15), int(bw * 0.95), int(bh * 0.85)))
    bible_crop = bible_crop.resize((W, int(W * 0.9)), Image.Resampling.LANCZOS)
    
    # 3. Soft vignette / alpha mask on the Bible so it floats seamlessly in pink nature
    mask = Image.new("L", bible_crop.size, 0)
    draw_mask = ImageDraw.Draw(mask)
    mcx, mcy = bible_crop.size[0] // 2, bible_crop.size[1] // 2
    for r in range(min(mcx, mcy), 0, -5):
        alpha = int(255 * (1.0 - (r / min(mcx, mcy)) ** 2))
        draw_mask.ellipse([mcx - r * 1.3, mcy - r * 0.85, mcx + r * 1.3, mcy + r * 0.85], fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=30))
    
    # Composite the Bible into the upper third (y = 120 to 900)
    bible_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bible_layer.paste(bible_crop, (0, 140), mask=mask)
    
    # Add gentle pink blossoms and floating petals in the top region
    draw_blossoms = ImageDraw.Draw(bible_layer)
    for bx, by in [
        (120, 220), (180, 180), (280, 260), (840, 210), (920, 280),
        (820, 360), (150, 420), (910, 480), (320, 160), (740, 170)
    ]:
        for ang in range(0, 360, 72):
            rad = math.radians(ang)
            px = bx + math.cos(rad) * 18
            py = by + math.sin(rad) * 18
            draw_blossoms.ellipse([px - 14, py - 14, px + 14, py + 14], fill=(*ROSE, 120))
        draw_blossoms.circle((bx, by), radius=8, fill=(*GOLD, 180))

    canvas = Image.new("RGBA", (W, H), (252, 247, 248, 255))
    canvas.alpha_composite(landscape)
    canvas.alpha_composite(bible_layer)
    
    # 4. Smooth gradient fade down the lower half:
    # Top 38% is clear and vivid; middle 38% to 65% blurs and transitions into gentle warm veil;
    # Lower 35% is a calm, soft luminous cream-blush surface ready for paywall text
    lower_blur = canvas.filter(ImageFilter.GaussianBlur(radius=28))
    
    # Gradient alpha blend
    final = canvas.copy()
    arr_c = np.array(canvas, dtype=np.float32)
    arr_b = np.array(lower_blur, dtype=np.float32)
    
    y_idx = np.arange(H).reshape(H, 1, 1)
    # 0 at y=500, 1 at y=950
    blur_weight = np.clip((y_idx - 500) / 450.0, 0.0, 1.0)
    # Cosine smoothstep
    blur_weight = 0.5 * (1.0 - np.cos(np.pi * blur_weight))
    
    blended = arr_c * (1.0 - blur_weight) + arr_b * blur_weight
    final = Image.fromarray(np.clip(blended, 0, 255).astype(np.uint8))
    
    final.save(OUT / "paywall_bible_mountain.jpg", "PNG")
    print("Generated:", OUT / "paywall_bible_mountain.jpg")


if __name__ == "__main__":
    generate_sketch_jesus_back()
    generate_sketch_jesus_child_path()
    generate_sketch_bible_open()
    generate_sketch_bible_dove()
    generate_paywall_bible_mountain()
    print("All artwork generated successfully!")
