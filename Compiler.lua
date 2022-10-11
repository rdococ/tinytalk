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

--[[
TERM ATTRIBUTES
    type
        "variable", "message", "literal", "method", "define", "decorate", "object", "sequence"
    line
    value/expression/name/receiver/[1], [2], etc.
]]

local Compiler = {}
Compiler.__index = Compiler

function Compiler:createEnv()
    local primitives, lookup, env = {}
    
    primitives["nil"] = {}
    primitives["nil"].makeString = tostring

    primitives.boolean = {}
    primitives.boolean.makeString = tostring
    primitives.boolean["match:"] = function (self, cases)
        return lookup(cases, tostring(self))()
    end
    primitives.boolean["and:"] = function (self, other)
        return self and other
    end
    primitives.boolean["or:"] = function (self, other)
        return self or other
    end
    primitives.boolean["not"] = function (self)
        return not self
    end

    primitives.number = {}
    function primitives.number:makeNumber() return self end
    primitives.number.makeString = tostring
    primitives.number["+"] = function (a, b)
        return a + lookup(b, "makeNumber")()
    end
    primitives.number["-"] = function (a, b)
        return a - lookup(b, "makeNumber")()
    end
    primitives.number["*"] = function (a, b)
        return a * lookup(b, "makeNumber")()
    end
    primitives.number["/"] = function (a, b)
        return a / lookup(b, "makeNumber")()
    end
    primitives.number["%"] = function (a, b)
        return a % lookup(b, "makeNumber")()
    end
    primitives.number["^"] = function (a, b)
        return a ^ lookup(b, "makeNumber")()
    end
    primitives.number["<"] = function (a, b)
        return a < lookup(b, "makeNumber")()
    end
    primitives.number["="] = function (a, b)
        return a == lookup(b, "makeNumber")()
    end
    primitives.number[">"] = function (a, b)
        return a > lookup(b, "makeNumber")()
    end
    primitives.number["<="] = function (a, b)
        return a <= lookup(b, "makeNumber")()
    end
    primitives.number[">="] = function (a, b)
        return a >= lookup(b, "makeNumber")()
    end
    primitives.number["larger:"] = math.max
    primitives.number["smaller:"] = math.min
    primitives.number.floor = math.floor
    primitives.number.ceil = math.ceil
    primitives.number.abs = math.abs
    primitives.number.sqrt = math.sqrt
    primitives.number.sin = math.sin
    primitives.number.cos = math.cos
    primitives.number.tan = math.tan

    primitives.string = {}
    primitives.string.makeNumber = tonumber
    primitives.string.makeString = tostring
    primitives.string["="] = function (a, b)
        return a == lookup(b, "makeString")()
    end
    primitives.string[","] = function (a, b)
        return a .. lookup(b, "makeString")()
    end
    primitives.string["get:"] = function (self, i)
        return self:sub(lookup(i, "makeNumber")(), lookup(i, "makeNumber")())
    end
    primitives.string["slice:"] = function (self, i, j)
        return self:sub(lookup(i, "makeNumber")(), lookup(j, "makeNumber")())
    end

    local function lookupOrNil(receiver, message)
        if type(receiver) ~= "function" then
            local method = primitives[type(receiver)][message]
            if not method then return nil end
            return function (...)
                return method(receiver, ...)
            end
        end
        return receiver(message)
    end
    function lookup(receiver, message)
        local method = lookupOrNil(receiver, message)
        if not method then
            error(("Message not understood: %s"):format(message))
        end
        return method
    end

    local function console(msg)
        if msg == "print:" then
            return function (text)
                print(lookup(text, "makeString")())
            end
        elseif msg == "write:" then
            return function (text)
                io.write(lookup(text, "makeString")())
            end
        elseif msg == "error:" then
            return function (text)
                error(lookup(text, "makeString")())
            end
        elseif msg == "read" then
            return io.read
        end
    end
    local function Cell(msg)
        if msg == "make:" then
            return function (value)
                return function (msg)
                    if msg == "get" then
                        return function () return value end
                    elseif msg == "put:" then
                        return function (new) value = new; return value end
                    end
                end
            end
        elseif msg == "make" then
            return Cell("make:")
        end
    end
    local function Array(msg)
        if msg == "make" then
            return function ()
                local items = {}
                return function (msg)
                    if msg == "get:" then
                        return function (n) return items[lookup(n, "makeNumber")()] end
                    elseif msg == "at:Put:" then
                        return function (n, value) items[lookup(n, "makeNumber")()] = value end
                    elseif msg == "size" then
                        return function () return #items end
                    end
                end
            end
        end
    end
    
    local loaded = setmetatable({}, {__mode = "v"})
    local function system(msg)
        if msg == "require:" then
            return function (filename)
                filename = lookup(filename, "makeString")()
                
                if loaded[filename] then return loaded[filename].result end
                
                local file = io.open(filename)
                local code = file:read("*a")
                file:close()
                
                local compiled = Compiler:compile(Parser:parse(Lexer:new(StringReader:new(code))))
                local fn, err = load(compiled, nil, "t", env)
                
                if not fn then
                    error(err)
                end
                
                loaded[filename] = {result = fn()}
                return loaded[filename].result
            end
        elseif msg == "run:" then
            return function (filename)
                filename = lookup(filename, "makeString")()
                
                local file = io.open(filename)
                local code = file:read("*a")
                file:close()
                
                local compiled = Compiler:compile(Parser:parse(Lexer:new(StringReader:new(code))))
                local fn, err = load(compiled, nil, "t", env)
                
                if not fn then
                    error(err)
                end
                
                return fn()
            end
        elseif msg == "open:" then
            return function (filename)
                filename = lookup(filename, "makeString")()
                local file = io.open(filename)
                
                return function (msg)
                    if msg == "read" then
                        return function () return file:read("*l") end
                    elseif msg == "readAll" then
                        return function () return file:read("*a") end
                    elseif msg == "write:" then
                        return function (text)
                            file:write(lookup(text, "makeString")())
                            file:flush()
                        end
                    elseif msg == "position" then
                        return function () return file:seek() end
                    elseif msg == "goto:" then
                        return function (pos) file:seek("set", pos) end
                    elseif msg == "move:" then
                        return function (dist) file:seek("cur", dist) end
                    elseif msg == "size" then
                        return function ()
                            local pos = file:seek()
                            local size = file:seek("end")
                            file:seek("set", pos)
                            return size
                        end
                    elseif msg == "close" then
                        return function () file:close() end
                    end
                end
            end
        end
    end
    
    env = {
        lookupOrNil = lookupOrNil,
        lookup = lookup,
        id = function (...) return ... end,
        
        vartrue = true,
        varfalse = false,
        varnl = "\n",
        
        varconsole = console,
        varCell = Cell,
        varArray = Array,
        varsystem = system
    }
    return env
end

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
    return ("return %s"):format(self:withGlobalScope(function () return self:compileTerm(term) end))
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
function Compiler.cases:object(term)
    local decoVars, decoValues = {}, {}
    
    local oldAddDeco = self.addDecoration
    function self:addDecoration(value)
        table.insert(decoValues, value)
        table.insert(decoVars, "deco" .. #decoValues)
        return decoVars[#decoVars]
    end
    
    local elements = {}
    for _, element in ipairs(term) do
        table.insert(elements, self:compileTerm(element))
    end
    
    self.addDecoration = oldAddDeco
    
    elements = table.concat(elements, " ")
    decoVars, decoValues = table.concat(decoVars, ", "), table.concat(decoValues, ", ")
    
    if #decoVars == 0 then
        return ("(function (msg) if false then %s end end)"):format(elements)
    end
    return ("(function (msg) local %s = %s; if false then %s end end)"):format(decoVars, decoValues, elements)
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
    return ("elseif msg == %q then return function (%s) return %s end"):format(term.name, parameters, expression)
end
function Compiler.cases:decorate(term, addDeco)
    local value = self:compileTerm(term.value)
    local var = self:addDecoration(value)
    
    return ("elseif lookupOrNil(%s, msg) then return lookup(%s, msg)"):format(var, var)
end

return Compiler