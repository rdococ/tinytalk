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

local Lexer = {}
Lexer.__index = Lexer

local function charSet(str, empty)
	local set = {}
	for i = 1, #str do
		set[str:sub(i, i)] = true
	end
	if empty then set[""] = true end
	return set
end

function Lexer:new(reader)
	return setmetatable({tokens = {}, index = 0, reader = reader}, self)
end
function Lexer:reset()
    self.tokens, self.index = {}, 0
    self.reader:reset()
end
function Lexer:peek()
    if self.tokens[self.index + 1] then return self.tokens[self.index + 1] end
    
    for _, case in ipairs(self.cases) do
        local token = case(self)
        if token == true then
            return self:peek()
        elseif token then
            self.tokens[self.index + 1] = token
            return token
        end
    end
    
    self:error("Expected valid token")
end
function Lexer:read()
    local token = self:peek()
    self.index = self.index + 1
    return token
end
function Lexer:line()
    return self.reader:line()
end
function Lexer:token(token)
    token.line = self:line()
    return token
end
function Lexer:error(err, ...)
    return error(("Line %s: %s"):format(self:line(), err:format(...)))
end

local whitespaceChars = charSet(" \r\n\t\"")

local numberStartChars = charSet("0123456789-")
local numberChars = charSet("0123456789")

local wordStartChars = charSet("abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ")
local msgopenStartChars = charSet("abcdefghijklmnopqrstuvwxyz_")
local msgnextStartChars = charSet("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
local wordNextChars = charSet("abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
local binopChars = charSet("+-*/%^<=>,")

local function strCase(str, type)
    return function (self)
        if self.reader:peek(1, #str) ~= str then return end
        self.reader:read(#str)
        return self:token {type = type}
    end
end
local function addCase(fn)
    table.insert(Lexer.cases, fn)
end

Lexer.cases = {}
addCase(function (self)
    if not numberStartChars[self.reader:peek()] then return end
    if self.reader:peek() == "-" and not numberChars[self.reader:peek(2)] then return end
    
    local value = self.reader:read()
    
    while numberChars[self.reader:peek()] do
        value = value .. self.reader:read()
    end
    
    if self.reader:peek() == "." and numberChars[self.reader:peek(2)] then
        value = value .. self.reader:read()
        while numberChars[self.reader:peek()] do
            value = value .. self.reader:read()
        end
    end
    
    value = tonumber(value)
    
    return self:token {type = "literal", value = value}
end)
addCase(function (self)
    if self.reader:peek() ~= "'" then return end
    self.reader:read()
    local value = ""
    
    while self.reader:peek() ~= "" and self.reader:peek() ~= "'" do
        if self.reader:peek() == "\\" then
            self.reader:read()
            value = value .. self.reader:read()
        else
            value = value .. self.reader:read()
        end
    end
    
    self.reader:read()
    
    return self:token {type = "literal", value = value}
end)
addCase(function (self)
    if not wordStartChars[self.reader:peek()] then return end
    local value = self.reader:read()
    
    while wordNextChars[self.reader:peek()] do
        value = value .. self.reader:read()
    end
    if self.reader:peek() == ":" then
        value = value .. self.reader:read()
        
        local char = value:sub(1, 1)
        if msgopenStartChars[char] then
            return self:token {type = "msgopen", value = value}
        end
        if msgnextStartChars[char] then
            return self:token {type = "msgnext", value = value}
        end
    end
    
    return self:token {type = "word", value = value}
end)
addCase(strCase("<-", "assign"))
addCase(function (self)
    if not binopChars[self.reader:peek()] then return end
    local value = self.reader:read()
    
    while binopChars[self.reader:peek()] do
        value = value .. self.reader:read()
    end
    
    return self:token {type = "binop", value = value}
end)
addCase(function (self)
    if not whitespaceChars[self.reader:peek()] then return end
    
    while whitespaceChars[self.reader:peek()] do
        local char = self.reader:read()
        if char == "\"" then
            while true do
                char = self.reader:read()
                if char == "" or char == "\"" then break end
            end
        end
    end
    
    return true
end)
addCase(function (self)
    if self.reader:peek() ~= "" then return end
    return self:token {type = "eof"}
end)
addCase(strCase("...", "objdeco"))
addCase(strCase("[", "objopen"))
addCase(strCase("|", "objnext"))
addCase(strCase("]", "objclose"))
addCase(strCase(".", "statclose"))
addCase(strCase("(", "expropen"))
addCase(strCase(")", "exprclose"))
addCase(strCase(":=", "define"))

return Lexer
