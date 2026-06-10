# App Icon Setup Instructions

## Steps to Update App Icon:

1. Save the calculator icon image you provided as: `assets/images/app_icon.png`
   - The image should be at least 1024x1024 pixels
   - PNG format with transparency

2. Run the following commands to generate all icon sizes:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

3. This will automatically generate icons for all Android densities:
   - mipmap-mdpi (48x48)
   - mipmap-hdpi (72x72)
   - mipmap-xhdpi (96x96)
   - mipmap-xxhdpi (144x144)
   - mipmap-xxxhdpi (192x192)

4. Rebuild the APK after icon generation:
   ```bash
   flutter build apk --release
   ```

## Current Configuration:
- App name: "Calculator" (looks like a regular calculator app)
- Icon: Calculator design with purple accent
- Background: Dark (#1a1a1a) to match the calculator theme
