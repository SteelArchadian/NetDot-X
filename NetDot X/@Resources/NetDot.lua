-- NetDot X: ping display, host fallback, Cloudflare data-center change notice.
-- Runs once per skin update (1s). Only touches meters when something actually changed.

local FAILS_BEFORE_SWITCH = 3

function Initialize()
	hosts = { SKIN:GetVariable('PingHost', '1.1.1.1'), SKIN:GetVariable('AltHost', '1.0.0.1') }
	good = tonumber(SKIN:GetVariable('GoodLatency', '100')) or 100
	bad = tonumber(SKIN:GetVariable('BadLatency', '300')) or 300
	traceInterval = tonumber(SKIN:GetVariable('TraceInterval', '600')) or 600
	flashSeconds = tonumber(SKIN:GetVariable('ColoFlashSeconds', '30')) or 30

	ping = SKIN:GetMeasure('MeasurePing')
	trace = SKIN:GetMeasure('MeasureTrace')

	idx, fails, ticks = 1, 0, 0
	gotResult = false
	colo, flash = nil, 0
	shownText, shownColor, shownTip = nil, nil, nil
end

local function setHost(i)
	idx = i
	fails = 0
	SKIN:Bang('!SetOption', 'MeasurePing', 'DestAddress', hosts[i])
	SKIN:Bang('!SetOption', 'MeasureTrace', 'URL', 'https://' .. hosts[i] .. '/cdn-cgi/trace')
end

-- called by MeasureTrace's FinishAction
function OnTrace()
	local c = trace:GetStringValue()
	if not c or c == '' then return end
	if colo and c ~= colo then
		flash = flashSeconds -- location / VPN / route changed
	end
	colo = c
end

local function show(text, color)
	if text ~= shownText then
		shownText = text
		SKIN:Bang('!SetOption', 'MeterPingText', 'Text', text)
	end
	if color ~= shownColor then
		shownColor = color
		SKIN:Bang('!SetOption', 'MeterStatusDot', 'Shape', 'Ellipse 20,15,5,5 | Fill Color ' .. color .. ' | StrokeWidth 0')
	end
	local tip = 'Cloudflare ' .. (colo or '?') .. ' via ' .. hosts[idx]
	if tip ~= shownTip then
		shownTip = tip
		SKIN:Bang('!SetOption', 'MeterPingText', 'ToolTipText', tip)
	end
end

function Update()
	ticks = ticks + 1
	if flash > 0 then flash = flash - 1 end

	-- while on the fallback host, retry the primary once per trace interval
	if idx ~= 1 and ticks % traceInterval == 0 then setHost(1) end

	local v = ping:GetValue()

	if v < 0 then
		fails = fails + 1
		if fails >= FAILS_BEFORE_SWITCH then setHost(idx == 1 and 2 or 1) end
		show('Offline', '128,128,128,255')
		return v
	end

	fails = 0
	if v == 0 and not gotResult then
		show('Ping: ...', '128,128,128,255') -- first ping still in flight
		return v
	end
	gotResult = true

	local color
	if v < good then color = '0,255,0,255'
	elseif v < bad then color = '255,255,0,255'
	else color = '255,0,0,255' end

	local text = string.format('Ping: %d ms', v)
	if flash > 0 and colo then text = text .. ' - ' .. colo end
	show(text, color)
	return v
end
