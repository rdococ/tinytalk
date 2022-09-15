--[[
Token types:
"word": Variable or unary message
"operation": Binary operation
"message starter": Start of multiary message
"message continuer": Middle segment in multiary message
"literal": Literal value
"[", "]", "(", ")", "|", "\", ".": Syntactic constructs
]]

local function set(str, empty)
	local set = {}
	for i = 1, #str do
		set[str:sub(i, i)] = true
	end
	if empty then set[""] = true end
	return set
end

Lexer = {}
Lexer.__index = Lexer

Lexer.whitespace = set(" \n\t\"")
Lexer.wordChars = set("abcdefghijklmnopqrstuvwxyz_+-*/%^<=>ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
Lexer.symbols = set("[]()|\\.")
Lexer.numberStarters = set("0123456789-")
Lexer.digits = set("0123456789")

Lexer.messageStarters = set("abcdefghijklmnopqrstuvwxyz_")
Lexer.messageContinuers = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
Lexer.operationStarters = set("+-*/%^<=>,")

function Lexer:new()
	return setmetatable({}, self)
end

function Lexer:lex(code)
	self.reader = Reader:new(code)
	self.tokens = {}
	
	while true do
		local token = self:lexToken()
		if token == nil then break end
		table.insert(self.tokens, token)
	end
	
	return self.tokens
end
function Lexer:error(err, ...)
	if self.reader then
		return error(("Line %s: %s"):format(self.reader:line(), err:format(...)))
	end
	return error(err:format(...))
end

function Lexer:createTerm(type, attr)
	local attributes = attr or {}
	attributes.type, attributes.line = type, self.reader:line()
	return attributes
end
function Lexer:add(token)
	table.insert(self.tokens, token)
end

function Lexer:lexToken()
	local char
	
	while true do
		char = self.reader:peek()
		if char == "\"" then
			self.reader:read()
			while true do
				char = self.reader:read()
				if char == "" then
					self:error("Expected end of comment, got \"\"")
				elseif char == "\"" then
					if self.reader:peek() == "\"" then
						self.reader:read()
					else
						break
					end
				end
			end
		elseif self.whitespace[char] then
			self.reader:read()
		else
			break
		end
	end
	
	if char == "'" then
		return self:lexString()
	elseif self.digits[char] or self.numberStarters[char] and self.digits[self.reader:peek(2)] then
		return self:lexNumber()
	elseif self.messageStarters[char] or self.messageContinuers[char] or self.operationStarters[char] or char == ":" then
		return self:lexWordlikeToken()
	elseif self.symbols[char] then
		return self:lexSymbol()
	elseif char == "" then
		return
	end
	
	self:error("Expected valid token, got %q", char)
end

function Lexer:lexString()
	local term = self:createTerm("literal")
	local chars = {}
	
	local quote = self.reader:read()
	while true do
		local char = self.reader:read()
		
		if char == "\\" then
			table.insert(chars, self.reader:read())
		elseif char == quote then
			if self.reader:peek() == quote then
				table.insert(chars, self.reader:read())
			else
				break
			end
		else
			table.insert(chars, char)
		end
	end
	
	term.value = table.concat(chars)
	return term
end
function Lexer:lexNumber()
	local number = self:createTerm("literal")
	local chars = {self.reader:read()}
	local dotHit = false
	
	while true do
		local char = self.reader:peek()
		
		if self.digits[char] then
			table.insert(chars, self.reader:read())
		elseif char == "." and not dotHit and self.digits[self.reader:peek(2)] then
			table.insert(chars, self.reader:read())
			dotHit = true
		else
			break
		end
	end
	
	local str = table.concat(chars)
	number.value = tonumber(str)
	if number.value == nil then
		return self:error("Expected a valid number, got %q", str)
	end
	
	return number
end
function Lexer:lexWordlikeToken()
	local word = self:createTerm("word")
	local chars = {}
	
	local char = self.reader:read()
	table.insert(chars, char)
	
	while true do
		char = self.reader:peek()
		if self.wordChars[char] or char == ":" then
			table.insert(chars, self.reader:read())
			if char == ":" then
				word.type = self.messageContinuers[chars[1]] and "message continuer" or "message starter"
				break
			end
		else
			break
		end
	end
	
	word.value = table.concat(chars)
	if word.value == ":=" then
		word.type = "definition"
		word.value = nil
	elseif self.operationStarters[word.value:sub(1, 1)] then
		word.type = "operation"
	end
	
	return word
end
function Lexer:lexSymbol()
	local char = self.reader:peek()
	
	if char == "." and self.reader:peek(2) == "." and self.reader:peek(3) == "." then
		self.reader:read(3)
		return self:createTerm("decoration")
	end
	
	return self:createTerm(self.reader:read())
end