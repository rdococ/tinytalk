--[[
An implementation for a purely object-oriented toy programming language.
Copyright (C) 2022-2023 rdococ

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]

local StringReader = {}
StringReader.__index = StringReader

function StringReader:new(text)
	return setmetatable({text = text, index = 1, lineNum = 1}, self)
end
function StringReader:peek(n, m)
	n = n or 1
	m = m or n
	return self.text:sub(self.index + n - 1, self.index + m - 1)
end
function StringReader:read(n)
	n = n or 1
	local substr = self:peek(n)
	self.index = self.index + n
	
	local _, lines = substr:gsub("\n", "")
	self.lineNum = self.lineNum + lines
	
	return substr
end
function StringReader:line()
    return self.lineNum
end
function StringReader:reset()
    self.index, self.lineNum = 1, 1
end

return StringReader