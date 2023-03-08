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

local Parser = {}
Parser.__index = Parser

function Parser:term(term)
    term.line = self.lexer:line()
    return term
end
function Parser:error(err, ...)
    return error(("Line %s: %s"):format(self.lexer:line(), err:format(...)))
end

function Parser:parse(lexer)
    local self = setmetatable({index = 0, lexer = lexer}, self)
    local term = self:parseRecursively(0)
    
    local token = self.lexer:peek()
    if token.type ~= "eof" then self:error("Expected next statement or eof, got %s", token.type) end
    
    return term
end
function Parser:parseRecursively(prec)
    local token = self.lexer:read()
    
    local case = self.cases[token.type]
    if not case.handleHead then self:error("Expected value, got %s", token.type) end
    local left = case.handleHead(self, token)
    
    while (self.cases[self.lexer:peek().type].precedence or 0) > prec do
        token = self.lexer:read()
        
        local case = self.cases[token.type]
        if not case.handleTail then self:error("Expected operation or end of expression, got %s", token.type) end
        left = self.cases[token.type].handleTail(self, token, left)
    end
    
    return left
end

Parser.cases = {}

Parser.cases.word = {precedence = 6}
function Parser.cases.word:handleHead(token)
    return self:term {type = "variable", name = token.value}
end
function Parser.cases.word:handleTail(token, left)
    return self:term {type = "message", receiver = left, name = token.value}
end

Parser.cases.literal = {precedence = 0}
function Parser.cases.literal:handleHead(token)
    return self:term {type = "literal", value = token.value}
end

Parser.cases.binop = {precedence = 5}
function Parser.cases.binop:handleTail(token, left)
    return self:term {type = "message", msgtype = "binop", receiver = left, name = token.value, self:parseRecursively(5)}
end

Parser.cases.msgopen = {precedence = 4}
function Parser.cases.msgopen:handleTail(token, left)
    local term = self:term {type = "message", msgtype = "keyword", receiver = left, name = token.value, self:parseRecursively(4)}
    
    while true do
        local next = self.lexer:peek()
        
        if not next or next.type ~= "msgnext" then return term end
        self.lexer:read()
        
        term.name = term.name .. next.value
        table.insert(term, self:parseRecursively(4))
    end
end

Parser.cases.msgnext = {precedence = 4}
function Parser.cases.msgnext:handleTail(token, left)
    self:error("Cannot start a keyword message with an uppercase letter")
end

Parser.cases.define = {precedence = 3}
function Parser.cases.define:handleTail(token, left)
    if left.type ~= "variable" then
        self:error("Expected variable, got %s", left.type)
    end
    
    return self:term {type = "define", variable = left.name, value = self:parseRecursively(2)}
end

Parser.cases.assign = {precedence = 3}
function Parser.cases.assign:handleTail(token, left)
    if left.type ~= "variable" then
        self:error("Expected variable, got %s", left.type)
    end
    
    return self:term {type = "assign", variable = left.name, value = self:parseRecursively(2)}
end

Parser.cases.statclose = {precedence = 2}
function Parser.cases.statclose:handleTail(token, left)
    local next = self.lexer:peek()
    if not self.cases[self.lexer:peek().type].handleHead then
        return left
    end
    
    if left.type == "sequence" then
        table.insert(left, self:parseRecursively(2))
        return left
    end
    
    return self:term {type = "sequence", left, self:parseRecursively(2)}
end

Parser.cases.expropen = {precedence = 0}
function Parser.cases.expropen:handleHead(token)
    local term = self:parseRecursively(0)
    local close = self.lexer:read()
    
    if close.type ~= "exprclose" then
        self:error("Expected closing parenthesis, got %s", close.type)
    end
    
    return term
end

Parser.cases.objopen = {precedence = 0}
function Parser.cases.objopen:handleHead(token)
    local object = self:term {type = "object"}
    
    if self.lexer:peek().type == "objclose" then
        self.lexer:read()
        return object
    end
    
    while true do
        local token = self.lexer:peek()
        if token.type == "msgopen" or token.type == "word" or token.type == "binop" then
            self.lexer:read()
            local method = self:term {type = "method", name = token.value}
            
            if token.type ~= "word" then
                while true do
                    local parameter = self.lexer:read()
                    if parameter.type ~= "word" then
                        self:error("Expected parameter, got %s", parameter.type)
                    end
                    table.insert(method, parameter.value)
                    
                    local token = self.lexer:peek()
                    if token.type ~= "msgnext" then break else
                        self.lexer:read()
                        method.name = method.name .. token.value
                    end
                end
            end
            
            if self.cases[self.lexer:peek().type].handleHead then
                method.expression = self:parseRecursively(0)
            end
            table.insert(object, method)
        elseif token.type == "objdeco" then
            self.lexer:read()
            table.insert(object, self:term {type = "decorate", value = self:parseRecursively(0)})
        end
        
        token = self.lexer:peek()
        if token.type == "objclose" then
            self.lexer:read()
            break
        elseif token.type == "objnext" then
            self.lexer:read()
        else
            self:error("Expected next method or end of object, got %s", token.type)
        end
    end
    
    return object
end

Parser.cases.exprclose = {precedence = 0}
Parser.cases.objnext = {precedence = 0}
Parser.cases.objclose = {precedence = 0}
Parser.cases.objdeco = {precedence = 0}
Parser.cases.eof = {precedence = 0}

return Parser
