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

local Runtime = {}

function Runtime:new()
    local primitives, env = {}
    
    local function id(...) return ... end
    local function lookupOrNil(receiver, message)
        if type(receiver) ~= "table" then
            local method = primitives[type(receiver)][message]
            if not method then return nil end
            return function (...)
                return method(receiver, ...)
            end
        end
        return receiver[message]
    end
    local function lookup(receiver, message)
        local method = lookupOrNil(receiver, message)
        if not method then
            error(("Message not understood: %s"):format(message))
        end
        return method
    end
    local function decorate(object, decoratee)
        if type(decoratee) ~= "table" then
            for message, method in pairs(primitives[type(decoratee)]) do
                object[message] = object[message] or function (...) return method(decoratee, ...) end
            end
            return
        end
        for message, method in pairs(decoratee) do
            object[message] = object[message] or method
        end
    end
    local function makePrimitiveString(receiver)
        return lookup(lookup(receiver, "makeString")(), "makePrimitive")()
    end
    local function makePrimitiveNumber(receiver)
        return lookup(lookup(receiver, "makeNumber")(), "makePrimitive")()
    end
    local loaded = setmetatable({}, {__mode = "v"})
    
    primitives["nil"] = {}
    primitives["nil"].makePrimitive = id
    primitives["nil"].makeString = tostring

    primitives.boolean = {}
    primitives.boolean.makePrimitive = id
    primitives.boolean.makeString = tostring
    primitives.boolean["if:"] = function (self, cases)
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
    primitives.number.makePrimitive = id
    primitives.number.makeNumber = id
    primitives.number.makeString = tostring
    primitives.number["+"] = function (a, b)
        return a + makePrimitiveNumber(b)
    end
    primitives.number["-"] = function (a, b)
        return a - makePrimitiveNumber(b)
    end
    primitives.number["*"] = function (a, b)
        return a * makePrimitiveNumber(b)
    end
    primitives.number["/"] = function (a, b)
        return a / makePrimitiveNumber(b)
    end
    primitives.number["%"] = function (a, b)
        return a % makePrimitiveNumber(b)
    end
    primitives.number["^"] = function (a, b)
        return a ^ makePrimitiveNumber(b)
    end
    primitives.number["<"] = function (a, b)
        return a < makePrimitiveNumber(b)
    end
    primitives.number["="] = function (a, b)
        return a == (lookupOrNil(b, "makePrimitive") or id)()
    end
    primitives.number[">"] = function (a, b)
        return a > makePrimitiveNumber(b)
    end
    primitives.number["<="] = function (a, b)
        return a <= makePrimitiveNumber(b)
    end
    primitives.number[">="] = function (a, b)
        return a >= makePrimitiveNumber(b)
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
    primitives.number.negate = function (x) return -x end
    primitives.number.character = string.char

    primitives.string = {}
    primitives.string.makePrimitive = id
    primitives.string.makeNumber = tonumber
    primitives.string.makeString = tostring
    primitives.string["="] = function (a, b)
        return a == (lookupOrNil(b, "makePrimitive") or id)()
    end
    primitives.string[","] = function (a, b)
        return a .. makePrimitiveString(b)
    end
    primitives.string["at:"] = function (self, i)
        return self:sub(makePrimitiveNumber(i), makePrimitiveNumber(i))
    end
    primitives.string["from:To:"] = function (self, i, j)
        return self:sub(makePrimitiveNumber(i), makePrimitiveNumber(j))
    end
    primitives.string.byte = string.byte
    primitives.string.import = function (self)
        local filename = ("./repository/%s.tiny"):format(self)
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
    
    local console = {}
    console["print:"] = function (text) print(makePrimitiveString(text)) end
    console["write:"] = function (text) io.write(makePrimitiveString(text)) end
    console["error:"] = function (text) error(makePrimitiveString(text)) end
    console.read = io.read
    console["read:"] = function (n) return io.read(makePrimitiveNumber(n)) end
    
    local Cell = {}
    Cell["make:"] = function (value)
        return {
            value = function () return value end,
            ["put:"] = function (new) value = new; return value end,
            makeString = function () return "Cell(" .. makePrimitiveString(text) .. ")" end
        }
    end
    Cell.make = Cell["make:"]
    
    local Array = {}
    Array.make = function ()
        local items = {}
        return {
            ["at:"] = function (n, value)
                n = makePrimitiveNumber(n)
                if type(n) ~= "number" then return end
                return items[n]
            end,
            ["at:Put:"] = function (n, value)
                n = makePrimitiveNumber(n)
                if type(n) ~= "number" or math.floor(n) ~= n then error("Cannot use non-integer array keys") end
                items[n] = value
            end,
            size = function () return #items end,
            makeString = function ()
                local itemStrs = {}
                for _, item in ipairs(items) do
                    table.insert(itemStrs, makePrimitiveString(item))
                end
                return "Array(" .. table.concat(itemStrs, ", ") .. ")"
            end
        }
    end
    
    system = {}
    system["require:"] = function (filename)
        filename = makePrimitiveString(filename)
        
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
    system["open:"] = function (filename)
        filename = makePrimitiveString(filename)
        local file = io.open(filename)
        
        return {
            read = function () return file:read() end,
            ["read:"] = function (x) return file:read(makePrimitiveNumber(x)) end,
            readAll = function () return file:read("*a") end,
            ["write:"] = function (text)
                file:write(lookup(text, "makeString")())
                file:flush()
            end,
            position = function () return file:seek() end,
            ["goto:"] = function (pos) file:seek("set", makePrimitiveNumber(pos)) end,
            ["move:"] = function (dist) file:seek("cur", makePrimitiveNumber(dist)) end,
            size = function ()
                local pos = file:seek()
                local size = file:seek("end")
                file:seek("set", pos)
                return size
            end,
            close = function () file:close() end,
            makeString = function ()
                return "File(" .. filename .. ")"
            end
        }
    end
    
    env = {
        lookupOrNil = lookupOrNil,
        lookup = lookup,
        decorate = decorate,
        id = id,
        
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

return Runtime