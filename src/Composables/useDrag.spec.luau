return function()
	local Composables = require(script.Parent)
	local Reactive = require(script.Parent.Parent.Core.Reactive)

	describe("useDrag", function()
		-- Fake input: InputBegan on the target and UserInputService's InputChanged and InputEnded.
		-- Inputs are plain tables with the fields useDrag reads.
		local function fakeInput()
			local began, changed, ended =
				Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
			return {
				began = began.Event,
				input = { InputChanged = changed.Event, InputEnded = ended.Event },
				press = function(x: number, y: number)
					began:Fire({
						UserInputType = Enum.UserInputType.MouseButton1,
						Position = Vector3.new(x, y, 0),
					})
				end,
				move = function(x: number, y: number)
					changed:Fire({
						UserInputType = Enum.UserInputType.MouseMovement,
						Position = Vector3.new(x, y, 0),
					})
				end,
				release = function()
					ended:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero })
				end,
				destroy = function()
					began:Destroy()
					changed:Destroy()
					ended:Destroy()
				end,
			}
		end

		it("needs an owner", function()
			expect(function()
				Composables.useDrag(Instance.new("Frame"))
			end).to.throw()
		end)

		it("follows a press, the moves and the release", function()
			local fake = fakeInput()
			local log = {}
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					onStart = function(point)
						table.insert(log, `start {point.X},{point.Y}`)
					end,
					onMove = function(delta, point)
						table.insert(log, `move {delta.X},{delta.Y} at {point.X},{point.Y}`)
					end,
					onEnd = function(delta)
						table.insert(log, `end {delta.X},{delta.Y}`)
					end,
				})
			end)
			expect(drag.dragging()).to.equal(false)
			fake.press(10, 20)
			task.wait()
			expect(drag.dragging()).to.equal(true)
			fake.move(15, 18)
			task.wait()
			expect(drag.delta()).to.equal(Vector2.new(5, -2))
			fake.release()
			task.wait()
			expect(drag.dragging()).to.equal(false)
			expect(drag.delta()).to.equal(Vector2.zero)
			expect(table.concat(log, "; ")).to.equal("start 10,20; move 5,-2 at 15,18; end 5,-2")
			scope:stop()
			fake.destroy()
		end)

		it("ignores presses while disabled, and ends a drag when disabled", function()
			local fake = fakeInput()
			local disabled = Reactive.ref(true)
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					disabled = disabled,
				})
			end)
			fake.press(0, 0)
			task.wait()
			expect(drag.dragging()).to.equal(false)
			disabled(false)
			fake.move(4, 4)
			task.wait()
			expect(drag.dragging()).to.equal(false)
			fake.press(1, 1)
			task.wait()
			expect(drag.dragging()).to.equal(true)
			-- turning it off mid drag ends the drag
			disabled(true)
			expect(drag.dragging()).to.equal(false)
			scope:stop()
			fake.destroy()
		end)

		it("cancel() ends a drag, and stopping the owner disconnects it", function()
			local fake = fakeInput()
			local ends = 0
			local moves = 0
			local scope = Reactive.effectScope(true)
			local drag
			scope:run(function()
				drag = Composables.useDrag(Instance.new("Frame"), {
					began = fake.began,
					input = fake.input,
					onMove = function()
						moves += 1
					end,
					onEnd = function()
						ends += 1
					end,
				})
			end)
			fake.press(0, 0)
			task.wait()
			drag.cancel()
			expect(drag.dragging()).to.equal(false)
			expect(ends).to.equal(1)
			fake.move(3, 3)
			task.wait()
			expect(moves).to.equal(0)
			fake.press(0, 0)
			task.wait()
			scope:stop()
			fake.move(3, 3)
			fake.press(0, 0)
			task.wait()
			expect(moves).to.equal(0)
			expect(ends).to.equal(2)
			fake.destroy()
		end)
	end)
end
