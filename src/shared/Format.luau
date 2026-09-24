-- Number / time formatting helpers shared by server and client.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.number(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local text = if n == math.floor(n) then tostring(n) else string.format("%.1f", n)
		return (if negative then "-" else "") .. text
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	if scaled >= 999.995 and tier < #SUFFIXES - 1 then
		-- Would round up to "1000K"; show "1M" instead.
		tier += 1
		scaled /= 1000
	end
	local text = string.format("%.2f", scaled):gsub("%.?0+$", "")
	return (if negative then "-" else "") .. text .. SUFFIXES[tier + 1]
end

-- 3725 -> "1h 2m", 65 -> "1m 5s"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.percent(fraction: number): string
	local pct = fraction * 100
	if pct >= 10 then
		return string.format("%d%%", math.floor(pct + 0.5))
	elseif pct >= 1 then
		return string.format("%.1f%%", pct)
	end
	return string.format("%.2f%%", pct)
end

return Format
