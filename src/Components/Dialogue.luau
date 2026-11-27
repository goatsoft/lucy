--!strict
--[[
	Dialogue (ADR 0060): a themed NPC conversation panel that pairs with Lucy.DialogueTree
	(or server-replicated snapshots). Shows an actor portrait (live R15 Model in a
	ViewportFrame, UserId Avatar, image, or speaker monogram), typewriter text via
	Lucy.useReveal, enabled and locked/disabled choice buttons, and full keyboard,
	gamepad and touch support.

		local dialogue = Lucy.Dialogue.new({
			app = app,
			runner = runner,
			resolveActor = function(speakerId)
				return { name = "DJ Nova", role = "Resident DJ", portrait = novaModel }
			end,
			onCue = function(snap)
				if snap.audio then playVoice(snap.audio) end
			end,
		})
]]

local Avatar = require(script.Parent.Avatar)
local Badge = require(script.Parent.Badge)
local Component = require(script.Parent.Parent.Core.Component)
local Composables = require(script.Parent.Parent.Composables)
local DialogueTree = require(script.Parent.Parent.Core.DialogueTree)
local Element = require(script.Parent.Parent.Core.Element)
local List = require(script.Parent.List)
local Preferences = require(script.Parent.Parent.Core.Preferences)
local Reactive = require(script.Parent.Parent.Core.Reactive)
local Text = require(script.Parent.Text)

export type ActorInfo = {
	name: string?,
	role: string?,
	portrait: (Model | number | string)?,
}

local Dialogue = {}

Dialogue.variants = { "default", "overlay", "inverse" }

local BASE, VARIANT = 0, 10

local rules: { Component.Rule } = {
	{
		selector = ".ui-dialogue-panel",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Card",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-dialogue-panel::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusLg" },
	},
	{
		selector = ".ui-dialogue-panel::UIPadding",
		priority = BASE,
		properties = {
			PaddingLeft = "$Space5",
			PaddingRight = "$Space5",
			PaddingTop = "$Space4",
			PaddingBottom = "$Space4",
		},
	},
	{
		selector = ".ui-dialogue-stroke",
		priority = BASE,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		},
	},
	{
		selector = ".ui-dialogue-portrait",
		priority = BASE,
		properties = {
			BackgroundColor3 = "$Muted",
			BorderSizePixel = 0,
		},
	},
	{
		selector = ".ui-dialogue-portrait::UICorner",
		priority = BASE,
		properties = { CornerRadius = "$RadiusFull" },
	},
	{
		selector = ".ui-dialogue-portrait-stroke",
		priority = BASE,
		properties = {
			Color = "$Border",
			Thickness = "$StrokeThin",
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		},
	},
	{
		selector = ".ui-dialogue-speaker",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$CardForeground",
			FontFace = "$FontSansBold",
			TextSize = "$TextBase",
		},
	},
	{
		selector = ".ui-dialogue-role",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$MutedForeground",
			FontFace = "$FontSans",
			TextSize = "$TextXs",
		},
	},
	{
		selector = ".ui-dialogue-text",
		priority = BASE,
		properties = {
			BackgroundTransparency = 1,
			TextColor3 = "$CardForeground",
			FontFace = "$FontSans",
			TextSize = "$TextBase",
		},
	},
	-- Variants
	{
		selector = ".ui-dialogue-panel.ui-dialogue-variant-overlay",
		priority = VARIANT,
		properties = {
			BackgroundColor3 = "$Popover",
			BackgroundTransparency = 0.08,
		},
	},
	{
		selector = ".ui-dialogue-panel.ui-dialogue-variant-inverse",
		priority = VARIANT,
		properties = {
			BackgroundColor3 = "$Foreground",
		},
	},
	{
		selector = ".ui-dialogue-variant-inverse >> .ui-dialogue-speaker",
		priority = VARIANT,
		properties = { TextColor3 = "$Background" },
	},
	{
		selector = ".ui-dialogue-variant-inverse >> .ui-dialogue-text",
		priority = VARIANT,
		properties = { TextColor3 = "$Background" },
	},
	{
		selector = ".ui-dialogue-variant-inverse >> .ui-list-item",
		priority = VARIANT,
		properties = { TextColor3 = "$Background" },
	},
}
Dialogue.rules = rules

function Dialogue.addVariant(name: string, variantRules: { Component.Rule })
	table.insert(Dialogue.variants, name)
	for _, r in variantRules do
		table.insert(rules, r)
	end
end

local function mountModelPortrait(viewport: ViewportFrame, source: Model)
	viewport:ClearAllChildren()
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local prev = source.Archivable
	source.Archivable = true
	local ok, cloned = pcall(function()
		return source:Clone()
	end)
	source.Archivable = prev
	if not ok or not cloned or not cloned:IsA("Model") then
		return
	end
	for _, desc in cloned:GetDescendants() do
		if
			desc:IsA("LuaSourceContainer")
			or desc:IsA("Sound")
			or desc:IsA("ProximityPrompt")
			or desc:IsA("BillboardGui")
		then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
	cloned:PivotTo(CFrame.new(0, 0, 0))
	cloned.Parent = world

	local head = cloned:FindFirstChild("Head") or cloned.PrimaryPart
	if head and head:IsA("BasePart") then
		local lookAt = head.Position + Vector3.new(0, -0.15, 0)
		local camPos = lookAt
			+ head.CFrame.LookVector * 3.8
			+ head.CFrame.RightVector * 0.45
			+ Vector3.new(0, 0.15, 0)
		camera.CFrame = CFrame.lookAt(camPos, lookAt)
	else
		camera.CFrame = CFrame.lookAt(Vector3.new(0.4, 1.8, -3.8), Vector3.new(0, 1.5, 0))
	end
end

local spec: Component.Spec = {
	kind = "dialogue",
	rules = rules,
	defaults = {
		open = true,
		variant = "default",
		rate = 48,
	},
	render = function(h: Component.Handle)
		local props = h.props
		local app = h.app
		local runner: DialogueTree.Runner? = props.runner
		local resolveActor: ((speakerId: string) -> ActorInfo?)? = props.resolveActor
		local onChoose: ((choiceId: string) -> ())? = props.onChoose
		local onAdvance: (() -> ())? = props.onAdvance
		local onClose: (() -> ())? = props.onClose
		local onCue: ((snapshot: DialogueTree.Snapshot) -> ())? = props.onCue
		local continueLabel = (props.continueText or "Continue") :: string
		local leaveLabel = (props.leaveText or "Leave") :: string
		local revealInstant = props.instant == true or Preferences.reducedMotion()

		-- Unified snapshot ref driven by runner, reactive snapshot prop, or direct props
		local runnerSnap = Reactive.ref(if runner then runner:snapshot() else nil)
		if runner then
			h.maid:give(runner.changed:Connect(function(nextSnap: any)
				runnerSnap(nextSnap)
			end))
		end

		local currentSnap = Reactive.computed(function(): any
			if runner then
				return runnerSnap()
			end
			if props.snapshot ~= nil then
				local s = Reactive.toValue(props.snapshot)
				return if type(s) == "table" then s else nil
			end
			local openVal = Reactive.toValue(if props.open ~= nil then props.open else h:ref("open"))
			if openVal == false then
				return nil
			end
			local choices = Reactive.toValue(props.choices) or {}
			local isEnd = props.isEnd == true
			return {
				treeId = props.id or "dialogue",
				nodeId = props.nodeId or "static",
				speaker = Reactive.toValue(props.speaker) or "",
				role = Reactive.toValue(props.role),
				portrait = Reactive.toValue(props.portrait),
				text = Reactive.toValue(props.text) or "",
				canLeave = if props.canLeave ~= nil then props.canLeave else true,
				canAdvance = if props.canAdvance ~= nil then props.canAdvance else (#choices == 0),
				isEnd = isEnd,
				choices = choices,
			}
		end)

		local isOpen = Reactive.computed(function(): boolean
			return currentSnap() ~= nil
		end)

		local currentText = Reactive.computed(function(): string
			local s = currentSnap()
			return if s and type(s.text) == "string" then s.text else ""
		end)

		local rate = math.max(tonumber(props.rate) or 48, 1)
		local reveal = Composables.useReveal(currentText, { rate = rate })

		local variantClass = Reactive.computed(function(): string
			local v = Reactive.toValue(props.variant) or h:get("variant") or "default"
			return `ui-dialogue-variant-{v}`
		end)

		-- Root panel
		local panel = Element.new("Frame")({
			Name = props.id or "Dialogue",
			Size = props.size or UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = isOpen,
			[Element.on("InputBegan")] = function(input: InputObject)
				if
					(
						input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch
					) and reveal.revealing()
				then
					reveal.skip()
				end
			end,
		}) :: Frame
		panel:AddTag("ui-dialogue-panel")
		Reactive.watchEffect(function()
			for _, v in Dialogue.variants do
				panel:RemoveTag(`ui-dialogue-variant-{v}`)
			end
			panel:AddTag(variantClass())
		end)

		local stroke = Instance.new("UIStroke")
		stroke.Parent = panel
		stroke:AddTag("ui-dialogue-stroke")

		if not props.size then
			local sizeConstraint = Instance.new("UISizeConstraint")
			sizeConstraint.MaxSize = Vector2.new(props.maxWidth or 760, 420)
			sizeConstraint.Parent = panel
		end

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		rowLayout.Padding = UDim.new(0, 20)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = panel

		-- Round portrait frame (96x96 by default so the NPC face reads clearly)
		local portraitSize = props.portraitSize or 96
		local portraitBox = Instance.new("Frame")
		portraitBox.Name = "Portrait"
		portraitBox.Size = UDim2.fromOffset(portraitSize, portraitSize)
		portraitBox.ClipsDescendants = true
		portraitBox.LayoutOrder = 1
		portraitBox.Parent = panel
		local pStroke = Instance.new("UIStroke")
		pStroke.Parent = portraitBox
		portraitBox:AddTag("ui-dialogue-portrait")
		pStroke:AddTag("ui-dialogue-portrait-stroke")

		-- Right column: header (speaker + subtle role subtitle), body text, choices
		local rightCol = Instance.new("Frame")
		rightCol.Name = "Content"
		rightCol.BackgroundTransparency = 1
		rightCol.Size = UDim2.new(1, -(portraitSize + 20), 0, 0)
		rightCol.AutomaticSize = Enum.AutomaticSize.Y
		rightCol.LayoutOrder = 2
		rightCol.Parent = panel
		local colLayout = Instance.new("UIListLayout")
		colLayout.FillDirection = Enum.FillDirection.Vertical
		colLayout.Padding = UDim.new(0, 10)
		colLayout.SortOrder = Enum.SortOrder.LayoutOrder
		colLayout.Parent = rightCol

		local headerCol = Instance.new("Frame")
		headerCol.Name = "Header"
		headerCol.BackgroundTransparency = 1
		headerCol.Size = UDim2.fromScale(1, 0)
		headerCol.AutomaticSize = Enum.AutomaticSize.Y
		headerCol.LayoutOrder = 1
		headerCol.Parent = rightCol
		local headerLayout = Instance.new("UIListLayout")
		headerLayout.FillDirection = Enum.FillDirection.Vertical
		headerLayout.Padding = UDim.new(0, 2)
		headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		headerLayout.Parent = headerCol

		local speakerLabel = Instance.new("TextLabel")
		speakerLabel.Name = "Speaker"
		speakerLabel.AutomaticSize = Enum.AutomaticSize.XY
		speakerLabel.Size = UDim2.fromOffset(0, 0)
		speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
		speakerLabel.LayoutOrder = 1
		speakerLabel.Parent = headerCol
		speakerLabel:AddTag("ui-dialogue-speaker")

		local roleLabel = Instance.new("TextLabel")
		roleLabel.Name = "Role"
		roleLabel.AutomaticSize = Enum.AutomaticSize.XY
		roleLabel.Size = UDim2.fromOffset(0, 0)
		roleLabel.TextXAlignment = Enum.TextXAlignment.Left
		roleLabel.LayoutOrder = 2
		roleLabel.Parent = headerCol
		roleLabel:AddTag("ui-dialogue-role")

		local bodyLabel = Instance.new("TextLabel")
		bodyLabel.Name = "Body"
		bodyLabel.Size = UDim2.fromScale(1, 0)
		bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
		bodyLabel.TextWrapped = true
		bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
		bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
		bodyLabel.LayoutOrder = 2
		bodyLabel.Parent = rightCol
		bodyLabel:AddTag("ui-dialogue-text")

		Reactive.watchEffect(function()
			bodyLabel.Text = currentText()
			if revealInstant then
				bodyLabel.MaxVisibleGraphemes = -1
			else
				bodyLabel.MaxVisibleGraphemes = reveal.visible()
			end
		end)

		local choicesWrap = Instance.new("Frame")
		choicesWrap.Name = "ChoicesWrap"
		choicesWrap.BackgroundTransparency = 1
		choicesWrap.Size = UDim2.fromScale(1, 0)
		choicesWrap.AutomaticSize = Enum.AutomaticSize.Y
		choicesWrap.LayoutOrder = 3
		choicesWrap.Parent = rightCol
		local choicesPad = Instance.new("UIPadding")
		choicesPad.PaddingTop = UDim.new(0, 4)
		choicesPad.Parent = choicesWrap

		local choiceItems = Reactive.ref({} :: { List.ItemSpec })
		local choiceMarker = Reactive.ref("decimal")
		local choiceList = List.new({
			app = app,
			id = "Choices",
			marker = choiceMarker,
			items = choiceItems,
			gap = 2,
			Parent = choicesWrap,
		})
		h.maid:give(choiceList)
		local choicesRow = choiceList.Instance

		local choiceBadges: { any } = {}
		local portraitHandle: any = nil
		local function clearChoices()
			for _, badge in choiceBadges do
				badge:destroy()
			end
			table.clear(choiceBadges)
		end
		local function clearPortrait()
			if portraitHandle then
				portraitHandle:destroy()
				portraitHandle = nil
			end
			for _, child in portraitBox:GetChildren() do
				if not child:IsA("UICorner") and not child:IsA("UIStroke") then
					child:Destroy()
				end
			end
		end
		h.maid:give(clearChoices)
		h.maid:give(clearPortrait)

		local function handleChoose(choiceId: string)
			if reveal.revealing() then
				reveal.skip()
			end
			if runner then
				runner:choose(choiceId)
			end
			if onChoose then
				onChoose(choiceId)
			end
		end

		local function handleAdvance()
			if reveal.revealing() then
				reveal.skip()
				return
			end
			if runner then
				runner:advance()
			end
			if onAdvance then
				onAdvance()
			end
		end

		local function handleClose()
			if runner then
				runner:close()
			end
			if onClose then
				onClose()
			end
		end

		local lastPortraitKey: any = nil
		local lastNodeKey: string? = nil

		Reactive.watchEffect(function()
			local s = currentSnap()
			Reactive.untrack(function()
				clearChoices()
				if not s then
					lastNodeKey = nil
					return
				end

				local actorInfo: ActorInfo? = if resolveActor and type(s.speaker) == "string"
					then resolveActor(s.speaker)
					else nil
				local displayName = (actorInfo and actorInfo.name) or s.actorName or s.speaker or ""
				local displayRole = (actorInfo and actorInfo.role) or s.actorRole or s.role or ""
				local portraitSource = (actorInfo and actorInfo.portrait) or s.portrait

				speakerLabel.Text = displayName
				roleLabel.Text = displayRole
				roleLabel.Visible = #displayRole > 0

				-- Refresh portrait only when the speaker / portrait source changes
				local portraitKey = portraitSource or displayName
				if portraitKey ~= lastPortraitKey then
					lastPortraitKey = portraitKey
					clearPortrait()
					if typeof(portraitSource) == "Instance" and portraitSource:IsA("Model") then
						local vp = Instance.new("ViewportFrame")
						vp.Name = "Viewport"
						vp.Size = UDim2.fromScale(1, 1)
						vp.BackgroundTransparency = 1
						vp.Ambient = Color3.fromRGB(170, 175, 185)
						vp.LightColor = Color3.fromRGB(255, 248, 236)
						vp.LightDirection = Vector3.new(-0.5, -0.7, -0.8)
						vp.Parent = portraitBox
						mountModelPortrait(vp, portraitSource)
					elseif type(portraitSource) == "number" then
						portraitHandle = Avatar.new({
							app = app,
							userId = portraitSource,
							name = displayName,
							size = "lg",
							Parent = portraitBox,
						})
						portraitHandle.Instance.Size = UDim2.fromScale(1, 1)
					elseif type(portraitSource) == "string" and #portraitSource > 0 then
						local img = Instance.new("ImageLabel")
						img.Name = "PortraitImage"
						img.Size = UDim2.fromScale(1, 1)
						img.BackgroundTransparency = 1
						img.ScaleType = Enum.ScaleType.Crop
						img.Image = portraitSource
						img.Parent = portraitBox
					else
						portraitHandle = Avatar.new({
							app = app,
							name = if #displayName > 0 then displayName else "NPC",
							size = "lg",
							Parent = portraitBox,
						})
						portraitHandle.Instance.Size = UDim2.fromScale(1, 1)
					end
				end

				-- Fire onCue once per node transition
				local nodeKey = `{s.treeId or ""}:{s.nodeId or ""}`
				if nodeKey ~= lastNodeKey then
					lastNodeKey = nodeKey
					if onCue then
						onCue(s)
					end
				end

				local choices = s.choices
				local nextItems: { List.ItemSpec } = {}
				if type(choices) == "table" and #choices > 0 then
					choiceMarker("decimal")
					for _, choice in choices do
						local content: any = choice.label
						if
							choice.disabled == true
							and type(choice.lockedReason) == "string"
							and #choice.lockedReason > 0
						then
							local badge = Badge.new({
								app = app,
								text = choice.lockedReason,
								variant = "outline",
								size = "sm",
							})
							table.insert(choiceBadges, badge)
							content = { choice.label, badge }
						end
						local itemVariant = if choice.variant == "default"
								or choice.variant == "primary"
							then "primary"
							elseif choice.variant == "destructive" then "destructive"
							else "default"
						table.insert(nextItems, {
							id = `dialogue-choice-{choice.id}`,
							content = content,
							variant = itemVariant,
							disabled = choice.disabled == true,
							onClick = function()
								if choice.disabled ~= true then
									handleChoose(choice.id)
								end
							end,
						})
					end
				elseif s.canAdvance or s.isEnd then
					choiceMarker("chevron")
					table.insert(nextItems, {
						id = "dialogue-continue",
						marker = ">",
						content = if s.isEnd then leaveLabel else continueLabel,
						variant = "primary",
						disabled = false,
						onClick = function()
							if s.isEnd then
								handleClose()
							else
								handleAdvance()
							end
						end,
					})
				end
				choiceItems(nextItems)

				-- Move gamepad/keyboard focus onto the first selectable choice on each new node
				if app and app.input then
					task.defer(function()
						if not isOpen() then
							return
						end
						for _, child in choicesRow:GetChildren() do
							if child:IsA("TextButton") and child.Selectable and child.Active then
								app.input:focus(child)
								break
							end
						end
					end)
				end
			end)
		end)

		local function firstFocusableChoice(): GuiObject?
			for _, child in choicesRow:GetChildren() do
				if child:IsA("TextButton") and child.Selectable and child.Active then
					return child
				end
			end
			return nil
		end

		-- Capture keyboard and controller focus inside the dialogue panel while open
		Composables.useFocusScope(app, isOpen, {
			root = panel,
			defaultFocus = firstFocusableChoice,
		})

		-- Back handler (B / Backspace): skips typing first, then closes when allowed
		Composables.useBackHandler(app, function(): boolean
			local s = currentSnap()
			if not s then
				return false
			end
			if reveal.revealing() then
				reveal.skip()
				return true
			end
			if s.canLeave ~= false then
				handleClose()
				return true
			end
			return true
		end, isOpen)

		if props.Parent then
			panel.Parent = props.Parent
		else
			local layer = app:portal("modal")
			panel.AnchorPoint = Vector2.new(0.5, 1)
			panel.Position = UDim2.new(0.5, 0, 1, -28)
			panel.Parent = layer
		end

		h.panel = panel
		h.portrait = portraitBox
		h.speaker = speakerLabel
		h.body = bodyLabel
		h.choices = choicesRow
		h.skip = reveal.skip
		h.revealing = reveal.revealing
		h.snapshot = currentSnap
		return panel
	end,
}

Component.define(spec)

-- Expose convenient factory + methods
function Dialogue.new(props: Component.Props?): Component.Handle
	return Component.mount(spec, props)
end

-- Keep Text referenced cleanly for future rich inline formatting extensions
local _ = Text

return Dialogue
