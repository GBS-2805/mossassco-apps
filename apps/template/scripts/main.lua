-- Template app — copy this folder, rename it, change the drawing.
-- Demonstrates: safe-area layout, dirty-flag redraw, touch edge detection.

local display = require("display")
local delay = require("delay")

local screen = display.open()
local info = screen:info()
local has_touch = info.touch_available

local taps = 0
local dirty = true
local pressed = false

local function draw()
  screen:begin({ clear = "#0b1220" })
  screen:text(150, 148, "MOSSASSCO", { font_size = 20, color = "#5bd1ff" })
  screen:text(176, 200, tostring(taps), { font_size = 48, color = "#e8eef8" })
  screen:text(150, 300, "tap the screen", { font_size = 14, color = "#7d8ea6" })
  screen:present()
  dirty = false
end

local function poll_touch()
  if not has_touch then return false end
  local ok, t = pcall(function() return screen:touch() end)
  if not ok or not t or not t.points then return false end
  return #t.points > 0
end

draw()

while true do
  delay.delay_ms(30)

  local touching = poll_touch()
  if touching and not pressed then
    taps = taps + 1
    dirty = true
  end
  pressed = touching

  if dirty then draw() end
end
