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

local Compiler = {}
Compiler.__index = Compiler

function Compiler:pushScope()
    self.scope = {varset = {}, variables = {}, defaults = {}, parent = self.scope}
    return self.scope
end
function Compiler:popScope()
    local scope = self.scope
    self.scope = self.scope.parent
    return scope
end
function Compiler:withScope(fn)
    local scope = self:pushScope()
    local result = fn()
    self:popScope()
    
    local variables = table.concat(scope.variables, ", ")
    local defaults = table.concat(scope.defaults, ", ")
    
    if #scope.variables == 0 then
        return result
    end
    
    return ("(function () local %s = %s; return %s end)()"):format(variables, defaults, result)
end
function Compiler:withGlobalScope(fn)
    local scope = self:pushScope()
    local result = fn()
    self:popScope()
    
    local variables = table.concat(scope.variables, ", ")
    local defaults = table.concat(scope.defaults, ", ")
    
    if #scope.variables == 0 then
        return result
    end
    
    return ("(function () %s = %s; return %s end)()"):format(variables, defaults, result)
end

function Compiler:addVariable(var, default)
    if self.scope.varset[var] then return end
    table.insert(self.scope.variables, var)
    table.insert(self.scope.defaults, default or "nil")
    self.scope.varset[var] = true
end

function Compiler:compile(term)
    local self = setmetatable({}, self)
    return ("return wrap(function () return %s end)()"):format(self:withGlobalScope(function () return self:compileTerm(term) end))
end
function Compiler:compileTerm(term)
    return self.cases[term.type](self, term)
end

Compiler.cases = {}

function Compiler.cases:variable(term)
    return ("var%s"):format(term.name)
end
function Compiler.cases:literal(term)
    if type(term.value) == "string" then
        return string.format("%q", term.value)
    end
    return tostring(term.value)
end
function Compiler.cases:message(term)
    local args = {}
    for _, arg in ipairs(term) do
        table.insert(args, self:compileTerm(arg))
    end
    args = table.concat(args, ", ")
    
    return ("lookup(%s, %q)(%s)"):format(self:compileTerm(term.receiver), term.name, args)
end
function Compiler.cases:sequence(term)
    local stats = {}
    for _, stat in ipairs(term) do
        table.insert(stats, ("id(%s)"):format(self:compileTerm(stat)))
    end
    
    local result = stats[#stats]
    table.remove(stats)
    stats = table.concat(stats, "; ")
    
    return ("(function () %s return %s end)()"):format(stats, result)
end
function Compiler.cases:define(term)
    local var = ("var%s"):format(term.variable)
    self:addVariable(var)
    return ("(function () %s = %s; return %s end)()"):format(var, self:compileTerm(term.value), var)
end
function Compiler.cases:assign(term)
    local var = ("var%s"):format(term.variable)
    return ("(function () %s = %s; return %s end)()"):format(var, self:compileTerm(term.value), var)
end
function Compiler.cases:object(term)
    local elements = {}
    for _, element in ipairs(term) do
        table.insert(elements, self:compileTerm(element))
    end
    
    elements = table.concat(elements, "; ")
    
    return ("(function () local object = {}; %s; return object end)()"):format(elements)
end
function Compiler.cases:method(term)
    local parameters = {}
    for _, parameter in ipairs(term) do
        table.insert(parameters, ("var%s"):format(parameter))
    end
    
    local expression = self:withScope(function ()
        for _, parameter in ipairs(parameters) do
            self:addVariable(parameter, parameter)
        end
        return term.expression and self:compileTerm(term.expression) or "nil"
    end)
    
    parameters = table.concat(parameters, ", ")
    return ("object[%q] = object[%q] or wrap(function (%s) return %s end)"):format(term.name, term.name, parameters, expression)
end
function Compiler.cases:decorate(term)
    local value = self:compileTerm(term.value)
    return ("decorate(object, %s)"):format(value)
end
function Compiler.cases:block(term)
    local expression = self:withScope(function ()
        return term.expression and self:compileTerm(term.expression) or "nil"
    end)

    return ("({[\"do\"] = function () return %s end})"):format(expression)
end
function Compiler.cases:yield(term)
    local expression = self:withScope(function ()
        return term.expression and self:compileTerm(term.expression) or "nil"
    end)

    return ("yield(%s)"):format(expression)
end

return Compiler