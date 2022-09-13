math.randomseed(os.time())

dofile("./reader.lua")
dofile("./lexer.lua")
dofile("./parser.lua")
dofile("./interpreter.lua")

local function getCode()
	print("Enter filename:")
	local file = io.open(("./examples/%s"):format(io.read()))
	local content = file:read("*a")
	file:close()
	
	return content
end

local r
r = Lexer:new():lex(getCode())
r = Parser:new():parse(r)

local result = Interpreter:new():run(r)
print(("\n%s"):format(result))