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

math.randomseed(os.time())

StringReader = dofile("./StringReader.lua")
Lexer = dofile("./Lexer.lua")
Parser = dofile("./Parser.lua")
Compiler = dofile("./Compiler.lua")

local env = Compiler:createEnv()

while true do
    io.write("> ")
    local code = io.read()
    local success, result = pcall(function ()
        local result = Compiler:compile(Parser:parse(Lexer:new(StringReader:new(code))))
        
        local fn, err = load(result, nil, "t", env)
        if not fn then
            error(err)
        end
        
        return fn()
    end)
    if success then
        local success, result = pcall(function ()
            return env.lookup(result, "makeString")()
        end)
        print(result)
    else
        print(result)
    end
end