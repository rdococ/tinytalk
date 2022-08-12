local function copy(tbl, new)
	new = new or {}
	for k, v in pairs(tbl) do
		new[k] = v
	end
	return new
end
local function mapSparse(list, func)
	local new = {}
	for i = 1, #list do
		local v = func(list[i], i)
		new[i] = v
	end
	return new
end
local function maybeMap(list, func)
	local new = {}
	for i, v in ipairs(list) do
		local v = func(v, i)
		if v ~= nil then table.insert(new, v) end
	end
	return new
end
local function chainable(func, id)
	return function (int, ...)
		if select("#", ...) == 0 then return id end
		
		local v = select(1, ...)
		for i = 2, select("#", ...) do
			v = func(int, v, select(i, ...))
		end
		return v
	end
end
local function noint(func)
	if type(func) == "table" then
		local new = {}
		for k, v in pairs(func) do new[k] = noint(v) end
		return new
	end
	return function (int, ...) return func(...) end
end

Interpreter = {}
Interpreter.__index = Interpreter

Interpreter.stringMethods = copy(noint(string), {
	[".."] = chainable(function (int, x, y) return x .. int:runMethod(y, "as-string", {}) end),
	
	size = function (int, s) return #s end,
	at = function (int, s, n) return s:sub(n, n) end,
	
	["<"] = function (int, x, y) return x < y end,
	["="] = function (int, x, y) return x == y end,
	[">"] = function (int, x, y) return x > y end,
	
	["<="] = function (int, x, y) return x <= y end,
	[">="] = function (int, x, y) return x >= y end,
	
	["as-string"] = function (int, s) return s end,
	["as-number"] = noint(tonumber)
})
Interpreter.numberMethods = copy(noint(math), {
	["+"] = chainable(function (int, x, y) return x + int:runMethod(y, "as-number", {}) end, 0),
	["-"] = chainable(function (int, x, y) return x - int:runMethod(y, "as-number", {}) end, 0),
	["*"] = chainable(function (int, x, y) return x * int:runMethod(y, "as-number", {}) end, 1),
	["/"] = chainable(function (int, x, y) return x / int:runMethod(y, "as-number", {}) end, 1),
	["^"] = chainable(function (int, x, y) return x ^ int:runMethod(y, "as-number", {}) end, 1),
	["%"] = function (int, x, y) return x % int:runMethod(y, "as-number", {}) end,
	
	[".."] = chainable(function (int, x, y) return x .. int:runMethod(y, "as-string", {}) end),
	
	negated = function (int, x) return -x end,
	
	["<"] = function (int, x, y) return x < y end,
	["="] = function (int, x, y) return x == y end,
	[">"] = function (int, x, y) return x > y end,
	
	["<="] = function (int, x, y) return x <= y end,
	[">="] = function (int, x, y) return x >= y end,
	
	["as-string"] = noint(tostring),
	["as-number"] = function (int, s) return s end
})
Interpreter.booleanMethods = {
	match = function (int, bool, clause)
		return int:runMethod(clause, bool and "true" or "false", {})
	end,
	
	["and"] = chainable(function (int, x, y) return x and y end, true),
	["or"] = chainable(function (int, x, y) return x or y end, false),
	["not"] = function (int, x) return not x end,
	
	["="] = function (int, x, y) return x == y end,
	
	["as-string"] = function (int, b) return b and "true" or "false" end
}
Interpreter.nilMethods = {
	match = function (int, v, clause)
		return int:runMethod(clause, "nil", {})
	end,
	
	["and"] = chainable(function (int, x, y) return x and y end, true),
	["or"] = chainable(function (int, x, y) return x or y end, false),
	["not"] = function (int, x) return not x end,
	
	["="] = function (int, x, y) return x == y end,
	
	["as-string"] = function (int, b) return "nil" end
}

Interpreter.globals = {
	["true"] = true,
	["false"] = false,
	infinity = math.huge,
	console = {
		type = "builtin",
		print = function (int, self, ...)
			return print(unpack(mapSparse({...}, function (obj)
				return int:runMethod(obj, "as-string", {})
			end)))
		end,
		read = function (int, self) return io.read() end
	},
	cell = {
		type = "builtin",
		new = function (int, self, value)
			return {
				type = "builtin",
				["$"] = function (int, self) return value end,
				[":="] = function (int, self, x) value = x end,
				decoratees = function (int, self) return value end
			}
		end
	}
}

function Interpreter:new()
	return setmetatable({}, self)
end

function Interpreter:run(term)
	return self:runTerm(term, copy(self.globals))
end
function Interpreter:error(err, ...)
	if self.term then
		return error(("Line %s: %s"):format(self.term.line, err:format(...)))
	end
	return error(err:format(...))
end

function Interpreter:runTerm(term, context)
	self.term = term
	if term.type == "body" then
		local result = nil
		for _, subterm in ipairs(term) do
			result = self:runTerm(subterm, context)
		end
		return result
	elseif term.type == "definition" then
		context[term.name] = self:runTerm(term.value, context)
		return context[term.name]
	elseif term.type == "object" or term.type == "procedure" then
		return {type = "instance", definition = term, context = context}
	elseif term.type == "send" then
		local receiver = self:runTerm(term.receiver, context)
		local message = term.message
		local arguments = maybeMap(term, function (v)
			return {value = self:runTerm(v, context)}
		end)
		
		return self:runMethod(receiver, message, arguments)
	elseif term.type == "variable" then
		return context[term.name]
	elseif term.type == "string" or term.type == "number" then
		return term.value
	end
end
function Interpreter:findMethod(receiver, message)
	if type(receiver) == "table" then
		if receiver.type == "instance" then
			local definition, context = receiver.definition, receiver.context
			
			-- Look up method in receiver definition
			if definition.type == "procedure" then
				if message == ":" then
					return receiver, definition
				end
			else
				for _, method in ipairs(definition) do
					if method.type == "method" and method.message == message then
						return receiver, method
					elseif method.type == "decoration" then
						local decoratee, method = self:findMethod(self:runTerm(method.target, context), message)
						if method then return decoratee, method end
					end
				end
			end
		elseif receiver.type == "builtin" then
			if message == "type" or message == "decoratees" then return end
			
			if receiver[message] ~= nil then
				return receiver, receiver[message]
			end
			if receiver.decoratees then
				for _, decoratee in ipairs({receiver.decoratees(self, receiver)}) do
					local realDecoratee, method = self:findMethod(decoratee, message)
					if method then return realDecoratee, method end
				end
			end
		end
	else
		if type(receiver) == "string" then
			return receiver, self.stringMethods[message]
		elseif type(receiver) == "number" then
			return receiver, self.numberMethods[message]
		elseif type(receiver) == "boolean" then
			return receiver, self.booleanMethods[message]
		elseif type(receiver) == "nil" then
			return receiver, self.nilMethods[message]
		end
	end
end
function Interpreter:runMethod(receiver, message, arguments)
	local receiver, method = self:findMethod(receiver, message)
	if not method then return self:error("Message %s not understood", message) end
	
	if type(method) == "table" then
		-- Construct a copy of the receiver's context and assign parameters
		local context = copy(receiver.context)
		for i, arg in ipairs(arguments) do
			arg = arg.value
			
			local param = method.parameters[i]
			if not param then break end
			context[param] = arg
		end
		
		-- Run the method body in the new context
		return self:runTerm(method.body, context)
	elseif type(method) == "function" then
		local args = {}
		for i, arg in ipairs(arguments) do
			args[i] = arg.value
		end
		
		return method(self, receiver, unpack(args, 1, #arguments))
	end
end