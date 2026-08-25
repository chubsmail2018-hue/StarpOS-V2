import pygame as pg
import sys

# Initialize core modules explicitly
pg.init()
pg.font.init()

# --- WINDOW CONFIGURATION ---
WIDTH, HEIGHT = 900, 600
screen = pg.display.set_mode((WIDTH, HEIGHT))
pg.display.set_caption("Paint Whatever You Want vs Stickmen - ULTIMATE EDITION")
clock = pg.time.Clock()

# --- COLORS & CONFIG ---
BG_COLOR = (245, 245, 245)       # Paper canvas background
STICKMAN_COLOR = (40, 40, 40)    # Ink stickmen
HUD_BAR = (210, 210, 210)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

# Multi-functional palette matrix
PALETTE = [
    {"color": (234, 32, 39), "name": "FIRE RED (Damage)"},
    {"color": (27, 156, 252), "name": "ICE BLUE (Slows)"},
    {"color": (46, 204, 113), "name": "ACID GREEN (Melts)"},
    {"color": (0, 0, 0), "name": "BLACK INK (Solid Wall)"},
    {"color": (245, 245, 245), "name": "ERASER MODE"} # Matches background color
]
active_idx = 0
brush_size = 10

# --- GAME STATE MODULES ---
score = 0
paint_ammo = 300
loop_timer = 0
is_drawing = False

# High precision paint surface layer
drawing_canvas = pg.Surface((WIDTH, HEIGHT))
drawing_canvas.fill(BG_COLOR)

# Game lists
stickmen = []   # {"x", "y", "type", "hp", "max_hp", "speed", "slow_timer"}
energy_drops = [] # {"x", "y", "timer", "radius"}

font = pg.font.SysFont(None, 22)
bold_font = pg.font.SysFont(None, 24, bold=True)

# --- MAIN LOOP ---
running = True
while running:
    loop_timer += 1
    mx, my = pg.mouse.get_pos()
    
    # 1. INPUT INTERACTION LAYER
    for event in pg.event.get():
        if event.type == pg.QUIT:
            running = False
            
        elif event.type == pg.MOUSEBUTTONDOWN:
            if my > 60:
                is_drawing = True
            else:
                # Top HUD Color Selection Button Click Intercepts
                for idx, item in enumerate(PALETTE):
                    if 20 + (idx * 110) <= mx <= 120 + (idx * 110) and 15 <= my <= 45:
                        active_idx = idx
                
                # Clear Canvas button trigger
                if 780 <= mx <= 880 and 15 <= my <= 45:
                    drawing_canvas.fill(BG_COLOR)
                    paint_ammo = 300
                    score = 0

        elif event.type == pg.MOUSEBUTTONUP:
            is_drawing = False

    # Perform Drawing Surface Edits
    if is_drawing and my > 60:
        # Checking Ammo Restrictions (Eraser uses zero fuel resource cost)
        if paint_ammo > 0 or active_idx == 4:
            pg.draw.circle(drawing_canvas, PALETTE[active_idx]["color"], (mx, my), brush_size)
            if active_idx != 4:  # Consume resource ink
                paint_ammo -= 0.4

    # 2. SKY ENERGY DROP GENERATOR (Spawn collectible sun-paint drops)
    if loop_timer % 120 == 0:
        drop_x = (loop_timer * 23) % (WIDTH - 100) + 50
        drop_y = (loop_timer * 7) % (HEIGHT - 150) + 100
        energy_drops.append({"x": drop_x, "y": drop_y, "timer": 300})

    # Pick up drops via mouse hover
    for d in energy_drops[:]:
        d["timer"] -= 1
        dist = ((mx - d["x"])**2 + (my - d["y"])**2)**0.5
        if dist < 25:
            paint_ammo = min(500, paint_ammo + 60)
            energy_drops.remove(d)
        elif d["timer"] <= 0:
            energy_drops.remove(d)

    # 3. ENEMY SPAWNER ARRAY GENERATOR
    if loop_timer % 80 == 0:
        spawn_y = (loop_timer * 19) % (HEIGHT - 140) + 90
        enemy_roll = loop_timer % 3
        
        if enemy_roll == 0:   # THE NINJA (Fast, Low HP)
            stickmen.append({"x": 920, "y": spawn_y, "type": "ninja", "hp": 40, "max_hp": 40, "speed": 2.2, "slow_timer": 0, "size": 0.7})
        elif enemy_roll == 1: # THE BOSS BRUTE (Huge, Slow, Huge HP)
            stickmen.append({"x": 920, "y": spawn_y, "type": "brute", "hp": 300, "max_hp": 300, "speed": 0.6, "slow_timer": 0, "size": 1.6})
        else:                 # STANDARD MARCHING STICKMAN
            stickmen.append({"x": 920, "y": spawn_y, "type": "grunt", "hp": 100, "max_hp": 100, "speed": 1.2, "slow_timer": 0, "size": 1.0})

    # 4. PHYSICAL SCANNER ENGINE (Terrain Collision Loops)
    for s in stickmen[:]:
        # Handle active freeze status
        current_speed = s["speed"]
        if s["slow_timer"] > 0:
            s["slow_timer"] -= 1
            current_speed *= 0.4
            
        next_x = s["x"] - current_speed
        next_y = s["y"]
        
        # Hard coordinate firewall bounding check
        if 0 <= int(next_x) < WIDTH and 0 <= int(next_y) < HEIGHT:
            pixel_color = drawing_canvas.get_at((int(next_x), int(next_y)))[:3]
            
            if pixel_color != BG_COLOR:
                # Trigger special elemental ink traits based on color values under feet
                if pixel_color == (234, 32, 39):   # Red = Fire Damage
                    s["hp"] -= 0.8
                elif pixel_color == (27, 156, 252): # Blue = Frost Slow
                    s["slow_timer"] = 90
                elif pixel_color == (46, 204, 113):  # Green = Acid Corrosion Melt
                    s["hp"] -= 0.4
                    
                # Crawl upward safely to overcome lines
                s["x"] -= current_speed * 0.1
                s["y"] += (loop_timer % 3 - 1) * 0.6
                
                # Check for elemental death
                if s["hp"] <= 0:
                    if s in stickmen: stickmen.remove(s)
                    score += 1
                    continue
            else:
                s["x"] = next_x
        else:
            s["x"] = next_x

        # Check breach boundaries
        if s["x"] < -30:
            if s in stickmen: stickmen.remove(s)

    # 5. RENDERING PIPELINE DISPLAY
    screen.blit(drawing_canvas, (0, 0))

    # Render Falling Collectible Paint Bubbles
    for d in energy_drops:
        pulse = int(5 * (loop_timer % 20 / 20))
        pg.draw.circle(screen, (255, 195, 18), (d["x"], d["y"]), 14 + pulse)
        pg.draw.circle(screen, (255, 230, 0), (d["x"], d["y"]), 8)

    # Render Dynamic Variable Size Stickmen Models
    for s in stickmen:
        cx, cy = int(s["x"]), int(s["y"])
        sz = s["size"]
        
        # Draw HP overhead bar index profiles
        hp_pct = max(0, s["hp"]) / s["max_hp"]
        bar_w = int(34 * sz)
        pg.draw.rect(screen, (200, 200, 200), (cx - bar_w//2, cy - int(32*sz), bar_w, 5))
        pg.draw.rect(screen, (234, 32, 39), (cx - bar_w//2, cy - int(32*sz), int(bar_w * hp_pct), 5))
        
        # Color modifier highlight matching condition adjustments
        draw_color = (30, 144, 255) if s["slow_timer"] > 0 else STICKMAN_COLOR
        if s["type"] == "brute":
            pg.draw.rect(screen, (100, 100, 100), (cx - 10, cy - int(20*sz), 20, 20), 2) # Shoulder armor boxes
            
        # Draw scaled stick figures
        pg.draw.circle(screen, draw_color, (cx, cy - int(16*sz)), int(8*sz), 2)                     # Head
        pg.draw.line(screen, draw_color, (cx, cy - int(8*sz)), (cx, cy + int(14*sz)), 2)            # Spine
        pg.draw.line(screen, draw_color, (cx - int(12*sz), cy), (cx + int(12*sz), cy), 2)          # Arms
        pg.draw.line(screen, draw_color, (cx, cy + int(14*sz)), (cx - int(10*sz), cy + int(30*sz)), 2) # L-Leg
        pg.draw.line(screen, draw_color, (cx, cy + int(14*sz)), (cx + int(10*sz), cy + int(30*sz)), 2) # R-Leg

    # --- TOP LAYER NAVIGATION HUD CONTROL MENU BAR ---
    pg.draw.rect(screen, HUD_BAR, (0, 0, WIDTH, 60))
    pg.draw.line(screen, (160, 160, 160), (0, 60), (WIDTH, 60), 2)
    
    # Render Palette Toggles
    for idx, item in enumerate(PALETTE):
        btn_color = (255, 182, 193) if idx == 4 else item["color"] # Eraser shows pink button label
        pg.draw.rect(screen, btn_color, (20 + (idx * 110), 15, 25, 25))
        lbl_surface = font.render(item["name"].split()[0], True, BLACK)
        screen.blit(lbl_surface, (50 + (idx * 110), 20))
        
        if idx == active_idx: # Draw choice highlight cursor frame border
            pg.draw.rect(screen, BLACK, (16 + (idx * 110), 11, 33, 33), 2)

    # Render Active Fuel Resource Indicators
    pg.draw.rect(screen, (100, 100, 100), (570, 20, 110, 20))
    ammo_w = int(110 * (paint_ammo / 500))
    pg.draw.rect(screen, (46, 204, 113), (570, 20, ammo_w, 20))
    txt_ammo = font.render("PAINT INK", True, WHITE)
    screen.blit(txt_ammo, (585, 23))

    # Score board values
    score_surface = bold_font.render(f"Splatted: {score}", True, BLACK)
    screen.blit(score_surface, (695, 22))

    # Master Reset Button
    pg.draw.rect(screen, (192, 57, 43), (780, 15, 100, 30))
    clear_txt = font.render("WIPE TOTAL", True, WHITE)
    screen.blit(clear_txt, (792, 22))

    pg.display.flip()
    clock.tick(60)

pg.quit()
sys.exit()


    