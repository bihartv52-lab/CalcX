---
name: Synthetix Noir
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#b9cacb'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#849495'
  outline-variant: '#3b494b'
  surface-tint: '#00dbe9'
  primary: '#dbfcff'
  on-primary: '#00363a'
  primary-container: '#00f0ff'
  on-primary-container: '#006970'
  inverse-primary: '#006970'
  secondary: '#ebb2ff'
  on-secondary: '#520072'
  secondary-container: '#b600f8'
  on-secondary-container: '#fff6fc'
  tertiary: '#faf3ff'
  on-tertiary: '#3c0090'
  tertiary-container: '#e1d2ff'
  on-tertiary-container: '#7213ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#7df4ff'
  primary-fixed-dim: '#00dbe9'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f54'
  secondary-fixed: '#f8d8ff'
  secondary-fixed-dim: '#ebb2ff'
  on-secondary-fixed: '#320047'
  on-secondary-fixed-variant: '#74009f'
  tertiary-fixed: '#e9ddff'
  tertiary-fixed-dim: '#d1bcff'
  on-tertiary-fixed: '#23005b'
  on-tertiary-fixed-variant: '#5700c9'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Sora
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Sora
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Sora
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Geist
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.1em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-margin: 24px
  gutter: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
  stack-xl: 64px
---

## Brand & Style

The design system is rooted in a **Cinematic Cyberpunk** aesthetic, blending the secretive allure of high-end tech with a raw, Gen Z energy. It prioritizes a "premium-dark" experience where the interface feels less like a tool and more like an advanced piece of hardware.

The style leverages **Glassmorphism** and **Neon Minimalism**. By stripping away unnecessary chrome and focusing on high-contrast glowing elements against matte surfaces, the UI evokes a sense of exclusivity and futuristic precision. Visual interest is driven by depth, light refraction, and ultra-smooth motion.

## Colors

The palette is designed for deep-space immersion.
- **Primary (Neon Blue):** Used for critical actions, active states, and primary data points. It should feel like it's emitting light.
- **Secondary (Electric Purple):** Used for accentuating depth, gradients, and secondary visual flourishes.
- **Background (Matte Black):** A true `#050505` foundation to maximize the contrast of the glass layers and neon highlights.
- **Surface (Deep Violet):** A semi-transparent overlay (`rgba(20, 10, 30, 0.6)`) used for glass cards to create a subtle chromatic link to the secondary color.

## Typography

This design system utilizes **Sora** for headlines to provide a bold, geometric, and modern feel that resonates with a premium tech audience. **Geist** is used for all functional text and data, offering a clean, monospaced-adjacent clarity that feels technical and precise.

Key typographic rules:
- Use **Headline LG** sparingly for hero numbers or impactful titles.
- **Labels** should always use high letter-spacing and uppercase styling to evoke a "heads-up display" (HUD) aesthetic.
- All technical data or values should be rendered in **Geist** to maintain the developer-grade precision look.

## Layout & Spacing

The layout follows a **Fluid Mobile-First Grid** with generous safe areas to enhance the "floating" feel of the UI. 
- **Margins:** A standard 24px margin on the left and right sides ensures content never feels cramped.
- **Vertical Rhythm:** Elements are grouped using a tight 8px base unit, but sections are separated by large 64px gaps to create an expensive, airy feel despite the dark theme.
- **Safe Zones:** Content should be centered or bottom-aligned to facilitate one-handed use on modern tall mobile devices.

## Elevation & Depth

Depth is achieved through **Glassmorphism** rather than traditional drop shadows.
- **Layers:** Use backdrop-blur (minimum 20px) on all floating cards. 
- **Borders:** Surfaces are defined by 1px semi-transparent borders. Top and left borders should be slightly brighter (`rgba(255, 255, 255, 0.15)`) than bottom and right borders to simulate a top-down light source.
- **Glows:** Primary elements (like buttons) utilize an "Outer Glow" instead of a shadow, using the primary neon blue color with a 15-25px blur at low opacity (30%).
- **Occlusion:** Use varying levels of transparency (0.4 to 0.8) to indicate hierarchy; more important elements are more opaque.

## Shapes

The shape language is defined by **Ultra-Rounded Corners**.
- **Cards & Modals:** Use a base radius of 24px (`rounded-xl` in this system).
- **Interactive Elements:** Buttons and input fields should follow the 24px rule to create a cohesive, "liquid" geometric look.
- **Nested Elements:** If a component is nested inside a 24px card, its radius should be reduced to 12px or 16px to maintain visual concentricity.

## Components

### Buttons
Primary buttons are high-contrast neon blue with a subtle inner glow. They should use `Label-MD` typography. Secondary buttons are "Ghost" style with a 1px white-alpha border and backdrop blur.

### Glass Cards
The core container for all content. These must have a background of `rgba(255, 255, 255, 0.03)`, a backdrop blur of 32px, and a subtle 1px border. They should appear to float over the matte black background.

### Inputs
Fields are strictly underlines or fully transparent rounded boxes with a 1px stroke. The active state triggers a primary neon blue glow around the border or under the line.

### Chips/Badges
Small, pill-shaped elements with a solid primary or secondary color background and black text (`label-sm`). These provide the "pop" of color needed to draw the eye to status changes.

### Progress Bars
Ultra-thin (2px - 4px) lines. The "filled" portion should be a linear gradient from Secondary Purple to Primary Blue, ending in a small glow "spark" at the leading edge.