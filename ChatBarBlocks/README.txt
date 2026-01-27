# ChatBarBlocks

**ChatBarBlocks** is a minimalistic addon for **World of Warcraft: TBC Classic ** that adds thin, colored blocks for quickly switching chat channels with a mouse click.

Inspired by classic ChatBar, but redesigned to be compact, clean, and unobtrusive.

---

## ✨ Features

- 🎨 Colored blocks for chat channels (SAY, PARTY, RAID, GUILD, OFFICER, WHISPER)
- 🖱 Click a block to instantly activate the corresponding chat input
- 🔔 **Flashing blocks** when new messages arrive in:
  - PARTY  
  - RAID  
  - GUILD  
  - WHISPER  
- ⚙️ Full settings menu in **Game Menu → Options → AddOns**
- 📏 Customizable:
  - block width
  - block height
  - spacing between blocks
  - transparency
  - scale
- 🔒 Lock / unlock panel dragging
- 💾 Settings are saved between UI reloads
- ❌ Global channels (Trade, General, etc.) **do not flash** — only important social channels

---

## 🧩 Compatibility

- World of Warcraft **TBC Classic**
- Client version: **2.5.5**
- Retail  — **not tested yet**

---

## 📦 Installation

### Option 1 — GitHub
1. Download the repository as ZIP
2. Extract the `ChatBarBlocks` folder
3. Place it into: World of Warcraft/anniversary/Interface/AddOns/
4. Restart the game or run `/reload`

### Option 2 — Git
git clone https://github.com/Enciosafe/ChatBarBlocks.git

---

## ⚙️ Configuration

Open:

Game Menu → Options → AddOns → ChatBarBlocks

Available options:

Lock / unlock dragging

Enable / disable tooltips

Block dimensions

Transparency

Scale

Reset to defaults

⌨️ Slash Commands

/cbb unlock      — unlock and move the bar
/cbb lock        — lock the bar position
/cbb reset       — reset all settings
/cbb tooltip     — toggle tooltips
/cbb set ...     — manually define channel list


Example:
/cbb set SAY PARTY RAID GUILD OFFICER WHISPER


🔔 Channel Flashing

A block will start flashing when a new message is received in:

PARTY

RAID

GUILD

WHISPER

Flashing stops when you click the block.

🎨 Icon

The addon includes a custom icon (icon.tga) that is correctly displayed in the addon list.

🧑‍💻 Author

Ogiz
GitHub: https://github.com/Enciosafe

📄 License

MIT
If you have ideas, bug reports, or feature requests — feel free to open an Issue 🙂

## 📌 Screenshot

![ChatBarBlocks in-game](sh1.jpg)




