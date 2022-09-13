local function set(str, empty)
	local set = {}
	for i = 1, #str do
		set[str:sub(i, i)] = true
	end
	if empty then set[""] = true end
	return set
end

Parser = {}
Parser.__index = Parser

Parser.symbols = set("[]()|\\.")
Parser.bodyClosers = set(")]|\\")

function Parser:new()
	return setmetatable({}, self)
end

function Parser:parse(tokens)
	self.tokens = tokens
	self.index = 1
	self.line = self:peek() and self:peek().line
	
	return self:parseProgram()
end
function Parser:error(err, ...)
	if self:peek() then
		return error(("Line %s: %s"):format(self:peek().line, err:format(...)))
	end
	return error(err:format(...))
end

function Parser:createTerm(type, attr)
	local attributes = attr or {}
	attributes.type, attributes.line = type, self.line
	return attributes
end
function Parser:peek()
	return self.tokens[self.index]
end
function Parser:read()
	local token = self:peek()
	self.index = self.index + 1
	self.line = token.line
	return token
end

function Parser:parseProgram()
	local body = self:parseBody()
	local token = self:peek()
	
	if token then
		self:error("Expected end of program, got %q", token.value)
	end
	return body
end
function Parser:parseValue()
	local token = self:peek()
	if not token then
		self:error("Expected value, got nothing")
	end
	local content = token.value
	
	if token.type == "[" then
		return self:parseObject()
	elseif token.type == "(" then
		self:read()
		local expr = self:parseExpression()
		
		local token = self:read()
		if token.type ~= ")" then
			self:error("Expected closed parenthesis, got %q", token.value)
		end
		
		return expr
	elseif token.type == "word" then
		return self:parseVariable()
	elseif token.type == "literal" then
		return self:read()
	end
	
	self:error("Expected value, got %q", token.value)
end
function Parser:parseVariable()
	local token = self:read()
	if token.type ~= "word" then
		self:error("Expected variable, got %q", token.value)
	end
	return self:createTerm("variable", {name = token.value})
end
function Parser:parseObject()
	self:read()
	
	local object = self:createTerm("object")
	
	local token = self:peek()
	if not token then
		self:error("Expected object body, got nothing")
	elseif token.type == "\\" then
		self:read()
		table.insert(object, self:parseDecoration())
	elseif token.type == "]" then
		return object
	else
		table.insert(object, self:parseMethod())
	end
	
	while true do
		token = self:read()
		
		if token.type == "|" then
			table.insert(object, self:parseMethod())
		elseif token.type == "\\" then
			table.insert(object, self:parseDecoration())
		elseif token.type == "]" then
			break
		else
			self:error("Expected object body, got %q", token.value)
		end
	end
	
	return object
end
function Parser:parseMethod()
	local method = self:parseMethodSignature()
	method.body = self:parseBody()
	
	return method
end
function Parser:parseMethodSignature()
	local method = self:createTerm("method", {parameters = self:createTerm("parameters")})
	local token = self:read()
	if not token then
		self:error("Expected method signature, got nothing")
	elseif token.type ~= "word" and token.type ~= "message starter" and token.type ~= "operation" then
		self:error("Expected method signature, got %q", token.value)
	end
	local name = token.value
	method.message = name
	
	-- Multiary message
	if token.type == "message starter" then
		while true do
			table.insert(method.parameters, self:parseVariable().name)
			
			local token = self:peek()
			if not token then
				self:error("Expected method signature, got nothing")
			end
			local content = token.value
			if token.type ~= "message continuer" then
				break
			end
			
			self:read()
			method.message = method.message .. content
		end
	-- Binary operation
	elseif token.type == "operation" then
		method.parameters[1] = self:parseVariable().name
	end
	
	return method
end
function Parser:parseDecoration()
	return self:createTerm("decoration", {target = self:parseExpression()})
end
function Parser:parseBody()
	local body = self:createTerm("body")
	
	local token = self:peek()
	if not token or self.bodyClosers[token.type] then
		return body
	end
	while true do
		table.insert(body, self:parseExpression())
		token = self:peek()
		
		if token and token.type == "." then
			self:read()
			
			local nextToken = self:peek()
			if not nextToken or self.bodyClosers[nextToken.type] then
				break
			end
		else
			break
		end
	end
	
	return body
end
function Parser:parseExpression()
	return self:parseExprDefinition(self:parseValue())
end
function Parser:getPrecedence(token)
	if self.symbols[token.type] or token.type == "message continuer" then
		return -1
	elseif token.type == "definition" then
		return 0
	elseif token.type == "message starter" then
		return 1
	elseif token.type == "operation" then
		return 2
	elseif token.type == "word" then
		return 3
	end
end
function Parser:parseExprDefinition(value)
	-- Figure out the message segment. If there is no segment, just return.
	local message = self:peek()
	local prec = self:getPrecedence(message)
	
	-- Send it off to other functions if it's higher precedence
	if prec > 0 then
		return self:parseExprDefinition(self:parseExprKeywordMsg(value))
	elseif prec < 0 then
		return value
	end
	self:read()
	
	-- Only variables can be on the left-hand side of a definition!
	if value.type ~= "variable" then
		self:error("Expected variable name")
	end
	
	-- Get the right-hand side and create the definition
	-- Use 'parseExprDefinition' here because definition is best right-associative
	value = self:createTerm("definition", {name = value.name, value = self:parseExprDefinition(self:parseValue())})
	
	-- Loop all over again
	return self:parseExprDefinition(value)
end
function Parser:parseExprKeywordMsg(value)
	-- Figure out the message segment. If there is no segment, just return.
	local message = self:peek()
	local prec = self:getPrecedence(message)
	
	-- If this is an operation or unary message, send it off to other functions
	if prec > 1 then
		return self:parseExprKeywordMsg(self:parseExprBinaryMsg(value))
	elseif prec < 1 then
		return value
	end
	self:read()
	
	-- Get the right-hand side
	local nextValue = self:parseExprBinaryMsg(self:parseValue())
	value = self:createTerm("send", {receiver = value, message = message.value, nextValue})
	
	local nextToken = self:peek()
	while nextToken and nextToken.type == "message continuer" do
		self:read()
		value.message = value.message .. nextToken.value
		table.insert(value, self:parseExprBinaryMsg(self:parseValue()))
		
		nextToken = self:peek()
	end
	
	-- Loop all over again
	return self:parseExprKeywordMsg(value)
end
function Parser:parseExprBinaryMsg(value)
	-- Figure out the message segment. If there is no segment, just return.
	local message = self:peek()
	local prec = self:getPrecedence(message)
	
	-- If this is a unary message, send it off to other functions
	-- If this is a multiary message, our caller will handle that
	if prec > 2 then
		return self:parseExprBinaryMsg(self:parseExprUnaryMsg(value))
	elseif prec < 2 then
		return value
	end
	self:read()
	
	value = self:createTerm("send", {receiver = value, message = message.value, self:parseExprUnaryMsg(self:parseValue())})
	
	-- Loop all over again
	return self:parseExprBinaryMsg(value)
end
function Parser:parseExprUnaryMsg(value)
	-- Figure out the message segment. If there is no segment, just return.
	local message = self:peek()
	local prec = self:getPrecedence(message)
	
	-- If this is not a unary message, our caller will handle that
	if prec < 3 then
		return value
	end
	self:read()
	
	value = self:createTerm("send", {receiver = value, message = message.value})
	
	-- Loop all over again
	return self:parseExprUnaryMsg(value)
end