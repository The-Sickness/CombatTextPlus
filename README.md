<div align="center">

# ⚔️ CombatTextPlus

**Fully customizable scrolling combat text for World of Warcraft.**

Take control of how damage and healing appear on your screen. Subtle and clean, or flashy and dynamic, CombatTextPlus lets you build it your way.

</div>

***

## 📖 Table of Contents

* [Features](#-features)
* [Installation](#-installation)
* [Configuration Guide](#%EF%B8%8F-configuration-guide)
* [How It Works](#-how-it-works)
* [Blizzard Combat Text](#-blizzard-combat-text)

***

## ✨ Features

### 🎞️ Text Movement
* **Scroll Duration** controls how long text stays on screen as it scrolls.
* **Speed Factor** makes text movement more dynamic or more static.
* **Max Y Offset** sets how far text travels vertically so it never drifts off screen.
* **Damage Type Offsets** give each damage school its own horizontal motion, such as zigzag or spiral patterns.

### 🎨 Colors
* **Damage Type Colors** assign a unique color to Physical, Holy, Fire, and every other school.
* **Label Colors** style the labels shown next to each damage type.

### 🔤 Fonts
* **Font Selection** lets you pick from a variety of fonts.
* **Font Size** makes your numbers as bold or as subtle as you like.

### 🔍 Damage Type Filters
Show or hide any damage type. Only care about Fire? Turn everything else off.

### 🔥 DOT Behavior
* **DOT Y Offset Multiplier** gives Damage Over Time ticks their own vertical movement so they stand out from direct hits.

### 💾 Profiles
Save and swap between configurations for different characters, specs, or content.

### 🧭 Minimap Button
Quick access to settings, with the option to hide it.

***

## 📦 Installation

1. Download the latest release.
2. Extract the `CombatTextPlus` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Restart WoW or type `/reload` in game.

***

## ⚙️ Configuration Guide

Open the settings at **Interface > AddOns > CombatTextPlus** or click the minimap button.

<table>
<tr><th>What you want to change</th><th>Where to find it</th></tr>
<tr><td>How fast text scrolls</td><td><b>Scroll Duration</b> and <b>Speed Factor</b> sliders</td></tr>
<tr><td>How high text travels</td><td><b>Max Y Offset</b> slider</td></tr>
<tr><td>Movement pattern per damage school</td><td><b>Damage Type Offsets</b></td></tr>
<tr><td>Damage colors</td><td><b>Damage Type Colors</b></td></tr>
<tr><td>Label colors</td><td><b>Label Colors</b></td></tr>
<tr><td>Font style</td><td><b>Font</b> dropdown</td></tr>
<tr><td>Text size</td><td><b>Font Size</b> slider</td></tr>
<tr><td>Which damage types appear</td><td><b>Damage Type Filters</b></td></tr>
<tr><td>DOT vertical movement</td><td><b>DOT Y Offset Multiplier</b></td></tr>
<tr><td>Saved setups</td><td><b>Profiles</b></td></tr>
</table>

***

## 🛠️ How It Works

CombatTextPlus listens to the WoW combat log for damage, healing, and other combat events. When a relevant event fires, the addon draws it on screen using your settings.

Movement is driven by a few core values:

* `scrollDuration` sets how long the text lives before fading out.
* `speedFactor` sets how fast it moves.
* `maxYOffset` caps how far it travels vertically.
* `damageTypeOffsets` controls horizontal motion for each damage school.

***

## 🔁 Blizzard Combat Text

CombatTextPlus automatically turns off Blizzard's default scrolling combat text so the two don't overlap.

Want Blizzard's text back? Type this in chat:

```
/console floatingCombatTextCombatDamage 1
```

***

<div align="center">

**Casual player or hardcore raider, make your combat text truly your own.**

If you enjoy CombatTextPlus, consider leaving a ⭐ on the repo!

</div>
