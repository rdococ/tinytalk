dofile("./parser.lua")
dofile("./interpreter.lua")

local function getCode()
	local file = io.open(io.read())
	return file:read("*a")
end

local ast = Parser:new():parse(getCode())
local result = Interpreter:new():run(ast)

print(("\n%s"):format(result))