return function()
	local CollectionService = game:GetService("CollectionService")
	local Binder = require(script.Parent.Binder)

	local seq = 0
	local function uniqueTag(prefix: string): string
		seq += 1
		return `LucyBinderSpec_{prefix}_{seq}`
	end

	local function makeRoot(): Folder
		local root = Instance.new("Folder")
		root.Name = "BinderSpecRoot"
		root.Parent = workspace
		return root
	end

	it("binds existing and newly tagged instances and cleans up on tag removal", function()
		local tag = uniqueTag("basic")
		local root = makeRoot()
		local cleaned = 0

		local existing = Instance.new("Part")
		existing.Name = "Existing"
		existing.Parent = root
		CollectionService:AddTag(existing, tag)

		local binder = Binder.new(tag, function(inst, maid)
			maid:give(function()
				cleaned += 1
			end)
			return inst.Name
		end, { ancestor = root })

		expect(binder:has(existing)).to.equal(true)
		expect(binder:get(existing)).to.equal("Existing")
		expect(binder:count()).to.equal(1)

		local later = Instance.new("Part")
		later.Name = "Later"
		later.Parent = root
		CollectionService:AddTag(later, tag)

		expect(binder:has(later)).to.equal(true)
		expect(binder:get(later)).to.equal("Later")
		expect(binder:count()).to.equal(2)

		CollectionService:RemoveTag(existing, tag)
		expect(binder:has(existing)).to.equal(false)
		expect(binder:get(existing)).to.equal(nil)
		expect(binder:count()).to.equal(1)
		expect(cleaned).to.equal(1)

		binder:destroy()
		expect(binder:count()).to.equal(0)
		expect(cleaned).to.equal(2)
		root:Destroy()
	end)

	it("respects ancestor when instances move in and out", function()
		local tag = uniqueTag("ancestor")
		local root = makeRoot()
		local storage = Instance.new("Folder")
		local cleaned = 0

		local part = Instance.new("Part")
		part.Parent = storage
		CollectionService:AddTag(part, tag)

		local binder = Binder.new(tag, function(_inst, maid)
			maid:give(function()
				cleaned += 1
			end)
			return true
		end, { ancestor = root })

		expect(binder:has(part)).to.equal(false)
		expect(binder:count()).to.equal(0)

		part.Parent = root
		expect(binder:has(part)).to.equal(true)
		expect(binder:count()).to.equal(1)

		part.Parent = storage
		expect(binder:has(part)).to.equal(false)
		expect(binder:count()).to.equal(0)
		expect(cleaned).to.equal(1)

		binder:destroy()
		part:Destroy()
		storage:Destroy()
		root:Destroy()
	end)

	it("supports class tables with .new and auto-cleans destroyable objects", function()
		local tag = uniqueTag("class")
		local root = makeRoot()
		local destroyed = 0

		local Door = {}
		Door.__index = Door
		function Door.new(inst: Instance)
			return setmetatable({ inst = inst }, Door)
		end
		function Door:destroy()
			destroyed += 1
		end

		local binder = Binder.new(tag, Door, { ancestor = root })
		local part = Instance.new("Part")
		part.Parent = root
		CollectionService:AddTag(part, tag)

		expect(binder:get(part).inst).to.equal(part)
		binder:destroy()
		expect(destroyed).to.equal(1)
		root:Destroy()
	end)

	it("tracks side-effect-only bindings that return nil but give tasks to maid", function()
		local tag = uniqueTag("sideeffect")
		local root = makeRoot()
		local cleaned = 0

		local binder = Binder.new(tag, function(inst, maid)
			if not inst:IsA("BasePart") then
				return nil
			end
			maid:give(function()
				cleaned += 1
			end)
			return nil
		end, { ancestor = root })

		local folder = Instance.new("Folder")
		folder.Parent = root
		CollectionService:AddTag(folder, tag)
		expect(binder:has(folder)).to.equal(false)

		local part = Instance.new("Part")
		part.Parent = root
		CollectionService:AddTag(part, tag)
		expect(binder:has(part)).to.equal(true)

		binder:destroy()
		expect(cleaned).to.equal(1)
		root:Destroy()
	end)

	it("isolates errors per instance and fires added/removed signals", function()
		local tag = uniqueTag("errors")
		local root = makeRoot()
		local warned = {}
		local addedCount = 0
		local removedCount = 0

		local binder = Binder.new(tag, function(inst)
			if inst.Name == "Bad" then
				error("kaboom")
			end
			return inst.Name
		end, {
			ancestor = root,
			warn = function(msg)
				table.insert(warned, msg)
			end,
		})

		binder.added:Connect(function()
			addedCount += 1
		end)
		binder.removed:Connect(function()
			removedCount += 1
		end)

		local bad = Instance.new("Part")
		bad.Name = "Bad"
		bad.Parent = root
		CollectionService:AddTag(bad, tag)

		local good = Instance.new("Part")
		good.Name = "Good"
		good.Parent = root
		CollectionService:AddTag(good, tag)

		expect(#warned).to.equal(1)
		expect(binder:has(bad)).to.equal(false)
		expect(binder:has(good)).to.equal(true)
		expect(addedCount).to.equal(1)

		binder:destroy()
		expect(removedCount).to.equal(1)
		root:Destroy()
	end)
end
