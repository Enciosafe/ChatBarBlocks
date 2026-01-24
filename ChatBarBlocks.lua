
--ver 1.1.0

-- Created by Ogiz aka Enciosafe
-- ChatBarBlocks (TBC Classic 2.5.5)
-- Colored blocks: click to open chat in selected channel.
-- Blink PARTY/RAID/GUILD/WHISPER when new messages arrive (not for global channels).
-- Optional ROLL button (/roll 100).
-- Minimap icon via LibDataBroker + LibDBIcon (standard minimap button look like other addons).

local ADDON_NAME = ...
ChatBarBlocksDB = ChatBarBlocksDB or {}

-- =========================
-- Defaults / DB / Helpers
-- =========================
local DEFAULTS = {
  point = "BOTTOMLEFT",
  relativePoint = "BOTTOMLEFT",
  x = 20,
  y = 220,
  scale = 1,
  alpha = 1,
  locked = false,
  showTooltips = true,

  items = { "SAY", "PARTY", "RAID", "GUILD", "OFFICER", "WHISPER" },

  w = 60,
  h = 6,
  gap = 4,

  layout = {
    mode = "HORIZONTAL",      -- HORIZONTAL / VERTICAL
    direction = "TOP_DOWN",   -- TOP_DOWN / BOTTOM_UP (only for VERTICAL)
  },

  flash = {
    stopOnHover = true,
    basePeriod = 0.50, -- 1 message
    midPeriod  = 0.30, -- 2-3 messages
    fastPeriod = 0.18, -- 4+ messages
    midAfter   = 2,
    fastAfter  = 4,
  },

  roll = {
    enabled = true,
  },

  -- (LibDBIcon)
  minimapIcon = {
    hide = false,
    minimapPos = 225,   -- degrees around minimap 
    radius = 80,        -- ring radius 
  },

  -- legacy (kept only for migration)
  minimap = {
    enabled = true,
    angle = 225,
    ringOffset = 10,
  },
}

local function CopyDefaults(src, dst)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function DB()
  if type(ChatBarBlocksDB) ~= "table" then
    ChatBarBlocksDB = {}
  end
  CopyDefaults(DEFAULTS, ChatBarBlocksDB)
  return ChatBarBlocksDB
end

local function Print(msg)
  local cf = DEFAULT_CHAT_FRAME or ChatFrame1
  if cf then cf:AddMessage("|cff66ccffChatBarBlocks:|r " .. msg) end
end

local function Tooltip(owner, text, r, g, b)
  if not DB().showTooltips then return end
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  if r and g and b then
    GameTooltip:SetText(text, r, g, b, true)
  else
    GameTooltip:SetText(text, 1, 1, 1, true)
  end
  GameTooltip:Show()
end

local function ChatTypeColor(chatType)
  local info = ChatTypeInfo and ChatTypeInfo[chatType]
  if info then return info.r, info.g, info.b end
  return 1, 1, 1
end

local function ChannelColorByNumber(n)
  local key = "CHANNEL" .. tostring(n)
  local info = ChatTypeInfo and ChatTypeInfo[key]
  if info then return info.r, info.g, info.b end
  return 0.7, 0.7, 0.7
end

local function IsChatType(s)
  return ChatTypeInfo and ChatTypeInfo[s] ~= nil
end

local function ActivateChat(chatType, target)
  local frame = DEFAULT_CHAT_FRAME or ChatFrame1

  if chatType == "CHANNEL" then
    local n = tonumber(target)
    if not n or n <= 0 then return end

    ChatFrame_OpenChat("", frame)
    local eb = (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or ChatFrame1EditBox or ChatFrameEditBox
    if not eb then return end

    local cmd = "/" .. tostring(n) .. " "
    eb:SetText(cmd)
    eb:SetCursorPosition(#cmd)

    local otc = eb:GetScript("OnTextChanged")
    if otc then otc(eb, true) end

    ChatEdit_UpdateHeader(eb)
    ChatEdit_ActivateChat(eb)
    return
  end

  local prefix = ""
  if chatType == "SAY" then prefix = "/s "
  elseif chatType == "YELL" then prefix = "/y "
  elseif chatType == "PARTY" then prefix = "/p "
  elseif chatType == "RAID" then prefix = "/raid "
  elseif chatType == "GUILD" then prefix = "/g "
  elseif chatType == "OFFICER" then prefix = "/o "
  elseif chatType == "WHISPER" then prefix = "/w " .. (target or "") .. " "
  end

  ChatFrame_OpenChat(prefix, frame)
end

-- =========================
-- UI state
-- =========================
local UI = {
  buttons = {},
  typeButtons = {},
  flashing = {},

  selectedChatType = "SAY",
  selectedTarget = nil,

  bar = nil,
  configFrame = nil,
}

-- Forward declarations
local RestorePos, Build, UpdateLockVisual
local ApplyAndRebuild
local OpenConfig

-- =========================
-- LibDataBroker / LibDBIcon 
-- =========================
local LDB, LDBIcon, brokerObj
local function Libs_Init()
  if brokerObj then return end

  local stub = LibStub
  if not stub then return end

  local ok1, lib1 = pcall(stub.GetLibrary, stub, "LibDataBroker-1.1", true)
  local ok2, lib2 = pcall(stub.GetLibrary, stub, "LibDBIcon-1.0", true)
  LDB = ok1 and lib1 or nil
  LDBIcon = ok2 and lib2 or nil
  if not (LDB and LDBIcon) then return end

  brokerObj = LDB:NewDataObject("ChatBarBlocks", {
    type = "data source",
    text = "ChatBarBlocks",
    icon = "Interface\\AddOns\\ChatBarBlocks\\icon.tga",

    OnClick = function(_, button)
      if button == "LeftButton" then
        OpenConfig()
      elseif button == "RightButton" then
        local db = DB()
        db.locked = not db.locked
        UpdateLockVisual()
        Print("Locked: " .. (db.locked and "ON" or "OFF"))
      end
    end,

    OnTooltipShow = function(tooltip)
      tooltip:AddLine("ChatBarBlocks |cffaaaaaaver 1.1.0|r")
      tooltip:AddLine(" ")
      tooltip:AddLine("|cffffffffLeft click:|r Options")
      tooltip:AddLine("|cffffffffRight click:|r Lock/Unlock bar")
    end,
  })

  local db = DB()
  db.minimapIcon = db.minimapIcon or {}

  -- Register 
  LDBIcon:Register("ChatBarBlocks", brokerObj, db.minimapIcon)

  -- Optional
  if db.minimapIcon.radius and LDBIcon.SetRadius then
    pcall(LDBIcon.SetRadius, LDBIcon, "ChatBarBlocks", db.minimapIcon.radius)
  end
end

local function MinimapIcon_Show()
  if not (LDBIcon and brokerObj) then return end
  local db = DB()
  db.minimapIcon.hide = false
  LDBIcon:Show("ChatBarBlocks")
end

local function MinimapIcon_Hide()
  if not (LDBIcon and brokerObj) then return end
  local db = DB()
  db.minimapIcon.hide = true
  LDBIcon:Hide("ChatBarBlocks")
end

local function MinimapIcon_Apply()
  if not (LDBIcon and brokerObj) then return end
  local db = DB()
  if db.minimapIcon.hide then
    LDBIcon:Hide("ChatBarBlocks")
  else
    LDBIcon:Show("ChatBarBlocks")
  end

  
  if db.minimapIcon.radius and LDBIcon.SetRadius then
    pcall(LDBIcon.SetRadius, LDBIcon, "ChatBarBlocks", db.minimapIcon.radius)
  end
end


local function MigrateMinimapSettings()
  local db = DB()
  if db._minimapMigrated then return end

  -- if user already has minimapIcon settings -> do nothing
  if db.minimapIcon and (db.minimapIcon.minimapPos ~= nil or db.minimapIcon.hide ~= nil) then
    db._minimapMigrated = true
    return
  end

  db.minimapIcon = db.minimapIcon or {}

  -- legacy mapping:
  if db.minimap then
    -- enabled -> hide
    if db.minimap.enabled == false then
      db.minimapIcon.hide = true
    end
    -- angle -> minimapPos
    if type(db.minimap.angle) == "number" then
      db.minimapIcon.minimapPos = db.minimap.angle
    end
    -- ringOffset -> radius approx (80 + offset)
    if type(db.minimap.ringOffset) == "number" then
      db.minimapIcon.radius = 80 + db.minimap.ringOffset
    end
  end

  -- sane defaults if still empty
  if db.minimapIcon.hide == nil then db.minimapIcon.hide = false end
  if type(db.minimapIcon.minimapPos) ~= "number" then db.minimapIcon.minimapPos = 225 end
  if type(db.minimapIcon.radius) ~= "number" then db.minimapIcon.radius = 80 end

  db._minimapMigrated = true
end

-- =========================
-- Config window (clean layout)
-- =========================
local function CreateConfigFrame()
  if UI.configFrame then return UI.configFrame end

  local f = CreateFrame("Frame", "ChatBarBlocksConfigFrame", UIParent, "BackdropTemplate")
  UI.configFrame = f

  f:SetSize(380, 630)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")

  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ChatBarBlocks")

  local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetWidth(340)
  sub:SetJustifyH("LEFT")
  sub:SetText("Thin colored bars to pick chat channels with a mouse click.")

  local author = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  author:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -6)
  author:SetWidth(340)
  author:SetJustifyH("LEFT")
  author:SetText("VER. 1.1.0    Created by Ogiz from Ukraine")


  local function MakeCheck(label, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, y)
    c.Text:SetText(label)
    c:SetScript("OnClick", function(self)
      set(self:GetChecked() and true or false)
      ApplyAndRebuild()
    end)
    c.Refresh = function()
      c:SetChecked(get() and true or false)
    end
    return c
  end

  local sliderCount = 0
  local function MakeSlider(label, x, y, minV, maxV, step, get, set, fmt)
    sliderCount = sliderCount + 1
    local name = "ChatBarBlocksCfgSlider" .. sliderCount

    local s = CreateFrame("Slider", name, f, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(260)

    local tText = _G[name .. "Text"]
    local tLow  = _G[name .. "Low"]
    local tHigh = _G[name .. "High"]

    tText:SetText(label)
    tText:ClearAllPoints()
    tText:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 6)
    tText:SetJustifyH("LEFT")
    tText:SetWidth(320)

    tLow:Hide()
    tHigh:Hide()

    local valText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:ClearAllPoints()
    valText:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", 0, 6)
    valText:SetJustifyH("RIGHT")
    valText:SetWidth(80)

    local function UpdateValueText(v)
      if fmt then valText:SetText(string.format(fmt, v)) else valText:SetText(tostring(v)) end
    end

    s:SetScript("OnValueChanged", function(self, value)
      value = tonumber(value) or 0
      set(value)
      UpdateValueText(value)
      ApplyAndRebuild()
    end)

    s.Refresh = function()
      local v = get()
      s:SetValue(v)
      UpdateValueText(v)
    end

    return s
  end

  local y = -72
  local chkLocked = MakeCheck("Locked (disable dragging)", 16, y,
    function() return DB().locked end,
    function(v) DB().locked = v end
  )

  y = y - 26
  local chkTooltips = MakeCheck("Show tooltips on hover", 16, y,
    function() return DB().showTooltips end,
    function(v) DB().showTooltips = v end
  )

  y = y - 26
  local chkHoverStop = MakeCheck("Stop flashing on hover", 16, y,
    function() return (DB().flash and DB().flash.stopOnHover) end,
    function(v)
      DB().flash = DB().flash or {}
      DB().flash.stopOnHover = v
    end
  )

  y = y - 26
  local chkRoll = MakeCheck("Show ROLL button (/roll 100)", 16, y,
    function() return (DB().roll and DB().roll.enabled) end,
    function(v)
      DB().roll = DB().roll or {}
      DB().roll.enabled = v
    end
  )

  y = y - 26
  local chkMini = MakeCheck("Show minimap options button", 16, y,
    function()
      DB().minimapIcon = DB().minimapIcon or {}
      return not DB().minimapIcon.hide
    end,
    function(v)
      DB().minimapIcon = DB().minimapIcon or {}
      DB().minimapIcon.hide = not v
      if v then MinimapIcon_Show() else MinimapIcon_Hide() end
    end
  )

  y = y - 52
  local sRadius = MakeSlider("Minimap button radius", 16, y, 50, 140, 1,
    function()
      DB().minimapIcon = DB().minimapIcon or {}
      return DB().minimapIcon.radius or 80
    end,
    function(v)
      DB().minimapIcon = DB().minimapIcon or {}
      DB().minimapIcon.radius = math.floor(v + 0.5)
    end,
    "%.0f"
  )

  y = y - 56
  local btnH = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnH:SetSize(120, 22)
  btnH:SetPoint("TOPLEFT", 16, y)
  btnH:SetText("Horizontal")
  btnH:SetScript("OnClick", function()
    DB().layout = DB().layout or {}
    DB().layout.mode = "HORIZONTAL"
    ApplyAndRebuild()
  end)

  local btnV = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnV:SetSize(120, 22)
  btnV:SetPoint("LEFT", btnH, "RIGHT", 10, 0)
  btnV:SetText("Vertical")
  btnV:SetScript("OnClick", function()
    DB().layout = DB().layout or {}
    DB().layout.mode = "VERTICAL"
    ApplyAndRebuild()
  end)

  y = y - 54
  local sW = MakeSlider("Block width", 16, y, 10, 200, 1,
    function() return DB().w end,
    function(v) DB().w = math.floor(v + 0.5) end,
    "%.0f"
  )

  y = y - 54
  local sH = MakeSlider("Block height", 16, y, 2, 40, 1,
    function() return DB().h end,
    function(v) DB().h = math.floor(v + 0.5) end,
    "%.0f"
  )

  y = y - 54
  local sGap = MakeSlider("Gap", 16, y, 0, 30, 1,
    function() return DB().gap end,
    function(v) DB().gap = math.floor(v + 0.5) end,
    "%.0f"
  )

  y = y - 54
  local sAlpha = MakeSlider("Bar alpha", 16, y, 0.1, 1.0, 0.05,
    function() return DB().alpha end,
    function(v) DB().alpha = v end,
    "%.2f"
  )

  y = y - 54
  local sScale = MakeSlider("Bar scale", 16, y, 0.6, 2.0, 0.05,
    function() return DB().scale end,
    function(v) DB().scale = v end,
    "%.2f"
  )

  local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  reset:SetSize(160, 22)
  reset:SetPoint("BOTTOMLEFT", 16, 16)
  reset:SetText("Reset to defaults")
  reset:SetScript("OnClick", function()
    ChatBarBlocksDB = nil
    DB()
    RestorePos()
    Build()
    UpdateLockVisual()
    Libs_Init()
    MinimapIcon_Apply()
    f.Refresh()
    Print("Reset.")
  end)

  local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  ok:SetSize(100, 22)
  ok:SetPoint("BOTTOMRIGHT", -16, 16)
  ok:SetText("Close")
  ok:SetScript("OnClick", function() f:Hide() end)

  f.Refresh = function()
    chkLocked.Refresh()
    chkTooltips.Refresh()
    chkHoverStop.Refresh()
    chkRoll.Refresh()
    chkMini.Refresh()
    sRadius.Refresh()

    sW.Refresh()
    sH.Refresh()
    sGap.Refresh()
    sAlpha.Refresh()
    sScale.Refresh()
  end

  f:SetScript("OnShow", function() f.Refresh() end)
  f:Hide()
  return f
end

OpenConfig = function()
  local cfg = CreateConfigFrame()
  if cfg:IsShown() then
    cfg:Hide()
  else
    cfg:Show()
    cfg:Raise()
  end
end

-- =========================
-- Roll helper
-- =========================
local function GetEditBox()
  return (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or ChatFrame1EditBox or ChatFrameEditBox
end

local function DoRoll100()
  local ct = UI.selectedChatType or "SAY"
  local tgt = UI.selectedTarget

  ActivateChat(ct, tgt)

  local eb = GetEditBox()
  if not eb then return end

  eb:SetText("/roll 100")
  eb:SetCursorPosition(#"/roll 100")
  ChatEdit_SendText(eb, 0)
end

-- =========================
-- Position / Lock visuals
-- =========================
local function SavePos()
  local db = DB()
  local p, _, rp, x, y = UI.bar:GetPoint(1)
  db.point, db.relativePoint, db.x, db.y = p, rp, x, y
end

RestorePos = function()
  local db = DB()
  UI.bar:ClearAllPoints()
  UI.bar:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
  UI.bar:SetScale(db.scale)
  UI.bar:SetAlpha(db.alpha)
end

UpdateLockVisual = function()
  if DB().locked then
    UI.bar:SetBackdropBorderColor(0, 0, 0, 0)
  else
    UI.bar:SetBackdropBorderColor(1, 1, 1, 0.35)
  end
end

-- =========================
-- Flashing logic
-- =========================
local function StopFlash(btn)
  if not btn then return end
  UI.flashing[btn] = nil
  btn._flash = nil
  btn._unread = 0

  if btn.glow then
    btn.glow:SetVertexColor(1, 1, 1, 0)
  end

  if btn._baseColor then
    btn.tex:SetVertexColor(btn._baseColor[1], btn._baseColor[2], btn._baseColor[3], btn._baseColor[4])
  end
end

local function GetFlashPeriod(btn)
  local db = DB()
  local f = db.flash or {}
  local unread = btn._unread or 0

  if unread >= (f.fastAfter or 4) then return (f.fastPeriod or 0.18) end
  if unread >= (f.midAfter  or 2) then return (f.midPeriod  or 0.30) end
  return (f.basePeriod or 0.50)
end

local function StartFlash(btn)
  if not btn then return end

  btn._unread = (btn._unread or 0) + 1
  if UI.flashing[btn] then return end

  UI.flashing[btn] = true
  btn._flash = { t = 0 }

  if not btn._hasUnifiedUpdate then
    btn._hasUnifiedUpdate = true

    btn:SetScript("OnUpdate", function(self, elapsed)
      local needUpdate = false

      if UI.flashing[self] and self._flash then
        needUpdate = true

        local period = GetFlashPeriod(self)
        local f = self._flash
        f.t = (f.t + elapsed) % period

        local x = f.t / period
        local pulse = math.sin(x * math.pi)

        local unread = self._unread or 1
        local boost = math.min(0.35 + unread * 0.06, 0.85)
        local glowA = pulse * boost

        if self.glow then
          local r, g, b = 1, 1, 1
          if self._baseColor then r, g, b = self._baseColor[1], self._baseColor[2], self._baseColor[3] end
          self.glow:SetVertexColor(r, g, b, glowA)
        end

        if self._baseColor then
          local r, g, b, a = self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4]
          local k = 1 + pulse * 0.25
          self.tex:SetVertexColor(math.min(r * k, 1), math.min(g * k, 1), math.min(b * k, 1), a)
        end
      end

      if self._borderAnim and self._borderAnim.active then
        needUpdate = true

        local anim = self._borderAnim
        anim.t = anim.t + elapsed
        local p = anim.t / anim.dur
        if p >= 1 then p = 1 end

        local k = p * p * (3 - 2 * p)

        local r = anim.from[1] + (anim.to[1] - anim.from[1]) * k
        local g = anim.from[2] + (anim.to[2] - anim.from[2]) * k
        local b = anim.from[3] + (anim.to[3] - anim.from[3]) * k
        local a = anim.from[4] + (anim.to[4] - anim.from[4]) * k

        if self._setBorderColor then
          self._setBorderColor(r, g, b, a)
        end

        if p >= 1 then
          anim.active = false
        end
      end

      if not needUpdate then
        self:SetScript("OnUpdate", nil)
        self._hasUnifiedUpdate = false
      end
    end)
  end
end

local function FlashChatType(chatType)
  local btn = UI.typeButtons and UI.typeButtons[chatType]
  if btn then StartFlash(btn) end
end

-- =========================
-- Blocks / Layout / Build
-- =========================
local function ClearButtons()
  if UI.buttons then
    for _, b in ipairs(UI.buttons) do
      StopFlash(b)
      b:Hide()
    end
  end
  wipe(UI.buttons)
  wipe(UI.typeButtons)
end

local function MakeBlock(parent, w, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)

  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetAllPoints(true)
  b.tex:SetTexture("Interface\\Buttons\\WHITE8x8")

  b.glow = b:CreateTexture(nil, "OVERLAY")
  b.glow:SetAllPoints(true)
  b.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
  b.glow:SetBlendMode("ADD")
  b.glow:SetVertexColor(1, 1, 1, 0)

  local function MakeEdge()
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    t:SetVertexColor(0, 0, 0, 0.55)
    return t
  end

  b.border = { top = MakeEdge(), bottom = MakeEdge(), left = MakeEdge(), right = MakeEdge() }

  local bw = 1
  b.border.top:SetPoint("TOPLEFT", 0, 0);       b.border.top:SetPoint("TOPRIGHT", 0, 0);       b.border.top:SetHeight(bw)
  b.border.bottom:SetPoint("BOTTOMLEFT", 0, 0); b.border.bottom:SetPoint("BOTTOMRIGHT", 0, 0); b.border.bottom:SetHeight(bw)
  b.border.left:SetPoint("TOPLEFT", 0, 0);      b.border.left:SetPoint("BOTTOMLEFT", 0, 0);    b.border.left:SetWidth(bw)
  b.border.right:SetPoint("TOPRIGHT", 0, 0);    b.border.right:SetPoint("BOTTOMRIGHT", 0, 0);  b.border.right:SetWidth(bw)

  local function SetBorderColor(r, g, bl, a)
    b.border.top:SetVertexColor(r, g, bl, a)
    b.border.bottom:SetVertexColor(r, g, bl, a)
    b.border.left:SetVertexColor(r, g, bl, a)
    b.border.right:SetVertexColor(r, g, bl, a)
  end
  b._setBorderColor = SetBorderColor

  b._borderAnim = { t = 0, dur = 0.15, from = {0, 0, 0, 0.55}, to = {0, 0, 0, 0.55}, active = false }

  local function AnimateBorder(toR, toG, toB, toA)
    local anim = b._borderAnim
    anim.t = 0
    anim.active = true

    local r, g, bl, a = b.border.top:GetVertexColor()
    anim.from[1], anim.from[2], anim.from[3], anim.from[4] = r, g, bl, a
    anim.to[1], anim.to[2], anim.to[3], anim.to[4] = toR, toG, toB, toA

    if not b._hasUnifiedUpdate then
      b._hasUnifiedUpdate = true
      b:SetScript("OnUpdate", function(self, elapsed)
        local needUpdate = false

        if UI.flashing[self] and self._flash then
          needUpdate = true

          local period = GetFlashPeriod(self)
          local f = self._flash
          f.t = (f.t + elapsed) % period

          local x = f.t / period
          local pulse = math.sin(x * math.pi)

          local unread = self._unread or 1
          local boost = math.min(0.35 + unread * 0.06, 0.85)
          local glowA = pulse * boost

          if self.glow then
            local rr, gg, bb = 1, 1, 1
            if self._baseColor then rr, gg, bb = self._baseColor[1], self._baseColor[2], self._baseColor[3] end
            self.glow:SetVertexColor(rr, gg, bb, glowA)
          end

          if self._baseColor then
            local rr, gg, bb, aa = self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4]
            local kk = 1 + pulse * 0.25
            self.tex:SetVertexColor(math.min(rr * kk, 1), math.min(gg * kk, 1), math.min(bb * kk, 1), aa)
          end
        end

        if self._borderAnim and self._borderAnim.active then
          needUpdate = true
          local anim2 = self._borderAnim
          anim2.t = anim2.t + elapsed
          local p = anim2.t / anim2.dur
          if p >= 1 then p = 1 end
          local kk = p * p * (3 - 2 * p)

          local rr = anim2.from[1] + (anim2.to[1] - anim2.from[1]) * kk
          local gg = anim2.from[2] + (anim2.to[2] - anim2.from[2]) * kk
          local bb = anim2.from[3] + (anim2.to[3] - anim2.from[3]) * kk
          local aa = anim2.from[4] + (anim2.to[4] - anim2.from[4]) * kk

          if self._setBorderColor then self._setBorderColor(rr, gg, bb, aa) end
          if p >= 1 then anim2.active = false end
        end

        if not needUpdate then
          self:SetScript("OnUpdate", nil)
          self._hasUnifiedUpdate = false
        end
      end)
    end
  end

  SetBorderColor(0, 0, 0, 0.55)

  b:SetScript("OnEnter", function(self)
    if self._tooltipText then
      local r, g, bl = 1, 1, 1
      if self._baseColor then r, g, bl = self._baseColor[1], self._baseColor[2], self._baseColor[3] end
      Tooltip(self, self._tooltipText, r, g, bl)
    end

    local db = DB()
    if db.flash and db.flash.stopOnHover and UI.flashing[self] then
      StopFlash(self)
      return
    end

    if self._baseColor then
      AnimateBorder(self._baseColor[1], self._baseColor[2], self._baseColor[3], 0.95)
    end

    local r, g, bl, a = self.tex:GetVertexColor()
    self.tex:SetVertexColor(r, g, bl, math.min(a + 0.15, 1))
  end)

  b:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if self._baseColor then
      self.tex:SetVertexColor(self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4])
    end
    AnimateBorder(0, 0, 0, 0.55)
  end)

  b._animateBorder = AnimateBorder
  return b
end

local function Layout()
  local db = DB()
  local pad = 4

  local mode = (db.layout and db.layout.mode) or "HORIZONTAL"
  local dir  = (db.layout and db.layout.direction) or "TOP_DOWN"

  if mode == "VERTICAL" then
    local y = -pad
    local x = pad

    for _, b in ipairs(UI.buttons) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", UI.bar, "TOPLEFT", x, y)

      if dir == "BOTTOM_UP" then
        y = y + (db.h + db.gap)
      else
        y = y - (db.h + db.gap)
      end
    end

    UI.bar:SetWidth(db.w + pad * 2)
    UI.bar:SetHeight((#UI.buttons * (db.h + db.gap)) - db.gap + pad * 2)
  else
    local x = pad

    for _, b in ipairs(UI.buttons) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", UI.bar, "TOPLEFT", x, -pad)
      x = x + db.w + db.gap
    end

    UI.bar:SetWidth(x + pad - db.gap)
    UI.bar:SetHeight(db.h + pad * 2)
  end
end

Build = function()
  local db = DB()
  ClearButtons()

  for _, item in ipairs(db.items) do
    local upper = string.upper(tostring(item))
    if IsChatType(upper) then
      local b = MakeBlock(UI.bar, db.w, db.h)

      local r, g, bl = ChatTypeColor(upper)
      b.tex:SetVertexColor(r, g, bl, 0.95)
      b._baseColor = { r, g, bl, 0.95 }
      b._tooltipText = upper
      b._chatType = upper

      UI.typeButtons[upper] = b

      b:SetScript("OnClick", function()
        UI.selectedChatType = upper
        UI.selectedTarget = nil
        StopFlash(b)
        ActivateChat(upper)
      end)

      table.insert(UI.buttons, b)
    end
  end

  local raw = { GetChannelList() }
  for i = 1, #raw, 3 do
    local id = raw[i]
    local name = raw[i + 1]
    local disabled = raw[i + 2]

    if type(id) == "number" and id > 0 and type(name) == "string" and name ~= "" then
      local isDisabled = (disabled == 1 or disabled == true)

      local canSend = not isDisabled
      if canSend and CanSendChatMessage then
        canSend = CanSendChatMessage("CHANNEL", nil, id)
      end

      if canSend then
        local b = MakeBlock(UI.bar, db.w, db.h)

        local r, g, bl = ChannelColorByNumber(id)
        b.tex:SetVertexColor(r, g, bl, 0.95)
        b._baseColor = { r, g, bl, 0.95 }
        b._tooltipText = ("CHANNEL %d: %s"):format(id, name)

        b:SetScript("OnClick", function()
          UI.selectedChatType = "CHANNEL"
          UI.selectedTarget = id
          ActivateChat("CHANNEL", id)
        end)

        table.insert(UI.buttons, b)
      end
    end
  end

  if db.roll and db.roll.enabled then
    local b = MakeBlock(UI.bar, db.w, db.h)
    b.tex:SetVertexColor(1, 1, 1, 0.18)
    b._baseColor = { 1, 1, 1, 0.18 }

    local function RollTooltip()
      local ct = UI.selectedChatType or "SAY"
      if ct == "CHANNEL" and UI.selectedTarget then
        return ("ROLL 100 → CHANNEL %d"):format(UI.selectedTarget)
      else
        return ("ROLL 100 → %s"):format(ct)
      end
    end

    b._tooltipText = RollTooltip()

    b:SetScript("OnEnter", function(self)
      self._tooltipText = RollTooltip()
      Tooltip(self, self._tooltipText, 1, 1, 1)
      if self._animateBorder then self._animateBorder(1, 1, 1, 0.75) end
      local r, g, bl, a = self.tex:GetVertexColor()
      self.tex:SetVertexColor(r, g, bl, math.min(a + 0.15, 1))
    end)

    b:SetScript("OnLeave", function(self)
      GameTooltip:Hide()
      if self._baseColor then
        self.tex:SetVertexColor(self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4])
      end
      if self._animateBorder then self._animateBorder(0, 0, 0, 0.55) end
    end)

    b:SetScript("OnClick", function()
      DoRoll100()
    end)

    table.insert(UI.buttons, b)
  end

  Layout()
end

-- =========================
-- Apply
-- =========================
ApplyAndRebuild = function()
  if UI and UI.bar then
    RestorePos()
    Build()
    UpdateLockVisual()
  end
  if UI.configFrame and UI.configFrame:IsShown() and UI.configFrame.Refresh then
    UI.configFrame.Refresh()
  end
  MinimapIcon_Apply()
end

-- =========================
-- Slash
-- =========================
SLASH_CHATBARBLOCKS1 = "/cbb"
SlashCmdList["CHATBARBLOCKS"] = function(msg)
  msg = msg or ""
  local cmd = msg:match("^(%S+)")
  cmd = cmd and cmd:lower() or ""

  local db = DB()

  if cmd == "unlock" then
    db.locked = false
    UpdateLockVisual()
    Print("Unlocked (drag with left mouse).")
  elseif cmd == "lock" then
    db.locked = true
    UpdateLockVisual()
    Print("Locked.")
  elseif cmd == "reset" then
    ChatBarBlocksDB = nil
    DB()
    RestorePos()
    Build()
    UpdateLockVisual()
    Libs_Init()
    MinimapIcon_Apply()
    Print("Reset.")
  elseif cmd == "tooltip" then
    db.showTooltips = not db.showTooltips
    Print("Tooltips: " .. (db.showTooltips and "ON" or "OFF"))
  elseif cmd == "options" then
    OpenConfig()
  else
    Print("Commands:")
    Print("/cbb unlock | lock | reset | tooltip | options")
  end
end

-- =========================
-- Main bar frame
-- =========================
local f = CreateFrame("Frame", "ChatBarBlocksFrame", UIParent, "BackdropTemplate")
UI.bar = f

f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
f:SetBackdropColor(0, 0, 0, 0.25)

f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetMovable(true)
f:SetClampedToScreen(true)

f:SetScript("OnDragStart", function(self)
  if DB().locked then return end
  self:StartMoving()
end)

f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SavePos()
end)

-- =========================
-- Events
-- =========================
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHANNEL_UI_UPDATE")
f:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")

f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_PARTY_LEADER")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_RAID_LEADER")
f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("CHAT_MSG_OFFICER")
f:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT")

f:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "ChatBarBlocks" then
    DB()
    MigrateMinimapSettings()
    Libs_Init()

    RestorePos()
    Build()
    UpdateLockVisual()

    CreateConfigFrame()
    MinimapIcon_Apply()

    Print("Loaded. Use /cbb options or minimap icon.")
    return
  end

  if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
    FlashChatType("PARTY"); return
  elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
    FlashChatType("RAID"); return
  elseif event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
    FlashChatType("GUILD"); return
  elseif event == "CHAT_MSG_OFFICER" then
    FlashChatType("OFFICER"); return
  elseif event == "CHAT_MSG_WHISPER" then
    FlashChatType("WHISPER"); return
  end

  if event == "PLAYER_ENTERING_WORLD"
    or event == "CHANNEL_UI_UPDATE"
    or event == "CHAT_MSG_CHANNEL_NOTICE" then
    Build()
  end
end)
