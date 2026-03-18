JacobsBuffTracker = {}
JacobsBuffTracker.name = "JacobsBuffTracker"

local JBT = JacobsBuffTracker
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

JBT.inCombat = false
JBT.unlocked = false
JBT.sv = nil
JBT.runtimeTrackers = {}
JBT.isMounted = false

local defaults = {
    unlocked = false,
    selectedTrackerId = 1,
    pendingNewTrackerName = "",

    trackers = {
        {
            id = 1,
            name = "Tracker 1",
            enabled = true,

            enableBar = true,
            enableRebuffIcon = true,

            abilityId = 0,
            rememberedIcon = "",
            classId = 0,
            showBuffName = false,
            warningThreshold = 3,

            barWidth = 360,
            barHeight = 24,
            barColor = { 0.2, 0.7, 1, 0.95 },

            barPosition = {
                x = 700,
                y = 500,
            },

            rebuffPosition = {
                x = 860,
                y = 420,
            },
        },
    },
}

local function SafeIcon(path)
    if path and path ~= "" then
        return path
    end
    return "/esoui/art/icons/icon_missing.dds"
end

local function GetPlayerClassIdSafe()
    return GetUnitClassId("player")
end

local function CloneTable(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            copy[k] = CloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function JBT:GetTrackerById(trackerId)
    if not self.sv or not self.sv.trackers then
        return nil
    end

    for _, tracker in ipairs(self.sv.trackers) do
        if tracker.id == trackerId then
            return tracker
        end
    end

    return nil
end

function JBT:GetRuntimeTracker(trackerId)
    return self.runtimeTrackers[trackerId]
end

function JBT:GetSelectedTrackerId()
    if not self.sv then
        return 1
    end
    return self.sv.selectedTrackerId
end

function JBT:SetSelectedTrackerId(trackerId)
    if self.sv then
        self.sv.selectedTrackerId = trackerId
    end
end

function JBT:GetNextTrackerId()
    local maxId = 0
    for _, tracker in ipairs(self.sv.trackers) do
        if tracker.id > maxId then
            maxId = tracker.id
        end
    end
    return maxId + 1
end

function JBT:CreateDefaultTracker(newId)
    local tracker = CloneTable(defaults.trackers[1])
    tracker.id = newId
    tracker.name = "Tracker " .. tostring(newId)

    tracker.barPosition.x = tracker.barPosition.x + ((newId - 1) * 30)
    tracker.barPosition.y = tracker.barPosition.y + ((newId - 1) * 30)
    tracker.rebuffPosition.x = tracker.rebuffPosition.x + ((newId - 1) * 30)
    tracker.rebuffPosition.y = tracker.rebuffPosition.y + ((newId - 1) * 30)

    return tracker
end

function JBT:AddTracker()
    local newId = self:GetNextTrackerId()
    local tracker = self:CreateDefaultTracker(newId)

    local customName = ""
    if self.sv and self.sv.pendingNewTrackerName then
        customName = tostring(self.sv.pendingNewTrackerName):gsub("^%s+", ""):gsub("%s+$", "")
    end

    if customName ~= "" then
        tracker.name = customName
    else
        tracker.name = "Tracker " .. tostring(newId)
    end

    table.insert(self.sv.trackers, tracker)
    self.sv.pendingNewTrackerName = ""
    self:SetSelectedTrackerId(newId)

    d("[JBT] Added tracker " .. tostring(newId) .. ". Reloading UI...")
    ReloadUI()
end

function JBT:DeleteTracker(trackerId)
    if #self.sv.trackers <= 1 then
        d("[JBT] At least one tracker must remain")
        return
    end

    for i, tracker in ipairs(self.sv.trackers) do
        if tracker.id == trackerId then
            table.remove(self.sv.trackers, i)
            break
        end
    end

    local selected = self.sv.trackers[1] and self.sv.trackers[1].id or 1
    self:SetSelectedTrackerId(selected)
    d("[JBT] Deleted tracker " .. tostring(trackerId) .. ". Reloading UI...")
    ReloadUI()
end

function JBT:IsTrackerEnabledForCurrentClass(trackerData)
    if not trackerData then
        return false
    end

    if not trackerData.enabled then
        return false
    end

    local requiredClassId = tonumber(trackerData.classId or 0) or 0
    if requiredClassId == 0 then
        return true
    end

    return requiredClassId == GetPlayerClassIdSafe()
end

function JBT:SaveBarPosition(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData or not runtime.barWindow then
        return
    end

    trackerData.barPosition.x = runtime.barWindow:GetLeft() or trackerData.barPosition.x
    trackerData.barPosition.y = runtime.barWindow:GetTop() or trackerData.barPosition.y
end

function JBT:SaveRebuffPosition(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData or not runtime.rebuffWindow then
        return
    end

    trackerData.rebuffPosition.x = runtime.rebuffWindow:GetLeft() or trackerData.rebuffPosition.x
    trackerData.rebuffPosition.y = runtime.rebuffWindow:GetTop() or trackerData.rebuffPosition.y
end

function JBT:ApplyBarPosition(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData or not runtime.barWindow then
        return
    end

    runtime.barWindow:ClearAnchors()
    runtime.barWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, trackerData.barPosition.x, trackerData.barPosition.y)
end

function JBT:ApplyRebuffPosition(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData or not runtime.rebuffWindow then
        return
    end

    runtime.rebuffWindow:ClearAnchors()
    runtime.rebuffWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, trackerData.rebuffPosition.x, trackerData.rebuffPosition.y)
end

function JBT:SetUnlocked(unlocked)
    self.unlocked = unlocked
    self.sv.unlocked = unlocked

    for trackerId, runtime in pairs(self.runtimeTrackers) do
        if runtime.barWindow then
            runtime.barWindow:SetMouseEnabled(unlocked)
            runtime.barWindow:SetMovable(unlocked)
        end

        if runtime.rebuffWindow then
            runtime.rebuffWindow:SetMouseEnabled(unlocked)
            runtime.rebuffWindow:SetMovable(unlocked)
        end

        if runtime.barDragLabel then
            runtime.barDragLabel:SetHidden(not unlocked)
        end

        if runtime.rebuffDragLabel then
            runtime.rebuffDragLabel:SetHidden(not unlocked)
        end

        if not unlocked then
            self:SaveBarPosition(trackerId)
            self:SaveRebuffPosition(trackerId)
        end
    end

    if unlocked then
        d("[JBT] Unlocked")
    else
        d("[JBT] Locked")
    end

    self:UpdateAllUI()
end

function JBT:ApplyTrackerVisualSettings(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData then
        return
    end

    local barWidth = tonumber(trackerData.barWidth or 360) or 360
    local barHeight = tonumber(trackerData.barHeight or 24) or 24
    local iconSize = barHeight
    local iconBgSize = barHeight + 6

    local color = trackerData.barColor or { 0.2, 0.7, 1, 0.95 }
    local r = color[1] or 0.2
    local g = color[2] or 0.7
    local b = color[3] or 1
    local a = color[4] or 0.95

    if runtime.icon then
        runtime.icon:SetDimensions(iconSize, iconSize)
    end

    if runtime.iconBg then
        runtime.iconBg:SetDimensions(iconBgSize, iconBgSize)
    end

    if runtime.barBg then
        runtime.barBg:SetDimensions(barWidth, barHeight)
    end

    if runtime.statusBar then
        runtime.statusBar:SetColor(r, g, b, a)
    end

    if runtime.buffNameLabel then
        runtime.buffNameLabel:SetHidden(not trackerData.showBuffName)
    end
    if runtime.barDragLabel then
        runtime.barDragLabel:SetText(trackerData.name .. " BAR")
    end
    if runtime.rebuffDragLabel then
        runtime.rebuffDragLabel:SetText(trackerData.name .. " REBUFF")
    end
end

function JBT:RescanTrackedBuff(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    if not runtime or not trackerData then
        return
    end

    runtime.activeBuff = nil

    if not self:IsTrackerEnabledForCurrentClass(trackerData) then
        return
    end

    local trackedId = tonumber(trackerData.abilityId or 0) or 0
    if trackedId == 0 then
        return
    end

    for i = 1, GetNumBuffs("player") do
        local buffName, startTime, endTime, stackCount, icon, buffType,
              effectType, abilityType, statusEffectType, unitName,
              unitId, abilityId = GetUnitBuffInfo("player", i)

        if abilityId == trackedId then
            runtime.activeBuff = {
                beginTime = startTime or 0,
                endTime = endTime or 0,
                stacks = stackCount or 0,
                icon = SafeIcon(icon),
                name = buffName or "Tracked Buff",
            }

            if icon and icon ~= "" then
                trackerData.rememberedIcon = icon
            end

            return
        end
    end
end

function JBT:CreateBarUI(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    local runtime = self.runtimeTrackers[trackerId]
    if not trackerData or not runtime then
        return
    end

    local suffix = tostring(trackerId)

    local barWindow = WM:CreateTopLevelWindow("JacobsBuffTrackerBarWindow_" .. suffix)
    barWindow:SetDimensions(520, 80)
    barWindow:SetClampedToScreen(true)
    barWindow:SetHidden(true)
    barWindow:SetMouseEnabled(false)
    barWindow:SetMovable(false)
    barWindow:SetDrawLayer(DL_OVERLAY)
    barWindow:SetHandler("OnMoveStop", function()
        self:SaveBarPosition(trackerId)
    end)
    runtime.barWindow = barWindow
    self:ApplyBarPosition(trackerId)

    local dragLabel = WM:CreateControl("JacobsBuffTrackerBarDragLabel_" .. suffix, barWindow, CT_LABEL)
    dragLabel:SetAnchor(TOP, barWindow, TOP, 0, 0)
    dragLabel:SetFont("ZoFontGame")
    dragLabel:SetColor(0.8, 0.8, 0.8, 0.85)
    dragLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    dragLabel:SetText(trackerData.name .. " BAR")
    dragLabel:SetHidden(true)
    runtime.barDragLabel = dragLabel

    local barBg = WM:CreateControl("JacobsBuffTrackerBarBg_" .. suffix, barWindow, CT_BACKDROP)
    barBg:SetDimensions(360, 24)
    barBg:SetAnchor(LEFT, barWindow, LEFT, 48, 24)
    barBg:SetCenterColor(0.05, 0.05, 0.05, 0.85)
    barBg:SetEdgeColor(1, 1, 1, 0.12)
    barBg:SetEdgeTexture("", 1, 1, 1)
    runtime.barBg = barBg

    local iconBg = WM:CreateControl("JacobsBuffTrackerBarIconBg_" .. suffix, barWindow, CT_BACKDROP)
    iconBg:SetDimensions(30, 30)
    iconBg:SetAnchor(RIGHT, barBg, LEFT, -4, 0)
    iconBg:SetCenterColor(0, 0, 0, 0.75)
    iconBg:SetEdgeColor(1, 1, 1, 0.15)
    iconBg:SetEdgeTexture("", 1, 1, 1)
    runtime.iconBg = iconBg

    local icon = WM:CreateControl("JacobsBuffTrackerBarIcon_" .. suffix, barWindow, CT_TEXTURE)
    icon:SetDimensions(24, 24)
    icon:SetAnchor(CENTER, iconBg, CENTER, 0, 0)
    icon:SetTexture("/esoui/art/icons/icon_missing.dds")
    runtime.icon = icon

    local statusBar = WM:CreateControl("JacobsBuffTrackerStatusBar_" .. suffix, barBg, CT_STATUSBAR)
    statusBar:SetAnchor(TOPLEFT, barBg, TOPLEFT, 2, 2)
    statusBar:SetAnchor(BOTTOMRIGHT, barBg, BOTTOMRIGHT, -2, -2)
    statusBar:SetMinMax(0, 1)
    statusBar:SetValue(1)
    statusBar:SetColor(0.2, 0.7, 1, 0.95)
    runtime.statusBar = statusBar

    local buffNameLabel = WM:CreateControl("JacobsBuffTrackerBuffName_" .. suffix, barWindow, CT_LABEL)
    buffNameLabel:SetAnchor(BOTTOMLEFT, barBg, TOPLEFT, 2, -2)
    buffNameLabel:SetFont("ZoFontGame")
    buffNameLabel:SetColor(1, 1, 1, 1)
    buffNameLabel:SetText("Buff")
    runtime.buffNameLabel = buffNameLabel

    local timerLabel = WM:CreateControl("JacobsBuffTrackerTimerLabel_" .. suffix, barBg, CT_LABEL)
    timerLabel:SetAnchor(RIGHT, barBg, RIGHT, -8, 0)
    timerLabel:SetFont("ZoFontGameBold")
    timerLabel:SetColor(1, 1, 1, 1)
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    timerLabel:SetText("")
    runtime.timerLabel = timerLabel
end

function JBT:CreateRebuffUI(trackerId)
    local trackerData = self:GetTrackerById(trackerId)
    local runtime = self.runtimeTrackers[trackerId]
    if not trackerData or not runtime then
        return
    end

    local suffix = tostring(trackerId)

    local rebuffWindow = WM:CreateTopLevelWindow("JacobsBuffTrackerRebuffWindow_" .. suffix)
    rebuffWindow:SetDimensions(220, 90)
    rebuffWindow:SetClampedToScreen(true)
    rebuffWindow:SetHidden(true)
    rebuffWindow:SetMouseEnabled(false)
    rebuffWindow:SetMovable(false)
    rebuffWindow:SetDrawLayer(DL_OVERLAY)
    rebuffWindow:SetHandler("OnMoveStop", function()
        self:SaveRebuffPosition(trackerId)
    end)
    runtime.rebuffWindow = rebuffWindow
    self:ApplyRebuffPosition(trackerId)

    local dragLabel = WM:CreateControl("JacobsBuffTrackerRebuffDragLabel_" .. suffix, rebuffWindow, CT_LABEL)
    dragLabel:SetAnchor(TOP, rebuffWindow, TOP, 0, 0)
    dragLabel:SetFont("ZoFontGame")
    dragLabel:SetColor(0.8, 0.8, 0.8, 0.85)
    dragLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    dragLabel:SetText(trackerData.name .. " REBUFF")
    dragLabel:SetHidden(true)
    runtime.rebuffDragLabel = dragLabel

    local rebuffIconBg = WM:CreateControl("JacobsBuffTrackerRebuffIconBg_" .. suffix, rebuffWindow, CT_BACKDROP)
    rebuffIconBg:SetDimensions(56, 56)
    rebuffIconBg:SetAnchor(CENTER, rebuffWindow, CENTER, 0, -4)
    rebuffIconBg:SetCenterColor(0, 0, 0, 0.7)
    rebuffIconBg:SetEdgeColor(1, 1, 1, 0.15)
    rebuffIconBg:SetEdgeTexture("", 1, 1, 1)
    runtime.rebuffIconBg = rebuffIconBg

    local rebuffIcon = WM:CreateControl("JacobsBuffTrackerRebuffIcon_" .. suffix, rebuffWindow, CT_TEXTURE)
    rebuffIcon:SetDimensions(48, 48)
    rebuffIcon:SetAnchor(CENTER, rebuffIconBg, CENTER, 0, 0)
    rebuffIcon:SetTexture("/esoui/art/icons/icon_missing.dds")
    runtime.rebuffIcon = rebuffIcon

    local rebuffLabel = WM:CreateControl("JacobsBuffTrackerRebuffLabel_" .. suffix, rebuffWindow, CT_LABEL)
    rebuffLabel:SetAnchor(TOP, rebuffIconBg, BOTTOM, 0, 6)
    rebuffLabel:SetFont("ZoFontWinH2")
    rebuffLabel:SetColor(1, 0.2, 0.2, 1)
    rebuffLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    rebuffLabel:SetText("REBUFF")
    runtime.rebuffLabel = rebuffLabel
end

function JBT:BuildAllRuntimeTrackers()
    self.runtimeTrackers = {}

    for _, trackerData in ipairs(self.sv.trackers) do
        self.runtimeTrackers[trackerData.id] = {
            activeBuff = nil,
            rebuffAlertShown = false,
        }

        self:CreateBarUI(trackerData.id)
        self:CreateRebuffUI(trackerData.id)
        self:ApplyTrackerVisualSettings(trackerData.id)
        self:RescanTrackedBuff(trackerData.id)
    end

    self:SetUnlocked(self.unlocked)
end

function JBT:OnEffectChanged(
    _,
    changeType,
    effectSlot,
    effectName,
    unitTag,
    beginTime,
    endTime,
    stackCount,
    iconName,
    buffType,
    effectType,
    abilityType,
    statusEffectType,
    unitName,
    unitId,
    abilityId,
    sourceType
)
    if unitTag ~= "player" then
        return
    end

    for _, trackerData in ipairs(self.sv.trackers) do
        local runtime = self:GetRuntimeTracker(trackerData.id)
        if runtime and self:IsTrackerEnabledForCurrentClass(trackerData) then
            local trackedId = tonumber(trackerData.abilityId or 0) or 0
            if trackedId ~= 0 and abilityId == trackedId then
                if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                    runtime.activeBuff = {
                        beginTime = beginTime or 0,
                        endTime = endTime or 0,
                        stacks = stackCount or 0,
                        icon = SafeIcon(iconName),
                        name = effectName or "Tracked Buff",
                    }

                    if iconName and iconName ~= "" then
                        trackerData.rememberedIcon = iconName
                    end
                elseif changeType == EFFECT_RESULT_FADED then
                    runtime.activeBuff = nil
                end
            end
        end
    end
end

function JBT:OnCombatState(_, inCombat)
    self.inCombat = (inCombat == true)
end

function JBT:OnMountedStateChanged(_, isMounted)
    self.isMounted = (isMounted == true)
end

function JBT:RefreshTrackerAfterSettingsChanged(trackerId, rescanBuff)
    self:ApplyTrackerVisualSettings(trackerId)

    if rescanBuff then
        self:RescanTrackedBuff(trackerId)
    end

    local runtime = self:GetRuntimeTracker(trackerId)
    if runtime then
        runtime.rebuffAlertShown = false
    end

    self:UpdateTrackerUI(trackerId)
end

function JBT:UpdateTrackerUI(trackerId)
    local runtime = self:GetRuntimeTracker(trackerId)
    local trackerData = self:GetTrackerById(trackerId)

    if not runtime or not trackerData then
        return
    end

    if not self:IsTrackerEnabledForCurrentClass(trackerData) then
        if self.unlocked then
            if runtime.barWindow then runtime.barWindow:SetHidden(false) end
            if runtime.rebuffWindow then runtime.rebuffWindow:SetHidden(false) end
            if runtime.barDragLabel then runtime.barDragLabel:SetHidden(false) end
            if runtime.rebuffDragLabel then runtime.rebuffDragLabel:SetHidden(false) end
        else
            if runtime.barWindow then runtime.barWindow:SetHidden(true) end
            if runtime.rebuffWindow then runtime.rebuffWindow:SetHidden(true) end
        end
        return
    end

    local buffData = runtime.activeBuff
    local warningThreshold = tonumber(trackerData.warningThreshold or 3) or 3
    local baseColor = trackerData.barColor or { 0.2, 0.7, 1, 0.95 }
    local br = baseColor[1] or 0.2
    local bg = baseColor[2] or 0.7
    local bb = baseColor[3] or 1
    local ba = baseColor[4] or 0.95

    if buffData then
        local now = GetGameTimeSeconds()
        local beginTime = buffData.beginTime or 0
        local endTime = buffData.endTime or 0
        local duration = math.max(endTime - beginTime, 0)
        local remaining = math.max(endTime - now, 0)

        if remaining <= 0 then
            runtime.activeBuff = nil
            buffData = nil
        else
            runtime.rebuffAlertShown = false

            if trackerData.enableRebuffIcon and runtime.rebuffWindow then
                runtime.rebuffWindow:SetHidden(true)
            end

            if trackerData.enableBar and runtime.barWindow then
                runtime.barWindow:SetHidden(false)
            elseif runtime.barWindow then
                runtime.barWindow:SetHidden(true)
            end

            if runtime.icon then
                runtime.icon:SetTexture(SafeIcon(buffData.icon))
            end
            if runtime.rebuffIcon then
                runtime.rebuffIcon:SetTexture(SafeIcon(buffData.icon))
            end
            if runtime.buffNameLabel then
                runtime.buffNameLabel:SetText(buffData.name or "Tracked Buff")
                runtime.buffNameLabel:SetHidden(not trackerData.showBuffName)
            end
            if runtime.timerLabel then
                runtime.timerLabel:SetText(string.format("%.1f", remaining))
            end

            if runtime.statusBar then
                if duration > 0 then
                    runtime.statusBar:SetMinMax(0, duration)
                    runtime.statusBar:SetValue(remaining)
                else
                    runtime.statusBar:SetMinMax(0, 1)
                    runtime.statusBar:SetValue(0)
                end

                if remaining <= warningThreshold then
                    runtime.statusBar:SetColor(1, 0.25, 0.25, 0.95)
                else
                    runtime.statusBar:SetColor(br, bg, bb, ba)
                end
            end

            if runtime.timerLabel then
                if remaining <= warningThreshold then
                    runtime.timerLabel:SetColor(1, 0.25, 0.25, 1)
                else
                    runtime.timerLabel:SetColor(1, 1, 1, 1)
                end
            end

            if self.unlocked and runtime.barDragLabel then
                runtime.barDragLabel:SetHidden(false)
            elseif runtime.barDragLabel then
                runtime.barDragLabel:SetHidden(true)
            end

            return
        end
    end

    if runtime.barWindow then
        runtime.barWindow:SetHidden(not self.unlocked)
    end

    if self.inCombat and not self.isMounted and not IsUnitDead("player") and trackerData.enableRebuffIcon then
        if runtime.rebuffWindow then
            runtime.rebuffWindow:SetHidden(false)
        end

        if runtime.rebuffIcon then
            runtime.rebuffIcon:SetTexture(SafeIcon(trackerData.rememberedIcon))
        end

        if not runtime.rebuffAlertShown then
            runtime.rebuffAlertShown = true
            if runtime.rebuffLabel then
                runtime.rebuffLabel:SetColor(1, 0.15, 0.15, 1)
            end
            d("[JBT] REBUFF: " .. tostring(trackerData.name))
        end
        return
    end

    runtime.rebuffAlertShown = false

    if runtime.rebuffWindow then
        runtime.rebuffWindow:SetHidden(not self.unlocked)
    end
end

function JBT:UpdateAllUI()
    for _, trackerData in ipairs(self.sv.trackers) do
        self:UpdateTrackerUI(trackerData.id)
    end
end

function JBT:GetTrackerChoices()
    local choices = {}
    for _, tracker in ipairs(self.sv.trackers) do
        table.insert(choices, tracker.name .. " [ID " .. tostring(tracker.id) .. "]")
    end
    return choices
end

function JBT:GetSelectedTrackerChoice()
    local selectedId = self:GetSelectedTrackerId()
    local tracker = self:GetTrackerById(selectedId)
    if not tracker then
        return nil
    end
    return tracker.name .. " [ID " .. tostring(tracker.id) .. "]"
end

function JBT:GetTrackerChoiceNames()
    local names = {}
    for _, tracker in ipairs(self.sv.trackers) do
        table.insert(names, tracker.name or ("Tracker " .. tostring(tracker.id)))
    end
    return names
end

function JBT:GetTrackerChoiceIds()
    local ids = {}
    for _, tracker in ipairs(self.sv.trackers) do
        table.insert(ids, tracker.id)
    end
    return ids
end

function JBT:SetSelectedTrackerChoice(choice)
    for _, tracker in ipairs(self.sv.trackers) do
        local trackerChoice = tracker.name .. " [ID " .. tostring(tracker.id) .. "]"
        if trackerChoice == choice then
            self:SetSelectedTrackerId(tracker.id)
            return
        end
    end
end

function JBT:RegisterSlashCommands()
    SLASH_COMMANDS["/jbt"] = function(text)
        local cmd = zo_strlower((text or ""):match("^%s*(.-)%s*$") or "")

        if cmd == "unlock" then
            self:SetUnlocked(true)
        elseif cmd == "lock" then
            self:SetUnlocked(false)
        else
            d("[JBT] /jbt unlock")
            d("[JBT] /jbt lock")
        end
    end
end

function JBT:GetClassChoices()
    return {
        "All Classes",
        "Dragonknight",
        "Sorcerer",
        "Nightblade",
        "Warden",
        "Necromancer",
        "Templar",
        "Arcanist",
    }
end

function JBT:GetClassIdFromChoice(choice)
    local map = {
        ["All Classes"] = 0,
        ["Dragonknight"] = 1,
        ["Sorcerer"] = 2,
        ["Nightblade"] = 3,
        ["Warden"] = 4,
        ["Necromancer"] = 5,
        ["Templar"] = 6,
        ["Arcanist"] = 117,
    }
    return map[choice] or 0
end

function JBT:GetChoiceFromClassId(classId)
    local map = {
        [0] = "All Classes",
        [1] = "Dragonknight",
        [2] = "Sorcerer",
        [3] = "Nightblade",
        [4] = "Warden",
        [5] = "Necromancer",
        [6] = "Templar",
        [117] = "Arcanist",
    }
    return map[classId or 0] or "All Classes"
end

function JBT:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("JacobsBuffTrackerSavedVars", 2, GetWorldName(), defaults)
    self.unlocked = self.sv.unlocked

    if not self.sv.trackers or #self.sv.trackers == 0 then
        self.sv.trackers = CloneTable(defaults.trackers)
    end

    self:BuildAllRuntimeTrackers()
    self:RegisterSlashCommands()

    EM:RegisterForEvent(self.name, EVENT_EFFECT_CHANGED, function(...)
        self:OnEffectChanged(...)
    end)
    EM:AddFilterForEvent(self.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EM:RegisterForEvent(self.name .. "_Combat", EVENT_PLAYER_COMBAT_STATE, function(...)
        self:OnCombatState(...)
    end)

    EM:RegisterForEvent(self.name .. "_Mounted", EVENT_MOUNTED_STATE_CHANGED, function(...)
    self:OnMountedStateChanged(...)
    end)

    EM:RegisterForUpdate(self.name .. "_Update", 100, function()
        self:UpdateAllUI()
    end)

    if self.InitializeSettings then
        self:InitializeSettings()
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= JBT.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(JBT.name, EVENT_ADD_ON_LOADED)
    JBT:Initialize()
end

EVENT_MANAGER:RegisterForEvent(JBT.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)