-- SmallerRollFrames_RollCount - Adds roll count display to SmallerRollFrames
local addon = CreateFrame("Frame")
local rollCache, rollIdToItem = {}, {}
local getCounter

SRF_RC_Settings = SRF_RC_Settings or {
  positions = {
    Need = {x = 0, y = 0},
    Greed = {x = 0, y = 1},
    Pass = {x = 0, y = -1}
  }
}

-- Forward declaration for updateFrames
local updateFrames

-- Register required events
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("CHAT_MSG_LOOT")
addon:RegisterEvent("CHAT_MSG_SYSTEM")
addon:RegisterEvent("START_LOOT_ROLL")

-- Utility function for messages
local function msg(text) DEFAULT_CHAT_FRAME:AddMessage("|cFF99CCFF[SRF_RC]|r " .. text) end

-- Prepare roll patterns once
local patterns = {
  Need = string.gsub(LOOT_ROLL_NEED, "%%s|Hitem:%%d+:%%d+:%%d+:%%d+|h%[%%s%]|h%%s", "%%s"),
  Greed = string.gsub(LOOT_ROLL_GREED, "%%s|Hitem:%%d+:%%d+:%%d+:%%d+|h%[%%s%]|h%%s", "%%s"),
  Pass = string.gsub(LOOT_ROLL_PASSED, "%%s|Hitem:%%d+:%%d+:%%d+:%%d+|h%[%%s%]|h%%s", "%%s")
}

-- Class color table
local classColors = {
  ["WARRIOR"] = "|cFFC79C6E", ["MAGE"] = "|cFF69CCF0", ["ROGUE"] = "|cFFFFF569", 
  ["DRUID"] = "|cFFFF7D0A", ["HUNTER"] = "|cFFABD473", ["SHAMAN"] = "|cFF0070DE", 
  ["PRIEST"] = "|cFFFFFFFF", ["WARLOCK"] = "|cFF9482C9", ["PALADIN"] = "|cFFF58CBA"
}

-- Position adjustments for each button type
local counterPositions = SRF_RC_Settings.positions

-- Add this function before your main code
local function updatePreviewCounters()
  -- Check if preview frames are visible
  local previewVisible = false
  for i = 1, 4 do
    local frame = getglobal("SmallGroupLootFrame"..i)
    if frame and frame:IsVisible() then
      previewVisible = true
      break
    end
  end
  
  if not previewVisible then return end
  
  -- Update all preview frames
  for i = 1, 4 do
    local frame = getglobal("SmallGroupLootFrame"..i)
    if frame and frame:IsVisible() then
      local buttons = {
        Need = getglobal("SmallGroupLootFrame"..i.."RollButton"),
        Greed = getglobal("SmallGroupLootFrame"..i.."GreedButton"),
        Pass = getglobal("SmallGroupLootFrame"..i.."PassButton")
      }
      
      for rollType, button in pairs(buttons) do
        if button then
          -- Remove existing count text
          if button.countText then
            button.countText:Hide()
            button.countText = nil
          end
          
          -- Create fresh counter with updated position
          local countText = getCounter(button, rollType)
          countText:SetText("0")
        end
      end
    end
  end
end

-- Add this function right before your event handler
local function hookOriginalCommand()
  if not SlashCmdList["SMALLERROLLFRAMES"] then return end
  
  -- Store original function
  local originalFunc = SlashCmdList["SMALLERROLLFRAMES"]
  
  -- Replace with our hooked version
  SlashCmdList["SMALLERROLLFRAMES"] = function(cmdText)
    -- Check if it's one of our commands
    if string.find(cmdText, "^offset%s+") then
      -- Extract the parts using string.find and sub
      local _, endPos = string.find(cmdText, "^offset%s+")
      local remaining = string.sub(cmdText, endPos + 1)
      
      -- Find rollType (first word)
      local rollTypeEnd = string.find(remaining, "%s+")
      if not rollTypeEnd then return end
      
      local rollType = string.sub(remaining, 1, rollTypeEnd - 1)
      remaining = string.sub(remaining, rollTypeEnd + 1)
      
      -- Find X (second word)
      local xEnd = string.find(remaining, "%s+")
      if not xEnd then return end
      
      local x = tonumber(string.sub(remaining, 1, xEnd - 1))
      remaining = string.sub(remaining, xEnd + 1)
      
      -- Y is the rest
      local y = tonumber(remaining)
      
      if rollType and x and y then
        if counterPositions[rollType] then
          counterPositions[rollType].x = x
          counterPositions[rollType].y = y
          -- Save to persistent settings
          SRF_RC_Settings.positions[rollType].x = x
          SRF_RC_Settings.positions[rollType].y = y
          msg("Counter position " .. rollType .. " set to x:" .. x .. ", y:" .. y)
          updateFrames()
          -- Update preview frames if they're visible
          updatePreviewCounters()
        else
          msg("Invalid roll type. Use: Need, Greed, or Pass")
        end
      end
    elseif cmdText == "resetpos" then
      -- Reset the counter positions
      counterPositions.Need = {x = 0, y = 0}
      counterPositions.Greed = {x = 0, y = 1}
      counterPositions.Pass = {x = 0, y = -1}
      
      -- Save to persistent settings
      SRF_RC_Settings.positions = {
        Need = {x = 0, y = 0},
        Greed = {x = 0, y = 1},
        Pass = {x = 0, y = -1}
      }
      
      msg("Counter positions reset to defaults")
      updateFrames()
      -- Update preview frames if they're visible
      updatePreviewCounters()
    elseif cmdText == "positions" then
      msg("Current counter positions:")
      for type, pos in pairs(counterPositions) do
        msg(type .. ": x=" .. pos.x .. ", y=" .. pos.y)
      end
    elseif string.find(cmdText, "^toggle%s+move") then
      -- Call original first for this command
      originalFunc(cmdText)
      
      -- Add our preview logic
      local delay = CreateFrame("Frame")
      delay:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed > 0.1 then
          -- Find the test frames created by SmallerRollFrames
          for i = 1, 4 do
            local frame = getglobal("SmallGroupLootFrame"..i)
            if frame and frame:IsVisible() then
              -- Add counter texts to the buttons
              local buttons = {
                Need = getglobal("SmallGroupLootFrame"..i.."RollButton"),
                Greed = getglobal("SmallGroupLootFrame"..i.."GreedButton"),
                Pass = getglobal("SmallGroupLootFrame"..i.."PassButton")
              }
              
              for rollType, button in pairs(buttons) do
                if button then
                  -- IMPORTANT: Remove any existing countText to force fresh creation with current settings
                  if button.countText then
                    button.countText:Hide()
                    button.countText = nil
                  end
                  
                  -- Create fresh counter text with current position settings
                  local countText = getCounter(button, rollType)
                  countText:SetText("0")  -- Simple "0" for preview
                end
              end
            end
          end
          
          this:SetScript("OnUpdate", nil)
        end
      end)
    elseif cmdText == "help" or cmdText == "" then
      -- Call original first
      originalFunc(cmdText)
      
      -- Add our help text
      msg("--- SmallerRollFrames_RollCount Commands ---")
      msg("/smrf offset <Need|Greed|Pass> <x> <y> - Adjust counter position")
      msg("/smrf resetpos - Reset counter positions")
      msg("/smrf positions - Show current counter positions")
    else
      -- For all other commands, pass to original handler
      originalFunc(cmdText)
    end
  end
end

-- Get or create count text on button with proper positioning
getCounter = function(button, rollType)
  if not button.countText then
    button.countText = button:CreateFontString(nil, "OVERLAY")
    button.countText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.countText:SetTextColor(1, 1, 1)
    button.countText:SetShadowOffset(1, -1)
    button.countText:SetShadowColor(0, 0, 0, 1)
    
    local pos = counterPositions[rollType] or {x = 0, y = 0}
    button.countText:SetPoint("CENTER", pos.x, pos.y)
    button.countText:SetDrawLayer("OVERLAY", 7)
  end
  return button.countText
end

-- Initialize or get roll data for an item
local function getRollData(itemName)
  if not rollCache[itemName] then
    rollCache[itemName] = {
      Need = {}, Greed = {}, Pass = {}, timestamp = GetTime()
    }
  end
  return rollCache[itemName]
end

-- Process a roll message
local function processRoll(message)
  -- Helper function for pattern matching
  local function match(text, pattern, matchNum)
    matchNum = matchNum or 1
    
    -- Convert %s placeholders to capture groups
    local buffer = pattern
    while string.find(buffer, "%%s") do
      buffer = string.gsub(buffer, "%%s", "(.+)", 1)
    end
    
    -- Use string.find with captures instead of string.match
    local results = {string.find(text, buffer)}
    if results[1] then
      return results[matchNum + 2]
    end
    
    return nil
  end
  
  -- Check each roll type
  for rollType, pattern in pairs(patterns) do
    local player, item = match(message, pattern), match(message, pattern, 2)
    if player and item then
      -- Find matching item
      for _, name in pairs(rollIdToItem) do
        if string.find(item, name) then
          -- Get player class if possible
          local playerClass = nil
          if player == YOU or player == UnitName("player") then
            _, playerClass = UnitClass("player")
          else
            for i = 1, GetNumPartyMembers() do
              if UnitName("party"..i) == player then
                _, playerClass = UnitClass("party"..i)
                break
              end
            end
            if not playerClass then
              for i = 1, GetNumRaidMembers() do
                if UnitName("raid"..i) == player then
                  _, playerClass = UnitClass("raid"..i)
                  break
                end
              end
            end
          end
          
          -- Add roll to cache
          local data = getRollData(name)
          if not data[rollType][player] then
            data[rollType][player] = playerClass or true
            data.timestamp = GetTime()
            updateFrames()
          end
          return true
        end
      end
      return true
    end
  end
  return false
end

-- Update all roll frames
updateFrames = function()
  for i = 1, 4 do
    local frame = getglobal("SmallGroupLootFrame"..i)
    if frame and frame:IsVisible() then
      -- Get item for this frame
      local itemName
      if frame.rollID and rollIdToItem[frame.rollID] then
        itemName = rollIdToItem[frame.rollID]
      end
      
      if itemName and rollCache[itemName] then
        -- Count players for each roll type
        local counts = {Need = 0, Greed = 0, Pass = 0}
        for rollType in pairs(counts) do
          for _ in pairs(rollCache[itemName][rollType]) do
            counts[rollType] = counts[rollType] + 1
          end
        end
        
        -- Update button counters
        local buttons = {
          Need = getglobal("SmallGroupLootFrame"..i.."RollButton"),
          Greed = getglobal("SmallGroupLootFrame"..i.."GreedButton"),
          Pass = getglobal("SmallGroupLootFrame"..i.."PassButton")
        }
        
        for rollType, button in pairs(buttons) do
          if button then
            getCounter(button, rollType):SetText(counts[rollType] > 0 and counts[rollType] or "")
            
            -- Hook tooltip if not already done
            if not button.hooked then
              button.rollType = rollType
              button.frameIndex = i
              
              button:SetScript("OnEnter", function()
                local f = getglobal("SmallGroupLootFrame"..this.frameIndex)
                if not f then return end
                
                local iName
                if f.rollID and rollIdToItem[f.rollID] then
                  iName = rollIdToItem[f.rollID]
                end
                
                if not iName or not rollCache[iName] then return end
                
                GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(this.rollType .. ":")
                
                local hasPlayers = false
                for name, class in pairs(rollCache[iName][this.rollType]) do
                  GameTooltip:AddLine(class and type(class) == "string" and 
                                      classColors[class] and 
                                      classColors[class]..name.."|r" or name)
                  hasPlayers = true
                end
                
                if not hasPlayers then
                  GameTooltip:AddLine("None", 0.7, 0.7, 0.7)
                end
                
                GameTooltip:Show()
              end)
              
              button:SetScript("OnLeave", function()
                GameTooltip:Hide()
              end)
              
              button.hooked = true
            end
          end
        end
      end
    end
  end
end

-- Clean up old data
local function cleanupData()
  local currentTime = GetTime()
  for itemName, data in pairs(rollCache) do
    if (currentTime - data.timestamp) > 60 then
      rollCache[itemName] = nil
    end
  end
end

-- Process events
addon:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "SmallerRollFrames_RollCount" then
    -- Ensure saved settings exist with proper structure
    if not SRF_RC_Settings.positions then
      SRF_RC_Settings.positions = {
        Need = {x = 0, y = 0},
        Greed = {x = 0, y = 1},
        Pass = {x = 0, y = -1}
      }
    end
    
    -- Apply saved settings
    counterPositions = SRF_RC_Settings.positions
    
    -- Hook SmallerRollFrames command
    hookOriginalCommand()
    
    updateFrames()
  elseif event == "START_LOOT_ROLL" then
    local rollID = arg1
    local _, itemName = GetLootRollItemInfo(rollID)
    
    if itemName then
      rollIdToItem[rollID] = itemName
      getRollData(itemName)
      
      -- Small delay to ensure frames are created
      local delay = CreateFrame("Frame")
      delay:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed > 0.2 then
          updateFrames()
          this:SetScript("OnUpdate", nil)
        end
      end)
    end
  elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM" then
    processRoll(arg1)
  end
end)

-- Periodic cleanup
local timer = 0
addon:SetScript("OnUpdate", function()
  timer = timer + arg1
  if timer >= 10 then
    timer = 0
    cleanupData()
  end
end)
