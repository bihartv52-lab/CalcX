from PIL import Image, ImageDraw, ImageFont
import os

# Create a 1024x1024 calculator icon
size = 1024
img = Image.new('RGBA', (size, size), (26, 26, 26, 255))
draw = ImageDraw.Draw(img)

# Draw rounded rectangle background
margin = 100
corner_radius = 180
draw.rounded_rectangle(
    [(margin, margin), (size-margin, size-margin)],
    radius=corner_radius,
    fill=(40, 40, 40, 255)
)

# Draw calculator display area
display_margin = 150
display_height = 200
draw.rounded_rectangle(
    [(display_margin, display_margin), (size-display_margin, display_margin+display_height)],
    radius=40,
    fill=(20, 20, 20, 255)
)

# Draw calculator buttons (4x5 grid)
button_size = 120
button_spacing = 30
start_x = 180
start_y = 450

# Purple accent color for equals button
purple = (147, 51, 234, 255)
gray = (60, 60, 60, 255)

for row in range(5):
    for col in range(4):
        x = start_x + col * (button_size + button_spacing)
        y = start_y + row * (button_size + button_spacing)
        
        # Last button (equals) in purple
        if row == 4 and col == 3:
            color = purple
        else:
            color = gray
            
        draw.rounded_rectangle(
            [(x, y), (x+button_size, y+button_size)],
            radius=25,
            fill=color
)

# Save
output_path = 'assets/images/app_icon.png'
os.makedirs(os.path.dirname(output_path), exist_ok=True)
img.save(output_path)
print(f"Icon created: {output_path}")
