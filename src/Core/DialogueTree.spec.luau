return function()
	local DialogueTree = require(script.Parent.DialogueTree)

	local function makeClubTree(): DialogueTree.Tree
		return {
			id = "club_nova",
			speaker = "dj_nova",
			entry = { "greet_vip", "greet_default" },
			nodes = {
				greet_vip = {
					when = function(bb)
						return bb:get("flags.Vip") == true
					end,
					text = "Welcome back, {name}. Booth is yours.",
					mood = "smirk",
					next = "hub",
				},
				greet_default = {
					text = "First night at Club Lucy, {name}?",
					audio = "Nova_Greet",
					onEnter = function(bb)
						bb:set("flags.MetNova", true)
					end,
					next = "hub",
				},
				hub = {
					text = "What do you want to know?",
					choices = {
						{
							id = "ask_beat",
							label = "How do combos work?",
							next = "beat_tip",
							once = true,
						},
						{
							id = "secret_set",
							label = "Play the secret set",
							next = "secret_done",
							when = function(bb)
								return (bb:get("score") or 0) >= 100
							end,
							locked = "disable",
							lockedReason = "Score 100+",
							onSelect = function(bb)
								if bb.fire then
									bb:fire("playSecretSet", { track = "midnight" })
								end
							end,
							variant = "default",
						},
						{
							id = "hidden_vip",
							label = "Open backstage",
							next = "secret_done",
							when = function(bb)
								return bb:get("flags.Vip") == true
							end,
							locked = "hide",
						},
						{ id = "leave", label = "See you around.", close = true },
					},
				},
				beat_tip = {
					text = "Stay on the rhythm to climb the leaderboard.",
					next = "hub",
				},
				secret_done = {
					text = "Dropping the secret mix now!",
					isEnd = true,
				},
			},
		}
	end

	it("evaluates Priority Stack entry and runs onEnter actions", function()
		local bb = DialogueTree.blackboard({ name = "Alex", score = 50 })
		local runner = DialogueTree.new(makeClubTree(), bb)
		local snap = runner:start()
		expect(snap).to.be.ok()
		expect(snap.nodeId).to.equal("greet_default")
		expect(snap.text).to.equal("First night at Club Lucy, Alex?")
		expect(snap.audio).to.equal("Nova_Greet")
		expect(bb:get("flags.MetNova")).to.equal(true)

		local bbVip = DialogueTree.blackboard({ name = "Sam", flags = { Vip = true } })
		local vipRunner = DialogueTree.new(makeClubTree(), bbVip)
		local vipSnap = vipRunner:start()
		expect(vipSnap.nodeId).to.equal("greet_vip")
		expect(vipSnap.text).to.equal("Welcome back, Sam. Booth is yours.")
	end)

	it("handles Hub and Spokes, once choices, hidden vs disabled locked choices, and events", function()
		local bb = DialogueTree.blackboard({ name = "Alex", score = 20 })
		local firedPayload = nil
		(bb :: any):onEvent("playSecretSet", function(p)
			firedPayload = p
		end)

		local runner = DialogueTree.new(makeClubTree(), bb)
		runner:start()
		local okAdv, hub = runner:advance()
		expect(okAdv).to.equal(true)
		expect(hub.nodeId).to.equal("hub")
		-- hidden_vip is omitted; secret_set is shown disabled with lockedReason
		expect(#hub.choices).to.equal(3)
		expect(hub.choices[2].id).to.equal("secret_set")
		expect(hub.choices[2].disabled).to.equal(true)
		expect(hub.choices[2].lockedReason).to.equal("Score 100+")

		-- Cannot choose a locked option
		local okLocked = runner:choose("secret_set")
		expect(okLocked).to.equal(false)
		expect(firedPayload).to.equal(nil)

		-- Ask once-only spoke, return to hub, and confirm it is gone
		local okSpoke, tip = runner:choose("ask_beat")
		expect(okSpoke).to.equal(true)
		expect(tip.nodeId).to.equal("beat_tip")

		local _, backAtHub = runner:advance()
		expect(backAtHub.nodeId).to.equal("hub")
		expect(#backAtHub.choices).to.equal(2)

		-- Unlock score gate, choose secret_set, fire event, and reach End Node
		bb:set("score", 150)
		local okSecret, endSnap = runner:choose("secret_set")
		expect(okSecret).to.equal(true)
		expect(firedPayload.track).to.equal("midnight")
		expect(endSnap.isEnd).to.equal(true)

		local okEnd, closed = runner:advance()
		expect(okEnd).to.equal(true)
		expect(closed).to.equal(nil)
		expect(runner:active()).to.equal(false)
	end)

	it("validates trees and reports broken links or duplicate choice ids", function()
		expect(#DialogueTree.validate(makeClubTree())).to.equal(0)

		local bad: DialogueTree.Tree = {
			id = "broken",
			entry = "missing_start",
			nodes = {
				a = {
					text = "Hi",
					next = "ghost",
					choices = {
						{ id = "dup", label = "One", next = "nowhere" },
						{ id = "dup", label = "Two" },
					},
				},
			},
		}
		local errs = DialogueTree.validate(bad)
		expect(#errs).to.equal(4)
	end)
end
