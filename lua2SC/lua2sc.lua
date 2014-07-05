-------------------------------------------------------------------------=---
-- Name:        Lua2SC
-- Purpose:     Lua2SC IDE
-- Author:      Victor Bombi
-- Created:     2012
-- Copyright:   (c) 2012 Victor Bombi. All rights reserved.
-- Licence:     wxWidgets licence
-------------------------------------------------------------------------=---

lanes=require("lanes")
lanes.configure({ nb_keepers = 1, with_timers = true, on_state_create = nil,track_lanes=true}) --,verbose_errors=true})
idlelinda= lanes.linda("idlelinda")
scriptlinda= lanes.linda("scriptlinda")
scriptguilinda= lanes.linda("scriptguilinda")
midilinda= lanes.linda("midilinda")
udpsclinda=lanes.linda("udpsclinda")
debuggerlinda=lanes.linda("debuggerlinda")
mainlinda=lanes.linda("mainlinda")
lindas = {idlelinda,scriptlinda,scriptguilinda,midilinda,udpsclinda,debuggerlinda,mainlinda}


require"lfs"

-----------------extracted from penligth (Steve Donovan)
local is_windows = package.config:sub(1,1) == '\\'
local function isabs(P)
	if is_windows then
		return P:sub(1,1) == '/' or P:sub(1,1)=='\\' or P:sub(2,2)==':'
	else
		return P:sub(1,1) == '/'
	end
end
local sep = is_windows and '\\' or '/'
path_sep = sep
local np_gen1,np_gen2 = '[^SEP]+SEP%.%.SEP?','SEP+%.?SEP'
local np_pat1, np_pat2 = np_gen1:gsub('SEP',sep) , np_gen2:gsub('SEP',sep)
local function normpath(P)
    if is_windows then
        if P:match '^\\\\' then -- UNC
            return '\\\\'..normpath(P:sub(3))
        end
        P = P:gsub('/','\\')
    end
    local k
    repeat -- /./ -> /
        P,k = P:gsub(np_pat2,sep)
    until k == 0
    repeat -- A/../ -> (empty)
        P,k = P:gsub(np_pat1,'')
    until k == 0
    if P == '' then P = '.' end
    return P
end
local function abspath(P)
	local pwd = lfs.currentdir()
	if not isabs(P) then
		P = pwd..sep..P
	elseif is_windows  and P:sub(2,2) ~= ':' and P:sub(2,2) ~= '\\' then
		P = pwd:sub(1,2)..P -- attach current drive to path like '\\fred.txt'
	end
	return normpath(P)
end
function splitpath(P)
	return P:match("(.+"..sep..")([^"..sep.."]+)")
end
----------------------------------------------
function SetLuaPath(arg)
	--print(arg[0],lfs.currentdir (),lfs.attributes(arg[0]).dev,debug.getinfo(2,"S").source)
	--print(abspath(arg[0]),splitpath(abspath(arg[0])))

	lua2scpath = splitpath(abspath(arg[0])) --.. sep
	_presetsDir = lua2scpath .. "presets" .. sep
	----_scscriptsdir = lua2scpath .."sc\\"
	-- .. lua2scpath .. "lua\\?\\init.lua;"
	local dllstr = is_windows and "dll" or "so"
	package.path = lua2scpath .. "lua" .. sep .. "?.lua;"  .. package.path 
	package.cpath = lua2scpath .. "luabin" .. sep .. "?." .. dllstr .. ";"  .. package.cpath
	print(package.path)
	print(package.cpath)
end

SetLuaPath(arg) 
require("pmidi")
print("pmidi",pmidi,pmidi.core)
require("sc.utils")
require("random") 	--not nedded here but to avoid lanes wx crash


require("osclua")
toOSC=osclua.toOSC
fromOSC=osclua.fromOSC

settings_defaults = {
	settings ={
		midiin={},
		midiout={},
		SCpath="",
		SC_SYNTHDEF_PATH="default",
		SC_PLUGIN_PATH={"default"},
		SC_UDP_PORT=57110,
		SC_AUDIO_DEVICE=""
	},
}
file_config = require"file_settings"
file_config:init(lua2scpath .. "settings.txt",settings_defaults)
local function strconcat(...)
	local str=""
	for i=1, select('#', ...) do
		str = str .. tostring(select(i, ...)) .. "\t"
	end
	str = str .. "\n"
	return str
	--return table.concat({...},'\t') .. "\n"
end
function thread_print(...)
	idlelinda:send("prout",{strconcat(...),false})
end
function thread_error_print(...)
	idlelinda:send("prout",{strconcat(...),true})
end
function MidiOpen(options)
	midilane = pmidi.gen(options.midiin, options.midiout, lanes ,scriptlinda,midilinda,{print=thread_print,
	prerror=thread_error_print,
	prtable=prtable,idlelinda = idlelinda})
end
function MidiClose()
	if midilane then
		midilane:cancel(0.1)
	end
end
require"oscfunc"
--SCUDP:init(file_config:load_table("settings"),true,udpsclinda) --with receive
SCSERVER = require"scserver"
--require"ide.ide"
require"ide.ide_lane"
idelane = ide_lane(lanes)

----------------------------------
MidiOpen(file_config:load_table("settings"))
require"scriptrun"
--lanes.timer(mainlinda,"wait",1,0)
--mainlinda:receive("wait")
--mainlinda:send("ScriptRun",{typerun=2,script=[[C:\LUA\lua2sc\test\SSSSS.lua]]})
print"going into mainloop"
while true do
	local key,val = mainlinda:receive("sendsc","initsc","closesc","MidiClose","MidiOpen","ide_exit","ScriptRun","CancelScript","GetScriptLaneStatus")
	if val then
		if key == "initsc" then
			SCSERVER:init(val[1],val[2],udpsclinda)
		elseif key == "closesc" then
			SCSERVER:close()
		elseif key == "sendsc" then
			SCSERVER:send(val)
		elseif key == "MidiClose" then
			MidiClose() 
		elseif key == "MidiOpen" then
			MidiOpen(val)
		elseif key == "ScriptRun" then
			ScriptRun(val)
		elseif key == "CancelScript" then
			local res = CancelScript(val.timeout)
			val.tmplinda:send("CancelScriptResp",res)
		elseif key == "GetScriptLaneStatus" then
			val:send("GetScriptLaneStatusResp",script_lane.status)
		elseif key == "ide_exit" then
			print"ide_exit arrived"
			break
		end
	end
	--prtable(lanes.threads())
end
MidiClose()
print"exit: print lindas:"

for i,linda in ipairs(lindas) do
	print("linda",linda)
	prtable(linda:count(),linda:dump())
end
prtable(lanes.timers())
prtable(lanes.threads())

