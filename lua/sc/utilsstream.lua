function LoadPreset(file)
	local fich=io.open(_presetsDir..file..".prSC","r")
	assert(fich,"Could not open:".._presetsDir..file..".prSC")
	local str=fich:read("*a")
	fich:close()
	return assert(loadstring(str))()
end
function SavePreset(file,preset)
	local fich=io.open(_presetsDir..file..".prSC","w")
	assert(fich,"Could not open:".._presetsDir..file..".prSC")
	fich:write("local ")
	fich:write(serializeTable("preset",preset))
	fich:write("return preset ")
	fich:close()
end
function NamesAndValues(params)
	local parnames={}
	local parvalues={}
	for k,v in pairsByKeys(params) do
		parnames[#parnames +1]=k
		--to avoid streams multiexpand
		if type(v) == "table" then v = {v} end
		parvalues[#parvalues +1]=v
	end
	return parnames,parvalues
end
function UsePreset(preset,player)
	local pre=LoadPreset(preset)
	local preN,preV=NamesAndValues(pre.params)
	return player:MergeBind{[preN]=ConstSt(preV)}
end

function midi2freq(midi)
	if IsREST(midi) then return midi end
	return 440*(2^((midi - 69.0)/12.0))
end
function freq2midi(freq)
	if IsREST(freq) then return freq end
	return 12 * math.log(freq / 440) / math.log(2) + 69
end
function midi2ratio(int)
	return midi2freq(int)/midi2freq(0)
end
function ratio2midi(rat)
	return freq2midi(rat * midi2freq(0))
end

function dbamp(db)
	return 10^(db/20)
end
function MultLS(a,b)
			if type(b) ~= "table" then b={b} elseif type(a) ~= "table" then a={a} end
			local res =a
			for k,v in ipairs(a) do
				for k2,v2 in ipairs(b) do
					res[(k-1)*#b+k2] = v * v2
					--table.insert(res,v * v2)
				end
			end
			return res
end
--local mmt=getmetatable(ListStream) or {}
--ListStream.__mul=MultLS
-- ListStream.__add=function (a,b)
			--if type(b) ~= "table" then b={b} elseif type(a) ~= "table" then a={a} end
			-- local res =a.lista
			-- for k,v in ipairs(a.lista) do
				-- if type(res[k]) == "number" then
					-- res[k] = res[k] + b
				-- elseif res[k].argus then --fyncion
					-- for k2,v2 in ipairs(res[k].argus) do
						-- res[k].argus[k2] = res[k].argus[k2] + b
					-- end
				-- else -- tabla??
					-- for k2,v2 in ipairs(res[k]) do
						-- res[k][k2] = res[k][k2] + b
					-- end
				-- end
			-- end
			-- return a
-- end

--TODO remove
--function println(...)
--	print(...)
	--print("\n")
--end
--println=print




--Mults b times integer indexed items in t
function multtablaStream(t,b)
	if t.isStream then return (t*b) end
	local res={}
	for i,v in ipairs(t) do
		if type(v) == "string" then
			res[i]= v
		elseif type(v) ~="table" or v.nextval ~= nil then --no tabla o stream
			res[i]= v * b
		else										-- tabla
			res[i]=multtablaStream(v,b)
		end
	end 
	return res
end
--Sums b to integer indexed items in t
function addtablaStream(t,b)
	if t.isStream then return (t+b) end
	local res={}
	for i,v in ipairs(t) do
		if type(v) == "string" then
			res[i]= v
		elseif IsREST(v) then
			res[i]=v
		elseif type(v) ~="table" or v.isStream then --no tabla o stream
			res[i]= v + b
		else										-- tabla not stream
			res[i]=addtablaStream(v,b)
		end
	end 
	return res
end

-- {0,1, 0,0, 1,0, 0,0},{23,24},0.25 
function DursAndNotes(beats,notes,quant)
	quant = quant or 0.25
	local beatsG = {}
	local notesG = {}
	local currbeat = 1
	local currnote = 1
	local dur
	if beats[1] == 0 then notesG[1]=REST end
	for i=2,#beats do
		if beats[i]==1 then
			dur = (i - currbeat) * quant
			beatsG[#beatsG + 1] = dur

			notesG[#notesG + 1] = WrapAtSimple(notes,currnote) 
			
			currnote = currnote + 1
			currbeat = i
		end
	end
	--last
	dur = (#beats + 1 - currbeat) * quant
	beatsG[#beatsG + 1] = dur
	if beats[1] ~= 0 then notesG[#notesG + 1] = WrapAtSimple(notes,currnote)  end
	return beatsG,notesG
end
-------------------------------------------------------
_arittablemt={}
function AT(t)
	setmetatable(t,_arittablemt)
	return t
end
---[[
_arittablemt.__add=function (a,b)
	
	local t,t2 
	if type(a) == "table" then
		t=a;t2=b
	else
		t=b;t2=a
	end
	
	local res =AT{}
	for k,v in ipairs(t) do
		if type(t[k]) == "number" then
			res[k] = t[k] + t2
		elseif type(t[k]) == "table" then
			res[k]=_arittablemt.__add(t[k],t2)
		end
	end
	return res	
end
--]]
--[[
_arittablemt.__add=function (a,b)
	
	local t,t2 
	if getmetatable(a) == _arittablemt then
		t=a;t2=b
	else
		t=b;t2=a
	end
	println("_arittablemt.__add")
	prtable(t)
	prtable(t2)
	local res =AT{}
	for k,v in ipairs(t) do
		if isSimpleTable(t[k]) then
			res[k]=_arittablemt.__add(t[k],t2)
		else 
			res[k] = t[k] + t2
		end
	end
	return res	
end
--]]

--prtable(AT{1,{11,12},3}+AT{100,200})
_arittablemt.__mul=function (a,b)
	local t,t2 
	if type(a) == "table" then
		t=a;t2=b
	else
		t=b;t2=a
	end
	local res =AT{}
	for k,v in ipairs(t) do
		if type(t[k]) == "number" then
			res[k] = t[k] * t2
		elseif type(t[k]) == "table" then
			res[k]=_arittablemt.__mul(t[k],t2)
		end
	end
	return res	
end
--------------------------------------------------------
--add to a new keys in b
--without replacing
function mergeMissingList(a,b)
	for k,v in pairs(b) do
		if a[k] == nil then
			a[k]=v
		end
	end
	return a
end

--------------------------------------------
function clip(val,mini,maxi)
	return math.max(mini,math.min(val,maxi))
end
--dif should be less than maxi - mini
-- to avoid use clip before return or dif = dif%(max-min)
function wrapclip(val,mini,maxi)
	local dif = maxi - val
	if dif < 0 then return maxi + dif end
	local dif = val - mini
	if dif < 0 then return mini - dif end
	return val
end

function whitei(lohi)
	--return (lohi[2]-lohi[1])*RANDOM:value()+lohi[1]
	return RANDOM:valuei(lohi[1],lohi[2])
end
function noiseiStream(a)
	return FS(whitei,a,nil,-1)
end
function whitef(lohi)
	return (lohi[2]-lohi[1])*RANDOM:value()+lohi[1]
end
function noisefStream(a)
	return FS(whitef,a,nil,-1)
end
function brownNoiseGenerator(lo,hi,step,last)
	local last = last or whitef{lo,hi}
	return function()
		local res = whitef{-step,step}
		res = clip(last + res,lo,hi)
		last = res
		--print(res)
		return res
	end
end
function brownSt(lo,hi,step)
	return FS(brownNoiseGenerator(lo,hi,step),nil,nil,-1)
end
function Gauss(m,sd)
	return RANDOM:valueN() * sd + m
end
function exprand(media)
	return - math.log(1 - RANDOM:value())*media
end
--my version
function exprandrngV(lo,hi,inside)
	local inside = inside or 0.95
	return lo + hi*math.log(1 - RANDOM:value()*inside)/math.log(1-inside);
end
--from supercollider
function exprandrng(lo,hi)
	return lo * math.exp(math.log(hi / lo) * RANDOM:value());
end
function GaussStream(m,sd)
	return FS(function(t) return RANDOM:valueN()*t.sd+t.m end,{m=m,sd=sd},nil,-1)
end
function GaussStream2(m,sd,min,max)
	min=min or 0
	max=max or 1
	return FS(function(t) return clip(RANDOM:valueN()*t.sd+t.m,t.min,t.max) end,{m=m,sd=sd,min=min,max=max},nil,-1)
end

function Normalize(t)
	local sum = 0
	for i,v in ipairs(t) do
		sum = sum + v
	end
	for i,v in ipairs(t) do
		t[i] = v/sum
	end
	t.normalized=true
	return t
end

function wchoice(a,b)
	if not b then return choose(a) end
	if not b.normalized then Normalize(b) end
	local ra = RANDOM:value() --math.random()
	local sum =0
	local ind
	for i,v in ipairs(b) do
		if ra >= sum and ra < sum + v then 
			ind = i
			do break end
		end
		sum = sum + v
	end
	return a[ind]
end
