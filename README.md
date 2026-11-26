<div align="center">

# ⚔️ CombatTextPlus

**Fully customizable scrolling combat text for World of Warcraft.**

Take control of how damage and healing appear on your screen. Subtle and clean, or flashy and dynamic, CombatTextPlus lets you build it your way.

Works on **Retail (Midnight)** and **WoW: Forever**.

</div>

***

## 📖 Table of Contents

* [Features](#-features)
* [Installation](#-installation)
* [Configuration Guide](#%EF%B8%8F-configuration-guide)
* [Slash Commands](#-slash-commands)
* [How It Works](#-how-it-works)
* [Blizzard Combat Text](#-blizzard-combat-text)

***

## ✨ Features

### ⚡ One Click Looks
Change your whole look in one click: font, size, animation, Number Style, and crits.
* **16 Looks:** Clean, Classic, Blizzard Style, Minimal, Big & Bold, Precision, Comic, Arcade, Neon Nights, Glitch, Elemental, Fantasy, Horror, Military, Rainbow, and Arcane.
* **Hover to preview** exactly what each Look changes before you apply it.
* **Your colors, filters, and positions are never touched.**
* **Undo Look** takes you back to the setup you had before you started trying Looks.

### 💥 Number Styles
Give your numbers some personality.
* **Classic** for clean, normal numbers.
* **Neon** for a glowing sign look in your damage colors.
* **Comic** for POW, BAM, and ZAP words that match the damage type.
* **Glitch** for a red and cyan cyberpunk jitter.
* **Elemental** for sparks, embers, and sparkles.
* **Style Crits Only** keeps normal hits clean and saves the effects for crits.

### 🎞️ Animations
18 animation styles, including Fade, Bounce, Pop, Shake, Spiral, Zigzag, Ripple, Flip, Arc (Blizzard style), and Rainbow arches in either direction.
* **Animation Easing** and **Animation Tuning** fine tune the motion.
* **Scroll Duration** controls how long text stays on screen.
* **Speed Factor** makes movement more dynamic or more static.
* **Max Y Offset** sets how far text travels vertically.
* **Start X and Y Offsets** move where numbers begin.
* **Damage Type Offsets** give each damage school its own horizontal motion.

### 🎯 Critical Hits
* **Crit Color** uses the damage school color or a classic red.
* **Crit Size** makes crits as big as you want.
* **Crit Animation** gives crits their own animation.
* **Add "Crit" to Label** shows labels like "Fire Crit".

### 🖥️ Where Numbers Show
* **Nameplates, center screen, or both.**
* **Finish Numbers When Nameplate Disappears** keeps numbers on screen until they finish, even if the enemy dies.
* **Prevent Overlap** and **Line Spacing** keep numbers readable.
* **Max Numbers Per Nameplate** keeps big pulls from flooding your screen.

### 🖼️ Spell Icons
Shows the icon of the spell that dealt the damage, with your choice of position and size.

### 🐾 Pet Tag
Tags your pet's ability hits so you can tell them apart from your own.
* Works for any class with a pet: Hunter, Warlock, Frost Mage, Unholy Death Knight, and more.
* **Tag Text:** Pet, PET, (Pet), [Pet], or your pet's actual name.
* **Tag Position, Size, and Color** are all adjustable.
* **Pet Number Color** gives pet hits their own number color, separate from the tag.

### 🛡️ Misses and Avoidance
* **Show Misses on Enemies** shows when your attacks miss, are dodged, parried, and more.
* **Show My Avoidance** shows when you dodge, parry, or block, with its own position, size, and color.

### 💚 Healing
Show healing numbers on yourself, your group, or friendly NPCs.

### 🎨 Colors
* **Damage Type Colors** for Physical, Holy, Fire, and every other school.
* **Label Colors** for the labels next to each number.
* **Use Default Colors** restores a clean, readable color preset in one click.

### 🔤 Fonts
* **18 bundled fonts** plus any fonts from LibSharedMedia.
* **Font Size**, **Label Font Size**, and **Damage Type Font Sizes** for full control.

### 🔍 Damage Type Filters
Show or hide any damage type. Only care about Fire? Turn everything else off.

### 🌙 Midnight Ready
Built for Blizzard's Midnight addon rules.
* **Only Enemies I'm Fighting** hides damage on enemies you never attacked.
* **Strict: Only Enemies I Targeted** for the cleanest numbers in groups.
* **PvP: Current Target Only** keeps battlegrounds readable.
* **Restricted Number Color** for hits where Blizzard hides the damage school.

### 💾 Profiles
Save and swap between configurations for different characters, specs, or content.

### 🧭 Minimap Button
Quick access to settings, with the option to hide it.

***

## 📦 Installation

1. Download the latest release.
2. Extract the `CombatTextPlus` folder into your game's AddOns folder, for example:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. Restart WoW or type `/reload` in game.

***

## ⚙️ Configuration Guide

Open the settings at **Interface > AddOns > CombatTextPlus**, click the minimap button, or type `/ctp`.

<table>
<tr><th>What you want to change</th><th>Where to find it</th></tr>
<tr><td>Whole look in one click</td><td><b>One Click Looks</b></td></tr>
<tr><td>Fancy number effects</td><td><b>Number Style</b></td></tr>
<tr><td>How text moves</td><td><b>Animation Style</b>, <b>Animation Easing</b>, and <b>Animation Tuning</b></td></tr>
<tr><td>How fast text scrolls</td><td><b>Scroll Duration</b> and <b>Speed Factor</b></td></tr>
<tr><td>Where text starts and how high it goes</td><td><b>Start X Offset</b>, <b>Start Y Offset</b>, and <b>Max Y Offset</b></td></tr>
<tr><td>Nameplates or center screen</td><td><b>Show Numbers On</b></td></tr>
<tr><td>Crit look</td><td><b>Crits</b></td></tr>
<tr><td>Spell icons</td><td><b>Show Spell Icons</b>, <b>Icon Position</b>, and <b>Icon Size</b></td></tr>
<tr><td>Pet hits</td><td><b>Pet Tag</b></td></tr>
<tr><td>Misses, dodges, and parries</td><td><b>Misses &amp; Avoidance</b></td></tr>
<tr><td>Colors</td><td><b>Damage Type Colors</b> and <b>Label Colors</b></td></tr>
<tr><td>Fonts and sizes</td><td><b>Font</b>, <b>Font Size</b>, and <b>Label Font Size</b></td></tr>
<tr><td>Which damage types appear</td><td><b>Damage Type Filters</b></td></tr>
<tr><td>Whose damage shows</td><td><b>Midnight Settings</b></td></tr>
<tr><td>Saved setups</td><td><b>Profiles</b></td></tr>
</table>

***

## 💬 Slash Commands

| Command | What it does |
| --- | --- |
| `/ctp` | Open the settings |
| `/ctp preview` | Play sample combat text |
| `/ctp look <name>` | Apply a One Click Look |
| `/ctp look undo` | Go back to your setup from before you tried Looks |
| `/ctp colors` | Restore the default color preset |
| `/ctp status` | Quick check of what the addon sees |
| `/ctp debug` | Print combat events on your target to chat |
| `/ctp debug all` | Print combat events on every nameplate |

***

## 🛠️ How It Works

Blizzard no longer lets addons read the combat log. CombatTextPlus reads the combat events Blizzard sends for each nameplate and draws them on screen using your settings.

Those events don't say who dealt the damage. So CombatTextPlus works out which enemies you are fighting: ones you targeted and attacked, ones with your damage over time effects on them, and ones your AoE just hit. On an enemy you are fighting, like a boss, other players' hits can still appear.

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

</div>
