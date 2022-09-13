Reader = {}
Reader.__index = Reader

function Reader:new(text)
	return setmetatable({text = text, index = 1, lineNum = 1}, self)
end
function Reader:peek(n, m)
	n = n or 1
	m = m or n
	return self.text:sub(self.index + n - 1, self.index + m - 1)
end
function Reader:read(n)
	n = n or 1
	local substr = self:peek(n)
	self.index = self.index + n
	
	local _, lines = substr:gsub("\n", "")
	self.lineNum = self.lineNum + lines
	
	return substr
end
function Reader:unread(v)
	if type(v) == "number" then
		local num = v
		
		self.index = self.index - num
		
		local _, lines = self:peek(num):gsub("\n", "")
		self.lineNum = self.lineNum - lines
	else
		local text = v
		
		self.text = text .. self.text:sub(self.index, #self.text)
		self.index = 1
		
		local _, lines = text:gsub("\n", "")
		self.lineNum = self.lineNum - lines
	end
end
function Reader:line()
	return self.lineNum
end
function Reader:copy()
	local new = setmetatable({}, getmetatable(self))
	for k, v in pairs(self) do
		new[k] = v
	end
	return new
end