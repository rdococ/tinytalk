--[[
An implementation for a purely object-oriented toy programming language.
Copyright (C) 2022 rdococ

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

local Compiler = {}
Compiler.__index = Compiler

function Compiler:compile(term)
    local self = setmetatable({}, self)
    return ([[local function newStack()
    local self, stack, len = {}, {}, 0
    function self.push(v) stack[len + 1] = v; len = len + 1 end
    function self.pop() if len < 1 then error("Value stack pop on empty") end local v = stack[len]; stack[len] = nil; len = len - 1; return v end
    function self.peek(n) return stack[len - (n or 0)] end
    function self.len() return len end
    function self.unpack() return unpack(stack, 1, len) end
    return self
end; %s; %s; local result = stack.pop(); if stack.len() > 0 then error("Value stack not empty at end") end; return result]]):format(self:newStack(), self:compileTerm(term))
end
function Compiler:compileTerm(term)
    return self.cases[term.type](self, term)
end

function Compiler:newStack()
    return [[local stack, frames = newStack(), newStack()]]
end

Compiler.cases = {}

function Compiler.cases:variable(term)
    return ("stack.push(var%s)"):format(term.name)
end
function Compiler.cases:literal(term)
    if type(term.value) == "string" then
        return ("stack.push(%q)"):format(term.value)
    end
    return ("stack.push(%s)"):format(tostring(term.value))
end
function Compiler.cases:message(term)
    local stmts = {}
    for _, arg in ipairs(term) do
        table.insert(stmts, self:compileTerm(arg))
        table.insert(stmts, "frames.peek().push(stack.pop())")
    end
    stmts = table.concat(stmts, "; ")
    
    return ([[frames.push(newStack()); %s; %s; stack.push(lookup(stack.pop(), %q)(frames.pop().unpack()))]]):format(self:compileTerm(term.receiver), stmts, term.name)
end
function Compiler.cases:sequence(term)
    local stmts = {}
    for _, stmt in ipairs(term) do
        table.insert(stmts, self:compileTerm(stmt))
    end
    return table.concat(stmts, "; stack.pop(); ")
end
function Compiler.cases:assign(term)
    local var = ("var%s"):format(term.variable)
    return ("%s; %s = stack.peek()"):format(self:compileTerm(term.value), var)
end
function Compiler.cases:declare(term)
    local vars = {}
    for _, var in ipairs(term) do
        table.insert(vars, ("var%s"):format(var))
    end
    
    return ("local %s; stack.push()"):format(table.concat(vars, ", "))
end
function Compiler.cases:object(term)
    local elements = {}
    for _, element in ipairs(term) do
        table.insert(elements, self:compileTerm(element))
    end
    
    elements = table.concat(elements, "; ")
    
    return ("stack.push({}); %s;"):format(elements)
end
function Compiler.cases:method(term)
    local parameters = {}
    for _, parameter in ipairs(term) do
        table.insert(parameters, ("var%s"):format(parameter))
    end
    
    parameters = table.concat(parameters, ", ")
    return ("stack.peek()[%q] = stack.peek()[%q] or function (%s) %s; %s; return stack.pop() end"):format(term.name, term.name, parameters, self:newStack(), self:compileTerm(term.expression))
end
function Compiler.cases:decorate(term)
    local value = self:compileTerm(term.value)
    return ("%s; decorate(stack.peek(1), stack.pop())"):format(value)
end

return Compiler