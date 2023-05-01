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
            return function () error(("Message not understood: %s"):format(message)) end
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
    local function asPrimitiveString(receiver)
        return lookup(lookup(receiver, "asString")(), "asPrimitive")()
    end
    local function asPrimitiveNumber(receiver)
        return lookup(lookup(receiver, "asNumber")(), "asPrimitive")()
    end
    local function asPrimitiveNumberOrNil(receiver)
        local method = lookupOrNil(lookup(receiver, "asNumber")(), "asPrimitive")
        if method then
            return method()
        end
    end
    local loaded = setmetatable({}, {__mode = "v"})
    
    primitives["nil"] = {}
    primitives["nil"].asPrimitive = id
    primitives["nil"].asString = tostring

    primitives.boolean = {}
    primitives.boolean.asPrimitive = id
    primitives.boolean.asString = tostring
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
    primitives.number.asPrimitive = id
    primitives.number.asNumber = id
    primitives.number.asString = tostring
    primitives.number["+"] = function (a, b)
        local bP = asPrimitiveNumberOrNil(b)
        if not bP then return lookup(b, "+")(a) end
        return a + bP
    end
    primitives.number["-"] = function (a, b)
        local bP = asPrimitiveNumberOrNil(b)
        if not bP then return lookup(lookup(b, "-")(a), "negate") end
        return a - bP
    end
    primitives.number["*"] = function (a, b)
        local bP = asPrimitiveNumberOrNil(b)
        if not bP then return lookup(b, "*")(a) end
        return a * bP
    end
    primitives.number["/"] = function (a, b)
        local bP = asPrimitiveNumberOrNil(b)
        if not bP then return lookup(lookup(b, "/")(a), "reciprocal") end
        return a / bP
    end
    primitives.number["%"] = function (a, b)
        return a % asPrimitiveNumber(b)
    end
    primitives.number["^"] = function (a, b)
        return a ^ asPrimitiveNumber(b)
    end
    primitives.number["<"] = function (a, b)
        return a < asPrimitiveNumber(b)
    end
    primitives.number["="] = function (a, b)
        return a == (lookupOrNil(b, "asPrimitive") or id)()
    end
    primitives.number[">"] = function (a, b)
        return a > asPrimitiveNumber(b)
    end
    primitives.number["<="] = function (a, b)
        return a <= asPrimitiveNumber(b)
    end
    primitives.number[">="] = function (a, b)
        return a >= asPrimitiveNumber(b)
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
    primitives.number.reciprocal = function (x) return 1 / x end
    primitives.number.character = string.char
    primitives.number["random:"] = math.random
    primitives.number["to:"] = function (a, b)
        return {
            asString = function () return ("%s to: %s"):format(asPrimitiveString(a), asPrimitiveString(b)) end,
            ["do:"] = function (body)
                local with = lookup(body, "with:")
                for i = a, b do
                    with(i)
                end
            end
        }
    end
    
    primitives.string = {}
    primitives.string.asPrimitive = id
    primitives.string.asNumber = tonumber
    primitives.string.asString = tostring
    primitives.string["="] = function (a, b)
        return a == (lookupOrNil(b, "asPrimitive") or id)()
    end
    primitives.string[","] = function (a, b)
        return a .. asPrimitiveString(b)
    end
    primitives.string["at:"] = function (self, i)
        return self:sub(asPrimitiveNumber(i), asPrimitiveNumber(i))
    end
    primitives.string["from:To:"] = function (self, i, j)
        return self:sub(asPrimitiveNumber(i), asPrimitiveNumber(j))
    end
    primitives.string.size = function (self) return #self end
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
    console["print:"] = function (text) print(asPrimitiveString(text)) end
    console["write:"] = function (text) io.write(asPrimitiveString(text)) end
    console["error:"] = function (text) error(asPrimitiveString(text)) end
    console.read = io.read
    console["read:"] = function (n) return io.read(asPrimitiveNumber(n)) end
    
    local Cell = {}
    Cell["new:"] = function (value)
        return {
            value = function () return value end,
            ["put:"] = function (new) value = new; return value end,
            asString = function () return "Cell(" .. asPrimitiveString(text) .. ")" end
        }
    end
    Cell.new = Cell["new:"]
    
    local Array = {}
    Array.new = function ()
        local items = {}
        return {
            ["at:"] = function (n, value)
                n = asPrimitiveNumber(n)
                if type(n) ~= "number" then return end
                return items[n]
            end,
            ["at:Put:"] = function (n, value)
                n = asPrimitiveNumber(n)
                if type(n) ~= "number" or math.floor(n) ~= n then error("Cannot use non-integer array keys") end
                items[n] = value
            end,
            size = function () return #items end,
            asString = function ()
                local itemStrs = {}
                for _, item in ipairs(items) do
                    table.insert(itemStrs, asPrimitiveString(item))
                end
                return "Array(" .. table.concat(itemStrs, ", ") .. ")"
            end
        }
    end
    
    system = {}
    system["require:"] = function (filename)
        filename = asPrimitiveString(filename)
        
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
        filename = asPrimitiveString(filename)
        local file = io.open(filename)
        
        return {
            read = function () return file:read() end,
            ["read:"] = function (x) return file:read(asPrimitiveNumber(x)) end,
            readAll = function () return file:read("*a") end,
            ["write:"] = function (text)
                file:write(lookup(text, "asString")())
                file:flush()
            end,
            position = function () return file:seek() end,
            ["goto:"] = function (pos) file:seek("set", asPrimitiveNumber(pos)) end,
            ["move:"] = function (dist) file:seek("cur", asPrimitiveNumber(dist)) end,
            size = function ()
                local pos = file:seek()
                local size = file:seek("end")
                file:seek("set", pos)
                return size
            end,
            close = function () file:close() end,
            asString = function ()
                return "File(" .. filename .. ")"
            end
        }
    end
    
    local Message = {}
    setmetatable(Message, {__index = function (_, selector)
        return function (...)
            local args, argCount = {...}, select("#", ...)
            
            return {
                ["send:"] = function (receiver)
                    return receiver[selector](table.unpack(args, 1, argCount))
                end,
                asString = function ()
                    local argStrings = {}
                    
                    for i, arg in ipairs(args) do
                        table.insert(argStrings, asPrimitiveString(arg))
                    end
                    
                    local messageString = {}
                    local argIndex = 1
                    for i = 1, #selector do
                        local char = selector:sub(i, i)
                        table.insert(messageString, char)
                        
                        if char == ":" then
                            table.insert(messageString, " ")
                            table.insert(messageString, asPrimitiveString(args[argIndex]))
                            argIndex = argIndex + 1
                            
                            if i < #selector then
                                table.insert(messageString, " ")
                            end
                        end
                    end
                    
                    return "Message(" .. table.concat(messageString) .. ")"
                end
            }
        end
    end})
    
    env = {
        lookupOrNil = lookupOrNil,
        lookup = lookup,
        decorate = decorate,
        id = id,
        
        vartrue = true,
        varfalse = false,
        varnl = "\n",
        
        varCell = Cell,
        varArray = Array,
        varMessage = Message,
        
        varconsole = console,
        varsystem = system,
    }
    return env
end

return Runtime