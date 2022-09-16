local function copy(tbl, new)
	new = new or {}
	for k, v in pairs(tbl) do
		new[k] = v
	end
	return new
end
local function mapArgs(list, func)
	local num = 0
	
	local new = {}
	for i = 1, #list - 1 do
		local v = func(list[i], i)
		new[i] = v
		num = num + 1
	end
	
	local values = table.pack(func(list[#list], #list))
	for i = 1, values.n do
		new[num + 1] = values[i]
		num = num + 1
	end
	
	new.n = num
	
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
local function builtin(methods, decoratees)
	return {
		type = "builtin",
		methods = methods,
		decoratees = decoratees
	}
end

Interpreter = {}
Interpreter.__index = Interpreter

Interpreter.stringMethods = {
	[","] = chainable(function (int, x, y) return x .. int:runMethod(y, "makeString") end),
	
	size = function (int, s) return #s end,
	["at:"] = function (int, s, n) return s:sub(n, n) end,
	
	["from:To:"] = noint(string.sub),
	
	["<"] = function (int, x, y) return x < y end,
	["="] = function (int, x, y) return x == y end,
	[">"] = function (int, x, y) return x > y end,
	
	["<="] = function (int, x, y) return x <= y end,
	[">="] = function (int, x, y) return x >= y end,
	
	makeString = function (int, s) return s end,
	makeNumber = noint(tonumber),
	
	type = noint(type)
}
Interpreter.numberMethods = {
	["+"] = chainable(function (int, x, y) return x + int:runMethod(y, "makeNumber") end, 0),
	["-"] = chainable(function (int, x, y) return x - int:runMethod(y, "makeNumber") end, 0),
	["*"] = chainable(function (int, x, y) return x * int:runMethod(y, "makeNumber") end, 1),
	["/"] = chainable(function (int, x, y) return x / int:runMethod(y, "makeNumber") end, 1),
	["^"] = chainable(function (int, x, y) return x ^ int:runMethod(y, "makeNumber") end, 1),
	["%"] = function (int, x, y) return x % int:runMethod(y, "makeNumber") end,
	
	[","] = chainable(function (int, x, y) return x .. int:runMethod(y, "makeString") end),
	
	negate = function (int, x) return -x end,
	
	["<"] = function (int, x, y) return x < y end,
	["="] = function (int, x, y) return x == y end,
	[">"] = function (int, x, y) return x > y end,
	
	["<="] = function (int, x, y) return x <= y end,
	[">="] = function (int, x, y) return x >= y end,
	
	floor = noint(math.floor),
	ceiling = noint(math.ceil),
	round = function (int, x) return math.ceil(x - 0.5) end,
	
	["max:"] = noint(math.max),
	["min:"] = noint(math.min),
	
	makeString = noint(tostring),
	makeNumber = function (int, s) return s end,
	
	type = noint(type)
}
Interpreter.booleanMethods = {
	["match:"] = function (int, bool, clause)
		return int:runMethod(clause, bool and "true" or "false")
	end,
	
	["and:"] = chainable(function (int, x, y) return x and y end, true),
	["or:"] = chainable(function (int, x, y) return x or y end, false),
	["not"] = function (int, x) return not x end,
	
	["="] = function (int, x, y) return x == y end,
	
	makeString = function (int, b) return b and "true" or "false" end,
	
	type = noint(type)
}
Interpreter.nilMethods = {
	["match:"] = function (int, v, clause)
		return int:runMethod(clause, "nil")
	end,
	
	["and:"] = chainable(function (int, x, y) return x and y end, true),
	["or:"] = chainable(function (int, x, y) return x or y end, false),
	["not"] = function (int, x) return not x end,
	
	["="] = function (int, x, y) return x == y end,
	
	makeString = function (int, b) return "nil" end,
	
	type = noint(type)
}

Interpreter.globals = {
	["true"] = true,
	["false"] = false,
	infinity = math.huge,
	console = builtin({
		["print:"] = function (int, self, obj)
			return print(int:runMethod(obj, "makeString"))
		end,
		["write:"] = function (int, self, obj)
			return io.write(int:runMethod(obj, "makeString"))
		end,
		["error:"] = function (int, self, obj)
			return error(int:runMethod(obj, "makeString"))
		end,
		read = function (int, self) return io.read() end
	}),
	Cell = builtin({
		make = function (int, self, value)
			return builtin({
				["get"] = function (int, self) return value end,
				["put:"] = function (int, self, x) value = x end
			}, function (int, self) return value end)
		end,
		["make:"] = function (int, self, value)
			return builtin({
				["get"] = function (int, self) return value end,
				["put:"] = function (int, self, x) value = x end
			}, function (int, self) return value end)
		end
	}),
	library = builtin({
		["fetch:"] = function (int, self, filename)
			filename = int:runMethod(filename, "makeString")
			if int.library[filename] then return int.library[filename] end
			
			local file, err = io.open(filename)
			if not file then self:error(err) end
			
			local content = file:read("*a")
			file:close()
			
			int.library[filename] = int:run(Parser:new():parse(Lexer:new():lex(content)))
			return int.library[filename]
		end
	})
}

function Interpreter:new()
	return setmetatable({library = {}}, self)
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
		local result = {nil}
		for _, subterm in ipairs(term) do
			result = table.pack(self:runTerm(subterm, context))
		end
		return table.unpack(result)
	elseif term.type == "definition" then
		context[term.name] = self:runTerm(term.value, context)
		return context[term.name]
	elseif term.type == "object" then
		return {type = "instance", definition = term, context = context}
	elseif term.type == "send" then
		local receiver = self:runTerm(term.receiver, context)
		local message = term.message
		local arguments = mapArgs(term, function (v)
			if v == nil then return end
			return self:runTerm(v, context)
		end)
		
		return self:runMethod(receiver, message, table.unpack(arguments, 1, arguments.n))
	elseif term.type == "variable" then
		local value = context[term.name]
		
		if type(value) == "table" and value.type == "tuple" then
			return table.unpack(value)
		end
		return value
	elseif term.type == "literal" then
		return term.value
	end
end
function Interpreter:findMethod(receiver, message)
	if type(receiver) == "table" then
		if receiver.type == "instance" then
			local definition, context = receiver.definition, receiver.context
			
			for _, method in ipairs(definition) do
				if method.type == "method" and method.message == message then
					return receiver, method
				elseif method.type == "decoration" then
					local decoratee, method = self:findMethod(self:runTerm(method.target, context), message)
					if method then return decoratee, method end
				end
			end
		elseif receiver.type == "builtin" then
			if receiver.methods[message] ~= nil then
				return receiver, receiver.methods[message]
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
function Interpreter:runMethod(receiver, message, ...)
	local receiver, method = self:findMethod(receiver, message)
	if not method then return self:error("Message %s not understood", message) end
	
	if type(method) == "table" then
		-- Construct a copy of the receiver's context and assign parameters
		local context = copy(receiver.context)
		for i, param in ipairs(method.parameters) do
			--[[if i == #method.parameters and param:sub(-3, -1) == "..." then
				context[param:sub(1, -4)] = select(i, ...)
				context[param] = {type = "tuple", n = select("#", ...) - i + 1, select(i, ...)}
			else]]
				context[param] = select(i, ...)
			--end
		end
		
		-- Run the method body in the new context
		return self:runTerm(method.body, context)
	elseif type(method) == "function" then
		return method(self, receiver, ...)
	end
end