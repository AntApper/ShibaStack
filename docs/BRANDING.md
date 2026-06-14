# ShibaStack Branding and Theme Color Guidelines

This document establishes the official brand identity, color palette, typography, and design guidelines for ShibaStack. These rules ensure that all user interfaces, CLI outputs, and packaging assets maintain a professional, unified, and cohesive appearance.

---

## 1. Brand Identity and Philosophy

ShibaStack (formerly Apple Private Container or APC) represents high-performance, containerized virtualization that runs natively on Apple Silicon with near-zero overhead. 

The Shiba Inu mascot represents:
- **Loyalty and Reliability:** The core virtualization layer is robust, secure, and always accessible.
- **Compact Agility:** The system has an ultra-lightweight footprint, operating in user-space with near-zero resource impact.
- **Friendly Accessibility:** Complex hypervisor and hardware systems are made straightforward and manageable through simple interfaces.

---

## 2. Color Palette Guidelines

ShibaStack interfaces utilize a custom color scheme based on the warm tones of the Shiba Inu coat, contrasted with clean charcoal interfaces to ensure high accessibility, readability, and a modern appearance.

### 2.1 Primary Brand Colors

| Color Name | Hex Code | RGB Values | Purpose |
| :--- | :--- | :--- | :--- |
| **Shiba Orange** | `#E06D3A` | `rgb(224, 109, 58)` | Primary brand color, used for active buttons, highlights, and accent icons. |
| **Shiba Cream** | `#F7EAD3` | `rgb(247, 234, 211)` | Secondary background color, card backgrounds, and face highlights in vector assets. |
| **Charcoal Black** | `#1C1C1E` | `rgb(28, 28, 30)` | Dark mode background color, primary window background, and list containers. |
| **Accent Gold** | `#EAA83A` | `rgb(234, 168, 58)` | Warning states, build caches, and special highlighted tags. |

### 2.2 System Colors (Standardized)

- **Success Green:** `#34C759` (active containers, connected USB devices).
- **Destructive Red:** `#FF453A` (stopped containers, stopped hypervisor, delete actions).
- **Secondary Gray:** `#8E8E93` (subtitles, secondary borders, inactive text).

---

## 3. Typography Rules

ShibaStack interfaces leverage macOS native system fonts (San Francisco) to maintain a clean "Apple-esque" aesthetic:
- **Titles:** Bold, San Francisco Pro Display, tracking set to tight.
- **Body Text:** San Francisco Pro Text, regular weight, high contrast.
- **Code & Logs:** San Francisco Mono (or standard system monospaced), colored in Success Green `#34C759` or White `#FFFFFF` against a solid dark Charcoal background.

---

## 4. Native Application Icon Design

The ShibaStack application icon is constructed programmatically as a minimalist geometric vector. It utilizes:
1. **Background:** A rounded rectangular dark Charcoal tile.
2. **Ears:** Sharp triangles in Shiba Orange `#E06D3A` with Shiba Cream `#F7EAD3` inner lining.
3. **Cheeks and Muzzle:** Symmetric polygons in Shiba Cream `#F7EAD3`.
4. **Eyes and Nose:** Minimalist dark circles and a soft central triangle.

This geometric layout compiles into a native `.icns` file embedded directly inside the application bundle resources.
