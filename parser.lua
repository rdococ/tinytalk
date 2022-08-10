--[[
Term types:

"object" - [n]: method
"method" - message: string, parameters: parameters, body: body
"definition" - name: string, value: expression
"send" - receiver: expression, message: string, [n]: expression
"parameters" - [n]: variable
"procedure" - parameters: parameters, body: body
"body" - [n]: expression
"variable" - name: string
"string" - value: string
"number" - value: number
"forward" - target: expression
]]

local function set(str, empty)
	local set = {}
	for i = 1, #str do
		set[str:sub(i, i)] = true
	end
	if empty then set[""] = true end
	return set
end

local Reader = {}
Reader.__index = Reader

function Reader:new(text)
	return setmetatable({text = text, index = 1, lineNum = 1}, self)
end
function Reader:peek(n)
	n = n or 1
	return self.text:sub(self.index, self.index + n - 1)
end
function Reader:read(n)
	n = n or 1
	local substr = self:peek(n)
	self.index = self.index + n
	
	local _, lines = substr:gsub("\n", "")
	self.lineNum = self.lineNum + lines
	
	return substr
end
function Reader:unread(v)
	if type(v) == "number" then
		local num = v
		
		self.index = self.index - num
		
		local _, lines = self:peek(num):gsub("\n", "")
		self.lineNum = self.lineNum - lines
	else
		local text = v
		
		self.text = text .. self.text:sub(self.index, #self.text)
		self.index = 1
		
		local _, lines = text:gsub("\n", "")
		self.lineNum = self.lineNum - lines
	end
end
function Reader:line()
	return self.lineNum
end
function Reader:copy()
	local new = setmetatable({}, getmetatable(self))
	for k, v in pairs(self) do
		new[k] = v
	end
	return new
end

Parser = {}
Parser.__index = Parser

Parser.whitespace = set(" \t\n;")
Parser.wordEnders = set(" \t\n()[]{};", true)
Parser.closingBrackets = {["("] = ")", ["["] = "]", ["{"] = "}"}

function Parser:new()
	return setmetatable({}, self)
end

function Parser:parse(code)
	self.reader = Reader:new(("(%s)"):format(code))
	
	return self:parseBody()
end
function Parser:error(err, ...)
	if self.reader then
		return error(("Line %s: %s"):format(self.reader:line(), err:format(...)))
	end
	return error(err:format(...))
end

function Parser:skipWhitespace()
	while true do
		local char = self.reader:peek()
		if not self.whitespace[char] then return end
		if char == ";" then
			while self.reader:peek() ~= "\n" do
				self.reader:read()
			end
		end
		
		self.reader:read()
	end
end
function Parser:consumeBracket()
	local open = self.reader:read()
	return self.closingBrackets[open] or "", open
end

function Parser:createTerm(type, attributes)
	attributes = attributes or {}
	attributes.type, attributes.line = type, self.reader:line()
	return attributes
end

function Parser:parseExpression()
	local char = self.reader:peek()
	if char == "(" then
		return self:parseParentheses()
	elseif char == "{" then
		return self:parseObject()
	elseif char == "[" then
		return self:parseProcedure()
	elseif char == "\"" then
		return self:parseString()
	elseif tonumber(char) or char == "." then
		return self:parseNumber()
	else
		return self:parseVariable()
	end
end
function Parser:parseParentheses()
	local backtrack = self.reader:copy()
	
	local closer, opener = self:consumeBracket()
	self:skipWhitespace()
	local word = self:parseWord()
	
	self.reader = backtrack
	
	if word == "define" then
		return self:parseDefinition()
	else
		return self:parseSend()
	end
end
function Parser:parseDefinition()
	local definition = self:createTerm("definition", {})
	
	local closer = self:consumeBracket()
	self:skipWhitespace()
	self:parseWord()
	self:skipWhitespace()
	definition.name = self:parseWord()
	self:skipWhitespace()
	definition.value = self:parseExpression()
	self:skipWhitespace()
	self.reader:read()
	
	return definition
end
function Parser:parseSend()
	local send = self:createTerm("send", {})
	
	local closer = self:consumeBracket()
	self:skipWhitespace()
	send.receiver = self:parseExpression()
	self:skipWhitespace()
	send.message = self:parseWord()
	
	while true do
		self:skipWhitespace()
		local char = self.reader:peek()
		if char == closer then
			self.reader:read()
			break
		end
		
		table.insert(send, self:parseExpression())
	end
	
	return send
end
function Parser:parseObject()
	local object = self:createTerm("object", {})
	
	local closer = self:consumeBracket()
	while true do
		self:skipWhitespace()
		local char = self.reader:peek()
		if char == closer then
			self.reader:read()
			break
		end
		
		table.insert(object, self:parseMethod())
	end
	
	return object
end
function Parser:parseMethod()
	local method = self:createTerm("method", {})
	
	local closer, opener = self:consumeBracket()
	self:skipWhitespace()
	
	-- Parse the first word in the method signature as a message name, and the rest as parameters
	local sigCloser, sigOpener = self:consumeBracket()
	self:skipWhitespace()
	method.message = self:parseWord()
	self.reader:unread(sigOpener)
	method.parameters = self:parseParameters()
	
	-- Parse the rest of the method as a body
	self.reader:unread(opener)
	method.body = self:parseBody()
	
	return method
end
function Parser:parseProcedure()
	local procedure = self:createTerm("procedure", {})
	
	local closer, opener = self:consumeBracket()
	self:skipWhitespace()
	procedure.parameters = self:parseParameters()
	
	-- Parse the rest of the procedure as a body
	self.reader:unread(opener)
	procedure.body = self:parseBody()
	
	return procedure
end
function Parser:parseParameters()
	local parameters = self:createTerm("parameters")
	
	local closer = self:consumeBracket()
	while true do
		self:skipWhitespace()
		local char = self.reader:peek()
		if char == closer then
			self.reader:read()
			break
		end
		
		table.insert(parameters, self:parseWord())
	end
	
	return parameters
end
function Parser:parseBody()
	local body = self:createTerm("body")
	
	local closer = self:consumeBracket()
	while true do
		self:skipWhitespace()
		local char = self.reader:peek()
		if char == closer then
			self.reader:read()
			break
		end
		
		table.insert(body, self:parseExpression())
	end
	
	return body
end
function Parser:parseWord()
	local word = ""
	while not self.wordEnders[self.reader:peek()] do
		word = word .. self.reader:read()
	end
	return word
end
function Parser:parseVariable()
	local var = self:createTerm("variable", {name = ""})
	while not self.wordEnders[self.reader:peek()] do
		var.name = var.name .. self.reader:read()
	end
	
	return var
end
function Parser:parseString()
	local str = self:createTerm("string", {value = ""})
	local quote = self.reader:read()
	
	while self.reader:peek() ~= quote do
		local char = self.reader:read()
		if char == "\\" then
			str.value = str.value .. self.reader:read()
		else
			str.value = str.value .. char
		end
	end
	self.reader:read()
	
	return str
end
function Parser:parseNumber()
	local num = self:createTerm("number", {value = ""})
	while not self.wordEnders[self.reader:peek()] do
		local char = self.reader:read()
		num.value = num.value .. char
	end
	num.value = tonumber(num.value)
	
	return num
end