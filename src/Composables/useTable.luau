--!strict
local TableModel = require(script.Parent.Parent.Core.TableModel)
local requireOwner = require(script.Parent.requireOwner)

local function useTable(options: { [string]: any })
	requireOwner("useTable")
	return TableModel.new(options)
end

return useTable
