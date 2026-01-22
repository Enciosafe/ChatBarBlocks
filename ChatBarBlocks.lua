-- ChatBarBlocks (TBC Classic 2.5.5)
-- Colored blocks: click to open chat in selected channel.
-- Blink PARTY/RAID/GUILD/WHISPER when new messages arrive (not for global channels).

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

local function Tooltip(owner, text)
  if not DB().showTooltips then return end
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:SetText(text, 1, 1, 1, true)
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

-- =========================
-- UI state
-- =========================
local UI = {
  buttons = {},
  typeButtons = {},   -- [chatType] = button
  flashing = {},      -- [button] = true
  optionsCreated = false,
  optionsRegistered = false,
}

-- Forward declarations (IMPORTANT)
local RestorePos, Build, UpdateLockVisual
local StopFlash, StartFlash, FlashChatType
local ApplyAndRebuild, CreateOptionsPanel

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
-- Flashing logic (GLOBAL for this file)
-- =========================
StopFlash = function(btn)
  if not btn then return end
  UI.flashing[btn] = nil
  btn._flash = nil
  btn:SetScript("OnUpdate", nil)
  if btn._baseColor then
    btn.tex:SetVertexColor(btn._baseColor[1], btn._baseColor[2], btn._baseColor[3], btn._baseColor[4])
  end
end

StartFlash = function(btn)
  if not btn or UI.flashing[btn] then return end
  UI.flashing[btn] = true
  btn._flash = { t = 0, on = false }

  btn:SetScript("OnUpdate", function(self, elapsed)
    if not UI.flashing[self] then
      self:SetScript("OnUpdate", nil)
      return
    end

    local f = self._flash
    if not f then return end

    f.t = f.t + elapsed
    if f.t >= 0.35 then
      f.t = 0
      f.on = not f.on

      if self._baseColor then
        local r,g,b,a = self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4]
        if f.on then
          self.tex:SetVertexColor(math.min(r*1.25,1), math.min(g*1.25,1), math.min(b*1.25,1), math.min(a+0.25,1))
        else
          self.tex:SetVertexColor(r,g,b,a)
        end
      end
    end
  end)
end

FlashChatType = function(chatType)
  local btn = UI.typeButtons and UI.typeButtons[chatType]
  if btn then StartFlash(btn) end
end

-- =========================
-- Blocks / Layout / Build
-- =========================
local function ClearButtons()
  -- stop flashing on existing buttons
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

  b:SetScript("OnEnter", function(self)
    if self._tooltipText then Tooltip(self, self._tooltipText) end
    local r, g, bl, a = self.tex:GetVertexColor()
    self.tex:SetVertexColor(r, g, bl, math.min(a + 0.15, 1))
  end)

  b:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    if self._baseColor then
      self.tex:SetVertexColor(self._baseColor[1], self._baseColor[2], self._baseColor[3], self._baseColor[4])
    end
  end)

  return b
end

local function Layout()
  local db = DB()
  local pad = 4
  local x = pad

  for _, b in ipairs(UI.buttons) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", UI.bar, "TOPLEFT", x, -pad)
    x = x + db.w + db.gap
  end

  UI.bar:SetWidth(x + pad - db.gap)
  UI.bar:SetHeight(db.h + pad * 2)
end

Build = function()
  local db = DB()
  ClearButtons()

  -- Fixed chat-type blocks only
  for _, item in ipairs(db.items) do
    local upper = string.upper(tostring(item))
    if IsChatType(upper) then
      local b = MakeBlock(UI.bar, db.w, db.h)

      local r, g, bl = ChatTypeColor(upper)
      b.tex:SetVertexColor(r, g, bl, 0.95)
      b._baseColor = { r, g, bl, 0.95 }
      b._tooltipText = upper

      UI.typeButtons[upper] = b

      b:SetScript("OnClick", function()
        StopFlash(b)          -- stop blink on click
        ActivateChat(upper)
      end)

      table.insert(UI.buttons, b)
    end
  end

  -- Dynamic channels (only active + sendable)
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
          ActivateChat("CHANNEL", id)
        end)

        table.insert(UI.buttons, b)
      end
    end
  end

  Layout()
end

-- =========================
-- Options panel
-- =========================
ApplyAndRebuild = function()
  if UI and UI.bar then
    RestorePos()
    Build()
    UpdateLockVisual()
  end
end

CreateOptionsPanel = function()
  local panel = CreateFrame("Frame", "ChatBarBlocksOptionsPanel")
  panel.name = "ChatBarBlocks"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("ChatBarBlocks")

  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Thin colored bars to pick chat channels with a mouse click.")

  local function MakeCheck(label, x, y, get, set)
    local c = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
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
    local name = "ChatBarBlocksOptSlider" .. sliderCount

    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetWidth(240)

    _G[name .. "Text"]:SetText(label)
    _G[name .. "Low"]:SetText(tostring(minV))
    _G[name .. "High"]:SetText(tostring(maxV))

    local valText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", s, "RIGHT", 10, 0)

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

  local chkLocked = MakeCheck("Locked (disable dragging)", 16, -70,
    function() return DB().locked end,
    function(v) DB().locked = v end
  )

  local chkTooltips = MakeCheck("Show tooltips on hover", 16, -95,
    function() return DB().showTooltips end,
    function(v) DB().showTooltips = v end
  )

  local sW = MakeSlider("Block width", 16, -140, 10, 200, 1,
    function() return DB().w end,
    function(v) DB().w = math.floor(v + 0.5) end,
    "%.0f"
  )

  local sH = MakeSlider("Block height", 16, -190, 2, 40, 1,
    function() return DB().h end,
    function(v) DB().h = math.floor(v + 0.5) end,
    "%.0f"
  )

  local sGap = MakeSlider("Gap", 16, -240, 0, 30, 1,
    function() return DB().gap end,
    function(v) DB().gap = math.floor(v + 0.5) end,
    "%.0f"
  )

  local sAlpha = MakeSlider("Bar alpha", 16, -290, 0.1, 1.0, 0.05,
    function() return DB().alpha end,
    function(v) DB().alpha = v end,
    "%.2f"
  )

  local sScale = MakeSlider("Bar scale", 16, -340, 0.6, 2.0, 0.05,
    function() return DB().scale end,
    function(v) DB().scale = v end,
    "%.2f"
  )

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(140, 22)
  reset:SetPoint("TOPLEFT", 16, -390)
  reset:SetText("Reset to defaults")
  reset:SetScript("OnClick", function()
    ChatBarBlocksDB = nil
    DB()
    RestorePos()
    Build()
    UpdateLockVisual()
    panel.Refresh()
    Print("Reset.")
  end)

  panel.Refresh = function()
    chkLocked.Refresh()
    chkTooltips.Refresh()
    sW.Refresh()
    sH.Refresh()
    sGap.Refresh()
    sAlpha.Refresh()
    sScale.Refresh()
  end

  panel:SetScript("OnShow", function()
    panel.Refresh()
  end)

  -- Register once (TBC usually has InterfaceOptions)
  if not UI.optionsRegistered then
    if InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(panel)
    elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
      local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name or "ChatBarBlocks")
      Settings.RegisterAddOnCategory(category)
    end
    UI.optionsRegistered = true
  end
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
    Print("Reset.")
  elseif cmd == "tooltip" then
    db.showTooltips = not db.showTooltips
    Print("Tooltips: " .. (db.showTooltips and "ON" or "OFF"))
  else
    Print("Commands:")
    Print("/cbb unlock | lock | reset | tooltip")
  end
end

-- =========================
-- Frame
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

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHANNEL_UI_UPDATE")
f:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")

-- Blink only for these (not global channels)
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_PARTY_LEADER")
f:RegisterEvent("CHAT_MSG_RAID")
f:RegisterEvent("CHAT_MSG_RAID_LEADER")
f:RegisterEvent("CHAT_MSG_GUILD")
f:RegisterEvent("CHAT_MSG_WHISPER")

f:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "ChatBarBlocks" then
    DB()

    if not UI.optionsCreated then
      CreateOptionsPanel()
      UI.optionsCreated = true
    end

    RestorePos()
    Build()
    UpdateLockVisual()
    Print("Loaded. Use /cbb or Options → AddOns → ChatBarBlocks.")
    return
  end

  -- Blink (only local channels)
  if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
    FlashChatType("PARTY")
    return
  elseif event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
    FlashChatType("RAID")
    return
  elseif event == "CHAT_MSG_GUILD" then
    FlashChatType("GUILD")
    return
  elseif event == "CHAT_MSG_WHISPER" then
    FlashChatType("WHISPER")
    return
  end

  -- Rebuild when channel state changes
  if event == "PLAYER_ENTERING_WORLD"
    or event == "CHANNEL_UI_UPDATE"
    or event == "CHAT_MSG_CHANNEL_NOTICE" then
    Build()
  end
end)
