math.randomseed(os.time())

dofile("./reader.lua")
dofile("./lexer.lua")
dofile("./parser.lua")
dofile("./interpreter.lua")

local interpreter = Interpreter:new()
local env = Interpreter:createEnv()

while true do
	local code = io.read("*l")
	local status, err = pcall(function ()
		return interpreter:run(Parser:new():parse(Lexer:new():lex(code)), env)
	end)
	
	local printStatus, err = pcall(function ()
		return interpreter:runMethod(err, "makeString")
	end)
	print(err)
end