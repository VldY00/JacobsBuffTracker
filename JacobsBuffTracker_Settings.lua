local JBT = JacobsBuffTracker
local LAM = LibAddonMenu2

function JBT:InitializeSettings()
    if not LAM then
        d("[JBT] LibAddonMenu-2.0 not found")
        return
    end

    local panelData = {
        type = "panel",
        name = "JacobsBuffTracker",
        displayName = "JacobsBuffTracker",
        author = "Jacobs",
        version = "0.6.1",
        registerForRefresh = true,
        registerForDefaults = false,
    }

    JBT.settingsPanel = LAM:RegisterAddonPanel("JacobsBuffTrackerOptions", panelData)

    local function GetSelectedTracker()
        local trackerId = JBT:GetSelectedTrackerId()
        return JBT:GetTrackerById(trackerId)
    end

    local function RefreshCurrentTracker(rescan)
        local tracker = GetSelectedTracker()
        if not tracker then
            return
        end
        JBT:RefreshTrackerAfterSettingsChanged(tracker.id, rescan)
    end

    local trackerChoiceNames = {}
    local trackerChoiceIds = {}

    if JBT.sv and JBT.sv.trackers then
        for _, tracker in ipairs(JBT.sv.trackers) do
            table.insert(trackerChoiceNames, tracker.name or ("Tracker " .. tostring(tracker.id)))
            table.insert(trackerChoiceIds, tracker.id)
        end
    end

    local optionsData = {
        {
            type = "header",
            name = "Tracker Selection",
            width = "full",
        },
        {
            type = "dropdown",
            name = "Current Tracker",
            tooltip = "Choose which tracker to edit",
            choices = trackerChoiceNames,
            choicesValues = trackerChoiceIds,
            getFunc = function()
                return JBT:GetSelectedTrackerId()
            end,
            setFunc = function(trackerId)
                JBT:SetSelectedTrackerId(trackerId)
            end,
            width = "full",
        },
        {
            type = "editbox",
            name = "New Tracker Name",
            tooltip = "Enter a name for the new tracker. If empty, default name will be used.",
            getFunc = function()
                return tostring(JBT.sv.pendingNewTrackerName or "")
            end,
            setFunc = function(value)
                JBT.sv.pendingNewTrackerName = tostring(value or "")
            end,
            isMultiline = false,
            width = "half",
            default = "",
        },
        {
            type = "button",
            name = "Add New Tracker",
            tooltip = "Create another account-wide tracker using the name above",
            func = function()
                JBT:AddTracker()
            end,
            width = "half",
        },
        {
            type = "button",
            name = "Delete Selected Tracker",
            func = function()
                local tracker = GetSelectedTracker()
                if tracker then
                    JBT:DeleteTracker(tracker.id)
                end
            end,
            width = "half",
            isDangerous = true,
        },

        {
            type = "header",
            name = "General",
            width = "full",
        },
        {
            type = "description",
            text = function()
                local tracker = GetSelectedTracker()
                if tracker then
                    return "Selected tracker: " .. tostring(tracker.name or ("Tracker " .. tostring(tracker.id)))
                end
                return "Selected tracker: none"
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Enabled",
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.enabled or false
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.enabled = value
                    RefreshCurrentTracker(true)
                end
            end,
            default = true,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Enable Progress Bar",
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.enableBar or false
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.enableBar = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = true,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Enable Rebuff Icon",
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.enableRebuffIcon or false
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.enableRebuffIcon = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = true,
            width = "half",
        },
        {
            type = "editbox",
            name = "Ability ID",
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tostring(tracker.abilityId or 0) or "0"
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                local num = tonumber(value)
                if tracker and num and num > 0 then
                    tracker.abilityId = math.floor(num)
                    RefreshCurrentTracker(true)
                    d(string.format("[JBT] Tracker %d abilityId = %d", tracker.id, tracker.abilityId))
                end
            end,
            isMultiline = false,
            width = "half",
            default = tostring(183047),
        },
        {
            type = "dropdown",
            name = "Class Filter",
            choices = JBT:GetClassChoices(),
            getFunc = function()
                local tracker = GetSelectedTracker()
                if not tracker then
                    return "All Classes"
                end
                return JBT:GetChoiceFromClassId(tracker.classId)
            end,
            setFunc = function(choice)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.classId = JBT:GetClassIdFromChoice(choice)
                    RefreshCurrentTracker(true)
                end
            end,
            default = "All Classes",
            width = "half",
        },
        {
            type = "checkbox",
            name = "Show Buff Name",
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.showBuffName or false
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.showBuffName = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = true,
            width = "half",
        },
        {
            type = "slider",
            name = "Warning Threshold",
            min = 1,
            max = 10,
            step = 1,
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.warningThreshold or 3
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.warningThreshold = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = 3,
            width = "half",
        },

        {
            type = "header",
            name = "Bar Appearance",
            width = "full",
        },
        {
            type = "slider",
            name = "Bar Width",
            min = 150,
            max = 700,
            step = 10,
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.barWidth or 360
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.barWidth = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = 360,
            width = "half",
        },
        {
            type = "slider",
            name = "Bar Height",
            min = 12,
            max = 60,
            step = 1,
            getFunc = function()
                local tracker = GetSelectedTracker()
                return tracker and tracker.barHeight or 24
            end,
            setFunc = function(value)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.barHeight = value
                    RefreshCurrentTracker(false)
                end
            end,
            default = 24,
            width = "half",
        },
        {
            type = "colorpicker",
            name = "Bar Color",
            getFunc = function()
                local tracker = GetSelectedTracker()
                local c = (tracker and tracker.barColor) or { 0.2, 0.7, 1, 0.95 }
                return c[1], c[2], c[3], c[4]
            end,
            setFunc = function(r, g, b, a)
                local tracker = GetSelectedTracker()
                if tracker then
                    tracker.barColor = { r, g, b, a }
                    RefreshCurrentTracker(false)
                end
            end,
            default = { 0.2, 0.7, 1, 0.95 },
            width = "half",
        },

        {
            type = "header",
            name = "Positioning",
            width = "full",
        },
        {
            type = "description",
            text = "Use /jbt unlock to move every tracker bar and rebuff icon independently. Use /jbt lock to save positions.",
            width = "full",
        },
    }

    LAM:RegisterOptionControls("JacobsBuffTrackerOptions", optionsData)
end