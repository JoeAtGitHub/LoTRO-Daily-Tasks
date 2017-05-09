-- Helper function to work around the locale bug in Turbine's PluginData class
-- H.F. 20150202

function DT_LoadSettings(name,path)

    DT_Settings = Turbine.PluginData.Load(Turbine.DataScope.Server,path)
    if type(DT_Settings) ~= "table" then
	DT_Settings = {names=true, player={}, rep={} }
        print(name..", settings initialized.")
    else print(name..", settings loaded.") end

    if DT_Settings.names==nil then DT_Settings.names=true end -- default to true

    -- Now extract numbers from strings and strip session player names
    for k,v in pairs(DT_Settings.player) do
	if k:sub(1,1)=="~" then
	    -- Delete entry by setting it to nil
	    DT_Settings.player[k] = nil
	else
	    if type(v)=="string" then
	        local n = tonumber(v)
		-- if the string cannot be converted, the entry will be deleted
		-- by setting it to the nil result obtained from tonumber()
	        DT_Settings.player[k] = n
	    end
	end
    end

    return DT_Settings
end

function DT_SaveSettings(name,path)
    -- !!! requires DT_Settings to be visible
    -- Now convert numbers to strings
    for k,v in pairs(DT_Settings.player) do
	if type(v)=="number" then
	    local n = tostring(v)
	    if n~=nil then
	        DT_Settings.player[k] = n
	    end
	end
    end
    Turbine.PluginData.Save(Turbine.DataScope.Server,path,DT_Settings)
    print(name..", settings saved.")
end
