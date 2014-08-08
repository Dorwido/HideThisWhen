-----------------------------------------------------------------------------------------------
-- Client Lua Script for HideThisWhen
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- HideThisWhen Module Definition
-----------------------------------------------------------------------------------------------
local HideThisWhen = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

local function print_r (t, indent, done)
  done = done or {}
  indent = indent or ''
  local nextIndent -- Storage for next indentation value
  for key, value in pairs (t) do
    if type (value) == "table" and not done [value] then
      nextIndent = nextIndent or
          (indent .. string.rep(' ',string.len(tostring (key))+2))
          -- Shortcut conditional allocation
      done [value] = true
      Print (indent .. "[" .. tostring (key) .. "] => Table {");
      Print  (nextIndent .. "{");
      print_r (value, nextIndent .. string.rep(' ',2), done)
      Print  (nextIndent .. "}");
    else
      Print  (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."")
    end
  end
end

function HideThisWhen:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

    return o
end

function HideThisWhen:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

function HideThisWhen:OnSave(eType)
  -- eType is one of:
  -- GameLib.CodeEnumAddonSaveLevel.General
  -- GameLib.CodeEnumAddonSaveLevel.Account
  -- GameLib.CodeEnumAddonSaveLevel.Realm
  -- GameLib.CodeEnumAddonSaveLevel.Character
 
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
    return self.windowManager
  end

  if eType == GameLib.CodeEnumAddonSaveLevel.General then
    return self.presets
  end


end

function HideThisWhen:OnRestore(eType, tSavedData)
  if eType == GameLib.CodeEnumAddonSaveLevel.Character then
	self.windowManager = tSavedData
	--local windowCombo = self.wndMain:FindChild("WindowChooseCombo")

	
    --for k,v in pairs(tSavedData) do
    --  addon_settings[k] = v
    --end
  end
  if eType == GameLib.CodeEnumAddonSaveLevel.General then
    self.presets = tSavedData  
  end



	self:GenerateWatchList()
end


-----------------------------------------------------------------------------------------------
-- HideThisWhen OnLoad
-----------------------------------------------------------------------------------------------
function HideThisWhen:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("HideThisWhen.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- HideThisWhen OnDocLoaded
-----------------------------------------------------------------------------------------------
function HideThisWhen:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "HideThisWhenForm", nil, self)
		self.wndAdd = Apollo.LoadForm(self.xmlDoc, "HideThisWhenAdd", nil, self)
		
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		Apollo.RegisterEventHandler("WindowManagementReady", "OnWindowManagementReady", self)
		Apollo.RegisterEventHandler("UnitEnteredCombat","OnUnitCombat",self)
	    self.wndMain:Show(false, true)
		self.wndAdd:Show(false,true)
		
		self.listenerActive = false
		self.curWindow = nil
		self.curSubWindow = nil
		self.ZoneListGrid = self.wndMain:FindChild("ZoneListGrid")
		self.ZoneListToId = {}
		self.selectedWindow = self.wndAdd:FindChild("SelectedWindow")
		self.comboWindow = self.wndMain:FindChild("WindowChooseCombo")
		if (self.windowManager == nil) then
			self.windowManager = {}
		end
		if (self.presets == nil) then
			self.presets = {}
		end

		local windowCombo = self.wndMain:FindChild("WindowChooseCombo")
		for k,_ in pairs (self.windowManager) do
			windowCombo:AddRow(k)	
		
		end
		self.presetMode = false
		--self.windowManager = {}
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("SubZoneChanged", "OnZoneChange", self)
		Apollo.RegisterSlashCommand("htw", "OnHideThisWhenOn", self)
		Apollo.RegisterSlashCommand("htwadd", "OnHideThisWhenAdd", self)
		
		

		-- Do additional Addon initialization here
	end
end



function HideThisWhen:OnWindowManagementReady()
    Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = "HideThisWhenConfig"})
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndAdd, strName = "HideThisWhenAddWindow"})
	self:PopulateZoneGrid()

	self:OnUnitCombat(GameLib.GetPlayerUnit(),GameLib.GetPlayerUnit():IsInCombat())
	self:OnZoneChange()

end


function HideThisWhen:GenerateWatchList()
	self.watchList = {CombatShow={},CombatHide={},zones={}}
	if not self.windowManager then
		return
	end
	for k,v in pairs(self.windowManager) do
		if(v["combat"]) then
		--showincombat
			if (v["combat"]==1) then
				 table.insert(self.watchList["CombatShow"],k) 
			elseif(v["combat"]==2) then
				 table.insert(self.watchList["CombatHide"],k)
			
			end
		end
		
		if(v["zonemode"] and (v["zonemode"]==1 or v["zonemode"]==2)) then
			local boolchange = false
			if(v["zonemode"]==2) then
				boolchange = true
			end
			
			
			
			if(v["zones"]) then
			
				
				for kz,vz in pairs(v["zones"]) do
					local toshow = false
					if(vz==true) then
						toshow = true	
					end
					if(boolchange==true) then
					 	toshow = not toshow
					end
					if not self.watchList["zones"][kz] then
						self.watchList["zones"][kz]={}
							
					end	
					self.watchList["zones"][kz][k]=toshow
								
				end
			end
		end
	end
end

function HideThisWhen:OnUnitCombat(unit,enter)
	
	if(unit:IsThePlayer()) then
		if (enter) then
			for _,v in ipairs(self.watchList.CombatShow) do
				local window = Apollo.FindWindowByName(v) 
				if(window) then
					window:Show(true)
				end
				--Apollo.FindWindowByName(v):Show(true)
			end
			for _,v in ipairs(self.watchList.CombatHide) do
				local window = Apollo.FindWindowByName(v) 
				if(window) then
					window:Show(false)
				end
				
			end

		else
			for _,v in ipairs(self.watchList.CombatShow) do
				local window = Apollo.FindWindowByName(v) 
				if(window) then
					window:Show(false)
				end

				
			end
			for _,v in ipairs(self.watchList.CombatHide) do
				local window = Apollo.FindWindowByName(v) 
				if(window) then
					window:Show(true)
				end
			end
		end
	
	end
end

function HideThisWhen:OnZoneChange()
	local currentmap =GameLib.GetCurrentZoneMap()
	--Print(currentmap.id)
	if(currentmap.id) then
		if(self.watchList["zones"][currentmap.id]) then
			for k,v in pairs(self.watchList["zones"][currentmap.id]) do
				local window = Apollo.FindWindowByName(k) 
				if(window) then
					window:Show(v)
				end

			end
		end
	end
	
end
-----------------------------------------------------------------------------------------------
-- HideThisWhen Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/htw"
function HideThisWhen:OnHideThisWhenOn()
	
	

	self.wndMain:Invoke() -- show the window
end

function HideThisWhen:PopulateZoneGrid()
--	self.ZoneListGrid
	local zones = g_wndTheZoneMap:GetAllZoneInfo()
	
	local i = 1
	for k,v in ipairs(zones) do
		--Print (v["strName"]..v["id"].."-"..v["parentZoneId"])
		--SetCellText
		self.ZoneListGrid:AddRow(v["strName"])
		local zoneData = {}
		zoneData.selected = false
		zoneData.id = v["id"]
		self.ZoneListGrid:SetCellLuaData(i,1,zoneData)
		--self.ZoneListGrid:SetCellImage(row,col,"achievements:sprAchievements_Icon_Complete")
		--self.ZoneListToId[v["strName"]] = v["id"]
		i=i+1
		--	
	end

end

function HideThisWhen:OnHideThisWhenAdd()
	local zones = g_wndTheZoneMap:GetAllZoneInfo()
	--GameLib.GetCurrentZoneMap
--	print_r(self.watchList)
self:OnZoneChange()
end

local function GetParentWindow(window)
	local lastwindow = window
	if(window:GetParent()~=nil) then
		 local curwindow = window:GetParent()
		 --while curwindow:GetParent()~=nil do
		repeat
			lastwindow = curwindow
			curwindow = curwindow:GetParent()
		until curwindow==nil
		
		
	end
	return  lastwindow

end

function HideThisWhen:GetCurrentWindowTimer()
	
	local window = Apollo.GetMouseTargetWindow()
	if(window~=nil) then
		if (window == self.curSubWindow) then
			return
		end	
		local parentWindow = GetParentWindow(window)
		if (parentWindow == self.curWindow) then
			return
		end
		self.curSubWindow = window
		self.curWindow = parentWindow
		self.selectedWindow:SetText(parentWindow:GetName())
		--Print(parentWindow:GetName())

	end
end


function HideThisWhen:SelectWindow()
	Print("waahw")
end

-----------------------------------------------------------------------------------------------
-- HideThisWhenForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function HideThisWhen:OnOK()
	self.wndMain:Close() -- hide the window
	self:OnUnitCombat(GameLib.GetPlayerUnit(),GameLib.GetPlayerUnit():IsInCombat())
	self:OnZoneChange()
end

-- when the Cancel button is clicked
function HideThisWhen:OnCancel()
	self.wndMain:Close() -- hide the window
end


function HideThisWhen:OnAddNewWindow()
	self.wndAdd:FindChild("ChoosePresetCombo"):DeleteAll()
	for k,_ in pairs(self.presets) do
		self.wndAdd:FindChild("ChoosePresetCombo"):AddItem(k)
	end
	
	if not (self.listenerTimer) then
		self.listenerTimer = ApolloTimer.Create(0.1,true,"GetCurrentWindowTimer",self)
	else
		self.listenerTimer:Start()
	end

	Apollo.RegisterEventHandler("SystemKeyDown","OnSystemKeyDown",self)
	self.wndMain:Close()
	self.wndAdd:Invoke()
	
end

function HideThisWhen:OnGridSelChange(grid,col)
	self.windowChoice = self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]
	self.wndMain:FindChild("Options"):Show(true)
	self.wndMain:FindChild("CombatWindow"):SetRadioSel("combat_RadioGroup",self.windowChoice["combat"])
	self.wndMain:FindChild("ZoneWindow"):SetRadioSel("zone_RadioGroup",self.windowChoice["zonemode"])
	--todo add zone option show/hide
	for i=1,self.ZoneListGrid:GetRowCount() do
		local zoneData = self.ZoneListGrid:GetCellLuaData(i,1)
		if (not self.windowChoice["zones"] or not self.windowChoice["zones"][zoneData.id] or  self.windowChoice["zones"][zoneData.id]==false) then
			zoneData.selected = false
			self.ZoneListGrid:SetCellLuaData(i,1,zoneData)
			self.ZoneListGrid:SetCellImage(i,1,"")
		else
			zoneData.selected = true
			self.ZoneListGrid:SetCellLuaData(i,1,zoneData)
			self.ZoneListGrid:SetCellImage(i,1,"achievements:sprAchievements_Icon_Complete")
		
		end	
	end
	
end

function HideThisWhen:OnCombatClick( wndHandler, wndControl, eMouseButton )
	--Print("jo")
	--Print(wndControl:GetRadioSel("combat_RadioGroup"))
	--0 nothing 1 show 2 hide
	local wcheck = self.wndMain:FindChild("CombatWindow"):GetRadioSel("combat_RadioGroup")
	--Print(self.comboWindow:GetCurrentRow())
	--if not(self.windowManager[self.comboWindow:GetCurrentRow()]["combat"]) then
	-- 	self.windowManager[self.comboWindow:GetCurrentRow()]["combat"] = {}
	--end
	if(self.presetMode==false) then
		self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]["combat"] = wcheck
		self:GenerateWatchList()
	else
		self.presets[self.wndMain:FindChild("WindowChoosePresetCombo"):GetCellText(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow())]["combat"]=wcheck
	end

	
end

function HideThisWhen:DeleteWindow( wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if(self.presetMode == false) then
		local currentRow = self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())
		self.comboWindow:DeleteRow(self.comboWindow:GetCurrentRow())
		self.windowManager[currentRow] = nil
		self:GenerateWatchList()
		self.comboWindow:SetCurrentRow(-1)
	else
		local currentRow = self.wndMain:FindChild("WindowChoosePresetCombo"):GetCellText(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow())
		self.wndMain:FindChild("WindowChoosePresetCombo"):DeleteRow(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow())
		self.presets[currentRow] = nil
		self.wndMain:FindChild("WindowChoosePresetCombo"):SetCurrentRow(-1)
	
	end
	self.wndMain:FindChild("Options"):Show(false)

end

function HideThisWhen:UpdateAllZones(currentWindow)
	if (self.presetMode==false) then
		if(not self.windowManager[currentWindow]["zones"]) then
			self.windowManager[currentWindow]["zones"] = {}
		end
		for i=1,self.ZoneListGrid:GetRowCount() do
			local zoneData =self.ZoneListGrid:GetCellLuaData(i,1)
			if(not zoneData.selected or zoneData.selected == false) then
				self.windowManager[currentWindow]["zones"][zoneData.id] = false
			else
				self.windowManager[currentWindow]["zones"][zoneData.id] = true
			end
		end	
		self:GenerateWatchList()
	else
		if(not self.presets[currentWindow]["zones"]) then
			self.presets[currentWindow]["zones"] = {}
		end
		for i=1,self.ZoneListGrid:GetRowCount() do
			local zoneData =self.ZoneListGrid:GetCellLuaData(i,1)
			if(not zoneData.selected or zoneData.selected == false) then
				self.presets[currentWindow]["zones"][zoneData.id] = false
			else
				self.presets[currentWindow]["zones"][zoneData.id] = true
			end
		end	
		
	end
end

function HideThisWhen:OnZoneGridSelChange( wndHandler, wndControl,row,col)
	--self.ZoneListGrid:SelectCell(1,1)
	--self.ZoneListGrid:SelectCell(2,1)
	--self.ZoneListGrid:SelectCell(3,1)
	--local _,img = self.ZoneListGrid:GetItemData(row,col)
--	Print(img)
	local zoneData = self.ZoneListGrid:GetCellLuaData(row,col)
	if(zoneData.selected == false) then
		self.ZoneListGrid:SetCellImage(row,col,"achievements:sprAchievements_Icon_Complete")
		zoneData.selected = true
		
	else
		self.ZoneListGrid:SetCellImage(row,col,"")
		zoneData.selected = false

	end
	--if(not self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]["zones"]) then
		--self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]["zones"] = {}
	--end
	--self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]["zones"][zoneData.id] = zoneData.selected
	self.ZoneListGrid:SetCellLuaData(row,col,zoneData)
	if(self.presetMode==false) then
		self:UpdateAllZones(self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow()))
	else
		self:UpdateAllZones(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCellText(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow()))

	end

	
	
end

function HideThisWhen:OnZone_RadioGroupClick( wndHandler, wndControl, eMouseButton )

	local wcheck = self.wndMain:FindChild("ZoneWindow"):GetRadioSel("zone_RadioGroup")
	--Print(self.comboWindow:GetCurrentRow())
	--if not(self.windowManager[self.comboWindow:GetCurrentRow()]["combat"]) then
	-- 	self.windowManager[self.comboWindow:GetCurrentRow()]["combat"] = {}
	--end
	if(self.presetMode==false) then
		self.windowManager[self.comboWindow:GetCellText(self.comboWindow:GetCurrentRow())]["zonemode"] = wcheck
		self:GenerateWatchList()
	else
		self.presets[self.wndMain:FindChild("WindowChoosePresetCombo"):GetCellText(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow())]["zonemode"]=wcheck
	end	
	--todo do zonechekc


end

function HideThisWhen:OnSwitchToPresetButtonClick( wndHandler, wndControl, eMouseButton )
	wndHandler:GetParent():Show(false)
	local presetCombo = self.wndMain:FindChild("WindowChoosePresetCombo")
	presetCombo:DeleteAll()
	for k,_ in pairs(self.presets) do
		presetCombo:AddRow(k)		
	end
	self.presetMode = true
	self.wndMain:FindChild("UpperWindowPresetMode"):Show(true)
end

function HideThisWhen:OnSwitchToHideButtonClick( wndHandler, wndControl, eMouseButton )
	wndHandler:GetParent():Show(false)
	self.wndMain:FindChild("UpperWindowHideMode"):Show(true)
	self.presetMode = false
	self.comboWindow:SetCurrentRow(-1)
	self.wndMain:FindChild("Options"):Show(false)
end

function HideThisWhen:OnAddNewPreset( wndHandler, wndControl, eMouseButton )
	--Print("preser")
	self.wndMain:FindChild("AddNewPresetForm"):Show(true)
	self.wndMain:FindChild("NewPresetEditBox"):SetFocus()
end

function HideThisWhen:OnCancelAddPresetButton( wndHandler, wndControl, eMouseButton )
	wndHandler:GetParent():Show(false)
end

function HideThisWhen:OkAddPresetButton( wndHandler, wndControl, eMouseButton )
	local presetName=wndHandler:GetParent():FindChild("NewPresetEditBox"):GetText()
	if not self.presets[presetName] then
		self.presets[presetName] = {}
		self.wndMain:FindChild("WindowChoosePresetCombo"):AddRow(presetName)
		
	end
	wndHandler:GetParent():FindChild("NewPresetEditBox"):SetText("")

	wndHandler:GetParent():Show(false)
end

function HideThisWhen:OnGridPresetSelChange()

	self.windowPresetChoice = self.presets[self.wndMain:FindChild("WindowChoosePresetCombo"):GetCellText(self.wndMain:FindChild("WindowChoosePresetCombo"):GetCurrentRow())]
	self.wndMain:FindChild("Options"):Show(true)
	self.wndMain:FindChild("CombatWindow"):SetRadioSel("combat_RadioGroup",self.windowPresetChoice["combat"])
	self.wndMain:FindChild("ZoneWindow"):SetRadioSel("zone_RadioGroup",self.windowPresetChoice["zonemode"])
	--todo add zone option show/hide
	for i=1,self.ZoneListGrid:GetRowCount() do
		local zoneData = self.ZoneListGrid:GetCellLuaData(i,1)
		if (not self.windowPresetChoice ["zones"] or not self.windowPresetChoice ["zones"][zoneData.id] or  self.windowPresetChoice ["zones"][zoneData.id]==false) then
			zoneData.selected = false
			self.ZoneListGrid:SetCellLuaData(i,1,zoneData)
			self.ZoneListGrid:SetCellImage(i,1,"")
		else
			zoneData.selected = true
			self.ZoneListGrid:SetCellLuaData(i,1,zoneData)
			self.ZoneListGrid:SetCellImage(i,1,"achievements:sprAchievements_Icon_Complete")
		
		end	
	end



end

---------------------------------------------------------------------------------------------------
-- HideThisWhenAdd Functions
---------------------------------------------------------------------------------------------------

function HideThisWhen:OnWindowAddClose( wndHandler, wndControl, eMouseButton )
	Apollo.RemoveEventHandler("SystemKeyDown",self)
	self.listenerTimer:Stop()

	self.wndAdd:Close()
	self.wndMain:Invoke()
end

function HideThisWhen:OnSystemKeyDown(key)
	if(key==17) then
		--Print(Apollo.GetMouseTargetWindow():GetName())
		if(self.curWindow~=nil) then
			local windowCombo = self.wndMain:FindChild("WindowChooseCombo")
			--local currentSelection = windowCombo:GetCurrentRow()
			local rowCount = windowCombo:GetRowCount()
			if(rowCount>0) then
				for i=1,rowCount do
					--windowCombo:SetCurrentRow(i)
					if(windowCombo:GetCellText(i)==self.curWindow:GetName()) then
						Print("That window is already in the list")
						--if(currentSelection ~= nil) then
							--windowCombo:SetCurrentRow(currentSelection)
						--end
						return
					end		
					
				end
			end
			Print("Window added")
			windowCombo:AddRow(self.curWindow:GetName())
			windowCombo:SetCurrentRow(-1)
			self.windowManager[self.curWindow:GetName()]= {}
			local seltext = self.wndAdd:FindChild("ChoosePresetCombo"):GetSelectedText()
			if(seltext and self.presets[seltext]) then
				self.windowManager[self.curWindow:GetName()] = self.presets[seltext]
			end
--			self.wndMain:FindChild("CombatWindow"):SetRadioSel("combat_RadioGroup",0)
--			self.wndMain:FindChild("Options"):Show(true)

		--	self:OnWindowAddClose()
		--self.wndMain:Invoke()	
		end	
	end

end


-----------------------------------------------------------------------------------------------
-- HideThisWhen Instance
-----------------------------------------------------------------------------------------------
local HideThisWhenInst = HideThisWhen:new()
HideThisWhenInst:Init()
