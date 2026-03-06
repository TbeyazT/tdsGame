local append, concat, floor, abs = table.insert, table.concat, math.floor, math.abs
local num = {'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'}
local tens = {'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'}
local bases = {{floor(1e18), ' quintillion'}, {floor(1e15), ' quadrillion'}, {floor(1e12), ' trillion'},
{floor(1e9), ' billion'}, {1000000, ' million'}, {1000, ' thousand'}, {100, ' hundred'}}

local insert_word_AND = false

local function IntegerNumberInWords(n)
	n = tonumber(n)
	if n then
		local str = {}
		if n < 0 then
			append(str, "minus")
		end
		
		n = floor(abs(n))
		if n == 0 then
			return "zero"
		end
		if n >= 1e21 then
			append(str, "infinity")
		else
			local AND
			for _, base in ipairs(bases) do
				local value = base[1]
				if n >= value then
					append(str, IntegerNumberInWords(n / value)..base[2])
					n, AND = n % value, insert_word_AND or nil
				end
			end
			if n > 0 then
				append(str, AND and "and")   -- a nice pun !
				append(str, num[n] or tens[floor(n/10)-1]..(n%10 ~= 0 and ' '..num[n%10] or ''))
			end
		end
		return concat(str, ' ')
	end
end

local module = {}

function module:IntegerNumberInWords(...)
    return IntegerNumberInWords(...)
end

function module:Round(num,places)
	local decimalPivot = 10^places
	return math.floor(num * decimalPivot + 0.5) / decimalPivot
end

return module