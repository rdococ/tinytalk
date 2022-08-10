dofile("./parser.lua")

local attributes = {
	"name",
	"value",
	"receiver",
	"message",
	"parameters",
	"body",
}
local function prettyify(term, tabs)
	tabs = tabs or ""
	if type(term) == "string" then return ("%q"):format(term) end
	if type(term) ~= "table" then return tostring(term) end
	
	local str = {("%s {\n"):format(term.type)}
	
	local tabs2 = tabs .. "\t"
	
	for _, k in ipairs(attributes) do
		local v = term[k]
		if v ~= nil then
			table.insert(str, ("%s%s: %s\n"):format(tabs2, k, prettyify(v, tabs2)))
		end
	end
	for k, v in ipairs(term) do
		table.insert(str, ("%s[%s]: %s\n"):format(tabs2, k, prettyify(v, tabs2)))
	end
	
	table.insert(str, ("%s}"):format(tabs))
	
	return table.concat(str)
end


local ast = Parser:new():parse([[
(define list {
	((cons h t) {((match c) (c cons h t))})
	((nil) {((match c) (c nil))})
})
(define l (list cons "x" nil))
(l match {
	((nil) "List is empty!")
	((cons h t) "List is not empty!")
})
]])

print(prettyify(ast))

return