-- Daily Tasks reference plugin by David Down
-- coding: utf-8 'ä
import "Turbine"
import "Turbine.Gameplay"

function print(text) Turbine.Shell.WriteLine("<rgb=#00FFFF>DT:</rgb> "..text) end
RepOnly = false
Homestead = false

import "Vinny.Common"
import "Vinny.Common.EII_ID"
if false or (Turbine.Shell.IsCommand("conseil")) then -- French?
  import "Vinny.DailyTasks.DT_Data_FR"
  print("French data")
elseif (Turbine.Shell.IsCommand("zusatzmodule")) then -- German?
  import "Vinny.DailyTasks.DT_Data_DE"
  print("German data")
else import "Vinny.DailyTasks.DT_Data" end
import "Vinny.DailyTasks.DT_Locations"

local xpat = "<Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine>"
local xpat4 = "^(%d+) %[(.-)%] (%d+) (.+)$"
local xpat5 = "^(%d+) <Examine:IIDDID:0x0%x+:0x700(%x+)>%[(.-)%]<\\Examine> (%d+) (.+)$"
xlink = "<Examine:IIDDID:0x0000000000000000:0x700%s>[%s]<\\Examine>"
red,yel,grn = "FF0000", "FFFF00", "00FF00"
local snl,enl = " <rgb=#00FF00>(", ")</rgb>"
local Trophy = 207 -- Turbine.Gameplay.ItemCategory.?
local DT_list, pid = {}
all,dtu,dtx = true

function printh(text) print("<rgb=#00FF00>"..text.."</rgb>") end
function printe(text) print("<rgb=#FF6040>Error: "..text.."</rgb>") end
DT_Settings = Turbine.PluginData.Load(Turbine.DataScope.Server,"DailyTasks_Settings")
local DTv = "Daily Tasks "..Plugins["DailyTasks"]:GetVersion()
if type(DT_Settings) ~= "table" then
	DT_Settings = {names=true, player={}, rep={} }
    print(DTv..", settings initialized.")
else print(DTv..", settings loaded.") end
if DT_Settings.names==nil then DT_Settings.names=true end -- default to true
player = Turbine.Gameplay.LocalPlayer.GetInstance()
pname = player:GetName()
if pname:sub(1,1)=="~" then
	printe("Session Play detected.")
	return
end
local found = DT_Settings.player[pname]
plvl = player:GetLevel()
DT_Settings.player[pname] = plvl
if not found then print("Added player name, "..pname) end
if found~=plvl then
	Turbine.PluginData.Save(Turbine.DataScope.Server,"DailyTasks_Settings",DT_Settings)
end
if not DT_Settings.rep then DT_Settings.rep = {} end
DT_rep = Turbine.PluginData.Load(Turbine.DataScope.Character,"DailyTasks_Rep")
if DT_rep then
	print("Converting old rep data...")
	DT_Settings.rep[pname] = DT_rep
	Turbine.PluginData.Save(Turbine.DataScope.Character,"DailyTasks_Rep",false)
else DT_rep = DT_Settings.rep[pname] end
if not DT_rep then
	DT_rep = {}
	DT_Settings.rep[pname] = DT_rep
end

import "Vinny.DailyTasks.DT_Window"

if DT_Settings.auto then
	DTW_Command:Execute() -- Auto-open the window
end

Plugins.DailyTasks.Open = function(sender,args)
	DT_window:SetVisible( true )
end

DT_Command = Turbine.ShellCommand()
local help_text = "dt <link> (Get info on a task item)"
local help_details = [[Daily Tasks commands:
dt  (list task items)
dtu (list usable task items)
dtc (list complete task items)
dtj (list junk task items)
dtx (list unusable task items)
dtl (list task locations)
dtz (list task zones)
dtr (list reputation codes)
dtw (open DT window)
dtt (toggle item tracking)]]
function DT_Command:GetShortHelp() return help_text end
function DT_Command:GetHelp() return help_details end

function DT_Find(name)
	name = name:lower()
	for id,item in pairs(DT_Data.id) do
		if name==item.N:lower() then return id,item end
	end
end

function DT_Lvl(c,l,r)
	if type(l)=="table" then
		local ll = l.l
		if l.c then c = l.c end
		if l.r then r = l.r end
		return c,ll,r
	end
	local tl = DT_Data.lmap[l]
	if tl then l = tl	-- Remap task level?
	elseif l>60 then l = l-4	-- Dunland
	elseif l>50 then l=46 end -- Moria
	return c,l,r
end

function mob_lvl(t,zone)
	local s,d = " (",t.d
	s = s..t.l
	if t.d then
		if t.d>0 then s = s..DiffCode[t.d]
		else s = s.."<rgb=#00BB00>"..DiffCode[-t.d].."</rgb>" end
	end
	s = s..")"
	if zone then s = s.." in "..zones[t.z] end
	return t.n..s
end

function mob_drop(t,zone)
	local str = mob_lvl(t,zone).." may drop:"
	for ix,id in pairs(t.i) do
		str = str.." "..string.format(xlink,id,DT_Data.id[id].N)
	end
	print(str)
end

-- Sorting priority function for item locations; level, rep, alpha
local iloc
local function loc_comp(a,b)
	local al,bl = iloc[a],iloc[b]
	if type(al)=="table" then al = al.l end
	if type(bl)=="table" then bl = bl.l end
	if al~=bl then return al>bl end
	local ar = DT_Data.rz[a] or DT_Data.loc[a].rep
	local br = DT_Data.rz[b] or DT_Data.loc[b].rep
	local bd = br=="--"
	if ar=="--" then return bd and a<b end
	return bd or a<b
end

function DT_Print(id,item,nr,dtm)
    if dtx==2 then return 0 end
	local xname = string.format(xlink,id,item.N)
	local cnt,clr,av = 0,yel,false
	local C,min,alts = 10,999,""
	if item.C then C = item.C end
	if nr>=C then clr = grn end
	local str = string.format("<rgb=#%s>%2d/%2d</rgb> %s",clr,nr,C,xname)
	iloc = item.L
	local ix,nc,gr = {}, DT_Settings.nc, DT_Settings.gr and 0
	for loc in pairs(iloc) do
		if not (DT_Settings.MX and DT_Data.moriax[loc]) then
			table.insert(ix,loc)
		end
	end
	table.sort(ix,loc_comp)
	local rl,kr = {}, DT_Settings.rep[pname] or {}
	local ht,bb,bl = item.H
	for i,loc in ipairs(ix) do
		local lt = DT_Data.loc[loc]
		local rep = DT_Data.rz[loc] or lt.rep
		local c,ll,rep = DT_Lvl(C,iloc[loc],rep)
		if not (RepOnly and (rep=="--" or kr[rep]) or nc and lt and lt.nc) then
			c = c==C and "" or " /"..c
			if plvl<ll then clr = yel
			else clr = grn; av = true end
			if all or clr==grn or dtx then
				rl[rep] = true
				local cr = kr[rep] and "<rgb=#FF0000>"..rep.."</rgb>" or rep
				if Homestead then
				  if not ht then print("No Homestead data for "..item.N) return 0 end
				  for hl,hr in pairs(ht) do
				    if string.match(hr,rep) then
					  bl = math.ceil(hl/10)*10
					  bb = (bl-9).."-"..bl
					  local tl = math.floor(hl)
					  str = str..string.format(", <rgb=#%s>%d</rgb>%s @ %s(%s)",clr,tl,c,bb,cr)
					  break
					end
				  end
				else
				  str = str..string.format(", <rgb=#%s>%d</rgb>%s @ %s(%s)",clr,ll,c,loc,cr)
				end
			end
			if ll<min then min = ll end
		end
	end
	if av then
		if dtx then return 0 end
		cnt = math.floor(nr/C)
	end
	if RepOnly and not next(rl) then return 0 end
	if all or cnt>0 or dtx or (dtu and av) then
		if DT_Settings.names then
			for name,lvl in pairs(DT_Settings.player) do
				if name~=pname and lvl>=min then
					local kr = DT_Settings.rep[name]
					local add = not RepOnly or not kr
					if not add then
						for rep in pairs(rl) do
							add = add or not kr[rep]
						end
					end
					if add then alts = (alts=="" and snl or alts..", ")..name end
				end
			end
			if alts~="" then alts = alts..enl end
		end
		print(str..alts)
		if dtm then
			if pid then print(item.N.." = "..id)
			elseif item.m then
				print("<rgb=#00FF00>"..item.N.." may be dropped by:</rgb>")
				for ix in pairs(item.m) do
					print( mob_lvl(DT_Data.mob[ix],true) )
				end
			else print("No drop data found.") end
		end
		return cnt,true
	end
	return 0
end

-- Display a trophy item and/or add it to a list
function DT_Item(index,ti,dtm,cnt)
	local n,item = 0, type(index)=='table' and index or pack:GetItem(index)
	if item then
		local info = item:GetItemInfo()
		local name = info:GetName()
		local cat = info:GetCategory()
		local list = false
		if cat==Trophy and not DT_Data.inf[name] then
			local nr = cnt or item:GetQuantity()
			if not ti then
				local id,item = DT_Find(name)
				if id then n,list = DT_Print(id,item,nr,dtm)
				elseif all or dtx then
					list,item = true,nil
					print("<rgb=#FF6040>"..name.." has no known task use.</rgb>")
				end
				if list and DT_list then DT_list[index] = true end
			elseif ti[name] then
				local t = ti[name]
				if nr>t.n then t.x = index; t.i = item end
				t.n = t.n + nr
			else ti[name] = {n=nr,i=item,x=index} end
		else item = nil end
	end
	return n,item
end

function DT_Event(sender,args) DT_Item(sender,nil,pid) end

-- Check all the items in backpack or vault
function DT_Backpack(inv)
	DT_list = {}
	pack = inv or player:GetBackpack()
	local ti,cnt
	if inv then ti,cnt = nil, inv:GetCapacity()
	else ti,cnt = {}, pack:GetSize() end
	for i=0,cnt do DT_Item(i,ti) end
	return ti
end

function DT_Command:Execute( cmd,args,lvl )
	if args=="help" then
		print(help_details)
		return
	end
	all = cmd=="dt" or cmd=="dtm" or cmd=="dtv" or cmd=="dts"
	dtu = cmd=="dtu"
	dtx = cmd=="dtx"
	plvl = lvl or player:GetLevel()
	if cmd=="dtv" then
		local vault = player:GetVault()
		if vault:IsAvailable() then
			printh("Vault trophy items:")
			DT_Backpack(vault)
			DT_list = nil
		else printe("Vault not available.") end
		return
	end
	if cmd=="dts" then
		local shared = player:GetSharedStorage()
		if shared:IsAvailable() then
			printh("Shared Storage trophy items:")
			DT_Backpack(shared)
			DT_list = nil
		else printe("Shared Storage not available.") end
		return
	end
	if cmd=="dtd" then
		local ti = DT_Backpack()
		if not next(ti) then
			printe("No trophy items to check.") return end
		local store,label = player:GetSharedStorage(), "Shared Storage"
		if args=="v" then store,label = player:GetVault(), "Vault" end
		if store:IsAvailable() then
			printh("Duplicate "..label.." trophy items(B,S):")
			local si,cnt = {}, store:GetCapacity()
			DT_list,pack = {}, store
			for i=0,cnt do DT_Item(i,si) end
			for name,t in pairs(ti) do
				if si[name] then
					local id = DT_Find(name)
					local xname = id and string.format(xlink,id,name) or name
					print(xname.." = "..t.n..", "..si[name].n)
				end
			end
			DT_list = nil
		else printe(label.." not available.") end
		return
	end
	if cmd=="dtt" then
		pack = player:GetBackpack()
		local ti = DT_Backpack()
		if pack.ItemAdded then
			pack.ItemAdded = nil
			for name,d in pairs(ti) do
				d.i.QuantityChanged = nil
			end
			print("Item tracker disabled.")
		else
			pack.ItemAdded = function(sender,args)
				local n,item = DT_Item(args.Index,nil,pid)
				if item then item.QuantityChanged = DT_Event end
			end
			for name,d in pairs(ti) do
				d.i.QuantityChanged = DT_Event
			end
			print("Item tracker enabled.")
		end
		return
    end
    if args=="nc" then
    	local nc = not DT_Settings.nc
    	DT_Settings.nc = nc
    	print((nc and "Disabled" or "Enabled").." listing 'no completion' locations.")
    	return
    end
    if args=="gr" then
    	local gr = not DT_Settings.gr
    	DT_Settings.gr = gr
    	print((gr and "Enabled" or "Disabled").." Great River location consolidation.")
    	return
    end
	local str = all and "" or dtu and " that can be used" or " that can be turned in"
	if cmd=="dtj" then str = " that are junk"; dtx = 2
	elseif dtx then str = " that can't be used" end
	lvl = args:match("^(%d+)$")
	if lvl then
		plvl = tonumber(lvl)
		args = ""
	end
	if args=="" and cmd~="dtm" then
		if RepOnly then
			if str=="" then str = " that increase rep"
			else str = str.." and increase rep" end
		end
		printh("Backpack trophy items"..str..":")
		local tasks,ix,ti = 0, {}, DT_Backpack()
		for name in pairs(ti) do table.insert(ix,name) end
		table.sort(ix)
		for i,name in ipairs(ix) do
			local it = ti[name]
			tasks = tasks + DT_Item(it.x,nil,nil,it.n)
		end
		if not dtx then print(tasks.." tasks can be completed.") end
		return
	end
	local tb = DT_Data.loc[args]
	local kr = DT_Settings.rep[pname] or {}
	if tb then
		if cmd=="dtj" then printe("Illogical request!") return end
		local rep = DT_Data.loc[args].rep
		if kr[rep] then rep = "<rgb=#FF0000>"..rep.."</rgb>" end
		printh(string.format("Known trophies for %s(%s) @ %s (%s)%s",args,rep,tb.loc,tb.zone,str))
		local z = DT_Data.loc[args].zone
		if DT_Data.rz[z] then args = z end -- zone based items?
		local ix,loc = {}, {}
		for id,item in pairs(DT_Data.id) do
			if item.L[args] then
				table.insert(ix,item.N)
				loc[item.N] = id
			end
		end
		table.sort(ix)
		local tasks,ti = 0,DT_Backpack()
		for i,name in ipairs(ix) do
			local id = loc[name]
			local item = DT_Data.id[id]
			local xname = string.format(xlink,id,name)
			local cnt,ll,r = DT_Lvl(item.C or 10,item.L[args],rep)
			r = r==rep and "" or " ("..r..")"
			local clr = red
			local nr,it = 0, ti[name]
			if it then
				nr = it.n
				clr = nr>=cnt and grn or yel
			end
			local str = string.format("<rgb=#%s>%2d/%2d</rgb> %s",clr,nr,cnt,xname)
			clr = grn
			if plvl<ll then clr = yel end
			if all or clr==grn and (dtu or nr>=cnt and not dtx) or clr~=grn and dtx then
				if it then DT_list[it.x] = true end
				print(string.format("%s <rgb=#%s>%d</rgb>%s",str,clr,ll,r))
				if clr==grn then tasks = tasks+math.floor(nr/cnt) end
			end
		end
		if tasks>0 then print(tasks.." tasks can be completed.") end
		return
	end
    local id,name = args:match(xpat)
	if not id then id,name = Vinny.Common.EII_ID(args) end
    if id then
		local item = DT_Data.id[id]
        if not item then
			printe(name.." has no known task use.")
			return
		end
 		local nr = name:match("^(%d+) ")
		nr = nr and tonumber(nr) or 1
		DT_Print(id,item,nr,cmd=="dtm")
        return
    end
	local rep = DT_Data.rep[args]
	if rep then
		if cmd=="dtj" then printe("Illogical request!") return end
		if kr[args] then rep = "<rgb=#FF0000>"..rep.."</rgb>" end
		printh("Known trophies for reputation with "..rep..str)
		local tasks,ti = 0,DT_Backpack()
		for id,item in pairs(DT_Data.id) do
			local loc,cnt,ll,r
			for ln,l in pairs(item.L) do
				r = DT_Data.rz[ln] or DT_Data.loc[ln].rep
				cnt,ll,r = DT_Lvl(item.C or 10,l,r)
				if r==args and not DT_Data.moriax[ln] then loc = ln break end
			end
			if loc and (ti[item.N] or not RepOnly) then
				local xname = string.format(xlink,id,item.N)
				local clr = red
				local nr,it = 0, ti[item.N]
				if it then
					nr = it.n
					clr = nr>=cnt and grn or yel
				end
				local str = string.format("<rgb=#%s>%2d/%2d</rgb> %s",clr,nr,cnt,xname)
				clr = grn
				if plvl<ll then clr = yel end
				if all or clr==grn and (dtu or nr>=cnt and not dtx) or clr~=grn and dtx then
					if it then DT_list[it.x] = true end
					print(string.format("%s <rgb=#%s>%d</rgb> @ %s",str,clr,ll,loc))
					if clr==grn then tasks = tasks+math.floor(nr/cnt) end
				end
			end
		end
		if tasks>0 then print(tasks.." tasks can be completed.") end
		return
	end
	local id,item = DT_Find(args)
	if id then
		DT_Print(id,item,1,cmd=="dtm")
		return
	end
	if cmd=="dtm" then
		if args=="" then
			local target = player:GetTarget()
			if target then
				local name = target:GetName()
				for i,t in pairs(DT_Data.mob) do
					if t.n==name then
						mob_drop(t,true)
						return
					end
				end
				printe("Unknown mob, "..name)
				return
			else
				print("Mob difficulty codes (<rgb=#00BB00>green</rgb> for non-aggro):")
				local s = ""
				for i,code in ipairs(DiffCode) do
					if #s>1 then s = s..", " end
					s = s..code.."="..Diff[i]
				end
				print(s)
				return
			end
		end
		if args=="pid" then pid = not pid; print("pid="..tostring(pid)) return end
		local code = Zone[args]
		if code then
			printh("Known mobs with task trophy drops in "..args..":")
			for i,t in pairs(DT_Data.mob) do
				if t.z==code then mob_drop(t) end
			end
			return
		end
		local name = args:lower():gsub("%-","%%%-")
		name,c = name:gsub("*",".-")
		if c>0 then printh("Matches for the pattern '"..args.."':") end
		name = "^"..name.."$"
		local n = 0
		for i,t in pairs(DT_Data.mob) do
			if string.match(t.n:lower(),name) then
				mob_drop(t,true)
				if c==0 then return end
				n = n+1
			end
		end
		if n==0 then printe("Unknown, "..args) end
		return
	end
    print(help_text)
end

Turbine.Shell.AddCommand( "dt;dtu;dtc;dtd;dtx;dtt;dtj;dtm;dtv;dts",DT_Command )

-- Daily Task bag command

DTB_Command = Turbine.ShellCommand()
local help_text = "dtb <#> (Move listed items to bag)"
function DTB_Command:GetShortHelp() return help_text end
function DTB_Command:GetHelp() return help_text end


function DTB_Command:Execute( command,args )
	if not DT_list then
		print("Error: No item list has been displayed yet.")
		return
	end
    if args=="" then
        printh("Item list bag slots:")
        for i in pairs(DT_list) do
			local item = pack:GetItem(i)
			if item then
				local name = item:GetItemInfo():GetName()
				local bag,slot = math.floor((i+14)/15), math.fmod(i-1,15)+1
				print(string.format("Bag #%d, slot %d = %s",bag,slot,name))
			end
        end
        return
    end
	local cnt = player:GetBackpack():GetSize()
	local bag = args:match("^(%d)$")
	local nr = tonumber(bag)
	if not nr or nr<1 or nr>cnt/15 then
		print("Error: Invalid bag number.")
		return
	end
	print("Moving item list to bag #"..bag)
	local dest,last = nr*15, nr*15-14
	for i in pairs(DT_list) do
		local item = pack:GetItem(i)
		if item and math.floor((i+14)/15)~=nr then
			while pack:GetItem(dest) do
				dest = dest-1
				if dest<last then
					print("Warning: Move ended on full bag.")
					return
				end
			end
			pack:PerformItemDrop( item,dest,false )
			dest = dest-1
		end
	end
end

Turbine.Shell.AddCommand( "dtb",DTB_Command )

Plugins.DailyTasks.Unload = function(sender,args)
	pname = player:GetName()
	if pname:sub(1,1)=="~" then return end -- session play?
	DT_Settings.player[pname] = player:GetLevel()
    Turbine.PluginData.Save(Turbine.DataScope.Server,"DailyTasks_Settings",DT_Settings)
    print(DTv..", settings saved.")
end

-- Options panel
import "Vinny.Common.Options"
OP = Vinny.Common.Options_Init(print,DT_Settings,DT_window)

local Bag = Vinny.Common.Options_Box(OP,30," Default move to last bag")
if DT_Settings.bag then Bag:SetChecked(true) end
Bag.CheckedChanged = function( sender, args )
	DT_Settings.bag = sender:IsChecked()
	print((DT_Settings.bag and "En" or "Dis").."abled last bag.")
end

local MX = Vinny.Common.Options_Box(OP,50," Hide extra Moria locations")
if DT_Settings.MX then MX:SetChecked(true) end
MX.CheckedChanged = function( sender, args )
	DT_Settings.MX = sender:IsChecked()
	print((DT_Settings.MX and "En" or "Dis").."abled hide locs.")
end
