-- Tetris for ESP-Mosaico (ESP-Claw Lua app)
-- Touch: bottom strip  [ < left | rotate | right > ]
-- Tap the playfield to drop the piece one row. Tap to restart after game over.

local display = require("display")
local delay = require("delay")

local COLS, ROWS, CELL = 10, 18, 16
local BX, BY = 56, 96           -- playfield top-left
local TICK_MS = 20

local SHAPES = {
  { "#5bd1ff", { {0,1},{1,1},{2,1},{3,1} } }, -- I
  { "#ffd166", { {1,0},{2,0},{1,1},{2,1} } }, -- O
  { "#c792ea", { {0,1},{1,1},{2,1},{1,0} } }, -- T
  { "#7ee787", { {1,1},{2,1},{0,0},{1,0} } }, -- S
  { "#ff7b72", { {0,1},{1,1},{1,0},{2,0} } }, -- Z
  { "#79c0ff", { {0,0},{0,1},{1,1},{2,1} } }, -- J
  { "#ffa657", { {2,0},{0,1},{1,1},{2,1} } }, -- L
}

local screen = display.open()
local info = screen:info()
local has_touch = info.touch_available

local board, piece, px, py, pcolor
local score, lines, level, fall_ms, fall_timer
local dirty, game_over
local seed = 20260101

local function rand(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return (seed % n) + 1
end

local function empty_row()
  local r = {}
  for x = 1, COLS do r[x] = nil end
  return r
end

local function reset()
  board = {}
  for y = 1, ROWS do board[y] = empty_row() end
  score, lines, level = 0, 0, 1
  fall_ms, fall_timer = 550, 0
  game_over = false
  piece = nil
  dirty = true
end

local function collides(nx, ny, cells)
  for i = 1, #cells do
    local c = cells[i]
    local x, y = nx + c[1], ny + c[2]
    if x < 1 or x > COLS or y > ROWS then return true end
    if y >= 1 and board[y][x] ~= nil then return true end
  end
  return false
end

local function spawn()
  local s = SHAPES[rand(#SHAPES)]
  pcolor = s[1]
  piece = {}
  for i = 1, #s[2] do piece[i] = { s[2][i][1], s[2][i][2] } end
  px, py = 4, 1
  if collides(px, py, piece) then game_over = true end
  dirty = true
end

local function try_move(dx)
  if game_over or not piece then return end
  if not collides(px + dx, py, piece) then px = px + dx; dirty = true end
end

local function try_rotate()
  if game_over or not piece then return end
  local r = {}
  for i = 1, #piece do r[i] = { 4 - piece[i][2], piece[i][1] } end
  if not collides(px, py, r) then piece = r; dirty = true end
end

local function try_down()
  if game_over or not piece then return end
  if not collides(px, py + 1, piece) then
    py = py + 1
    dirty = true
    return true
  end
  return false
end

local function lock()
  for i = 1, #piece do
    local x, y = px + piece[i][1], py + piece[i][2]
    if y >= 1 and y <= ROWS and x >= 1 and x <= COLS then board[y][x] = pcolor end
  end

  local cleared = 0
  local y = ROWS
  while y >= 1 do
    local full = true
    for x = 1, COLS do
      if board[y][x] == nil then full = false; break end
    end
    if full then
      table.remove(board, y)
      table.insert(board, 1, empty_row())
      cleared = cleared + 1
    else
      y = y - 1
    end
  end

  if cleared > 0 then
    local pts = { 0, 100, 300, 500, 800 }
    score = score + pts[cleared] * level
    lines = lines + cleared
    level = math.floor(lines / 10) + 1
    fall_ms = math.max(110, 550 - (level - 1) * 45)
  end

  piece = nil
  spawn()
end

local function draw()
  screen:begin({ clear = "#0b1220" })

  screen:fill_round_rect(BX - 4, BY - 4, COLS * CELL + 8, ROWS * CELL + 8, 10, "#111b2e")

  for x = 0, COLS do
    local gx = BX + x * CELL
    screen:line(gx, BY, gx, BY + ROWS * CELL, "#1b2740")
  end
  for y = 0, ROWS do
    local gy = BY + y * CELL
    screen:line(BX, gy, BX + COLS * CELL, gy, "#1b2740")
  end

  for y = 1, ROWS do
    for x = 1, COLS do
      local c = board[y][x]
      if c then
        screen:fill_rect(BX + (x - 1) * CELL + 1, BY + (y - 1) * CELL + 1, CELL - 2, CELL - 2, c)
      end
    end
  end

  if piece and not game_over then
    for i = 1, #piece do
      local gx, gy = px + piece[i][1], py + piece[i][2]
      if gy >= 1 then
        screen:fill_rect(BX + (gx - 1) * CELL + 1, BY + (gy - 1) * CELL + 1, CELL - 2, CELL - 2, pcolor)
      end
    end
  end

  screen:text(246, 116, "TETRIS", { font_size = 26, color = "#e6edf3" })
  screen:text(246, 160, "Score " .. score, { font_size = 18, color = "#9fb0c7" })
  screen:text(246, 186, "Lines " .. lines, { font_size = 18, color = "#9fb0c7" })
  screen:text(246, 212, "Level " .. level, { font_size = 18, color = "#9fb0c7" })

  screen:text(150, 416, "< rotate >", { font_size = 18, color = "#7d8ea6" })

  if game_over then
    screen:fill_round_rect(96, 218, 288, 92, 14, 0xE60b1220)
    screen:text(126, 236, "GAME OVER", { font_size = 26, color = "#ff7b72" })
    screen:text(150, 274, "tap to restart", { font_size = 18, color = "#e6edf3" })
  end

  screen:present()
  dirty = false
end

local touch_ok = has_touch
local function read_point()
  if not touch_ok then return nil end
  local ok, t = pcall(function() return screen:touch() end)
  if not ok or not t then touch_ok = false; return nil end
  local pts = t.points
  if not pts or #pts == 0 then return nil end
  return pts[1]
end

reset()
spawn()
draw()

local tick = 0
local last_action = -1000
local held = false

while true do
  delay.delay_ms(TICK_MS)
  tick = tick + TICK_MS

  local p = read_point()

  if game_over then
    if p and tick - last_action > 400 then
      last_action = tick
      reset()
      spawn()
    end
  else
    if not p then
      held = false
    else
      local is_new = not held
      local repeatable = p.y > 395 and (p.x < 190 or p.x > 290)
      if is_new or (repeatable and tick - last_action > 160) then
        last_action = tick
        if p.y > 395 then
          if p.x < 190 then
            try_move(-1)
          elseif p.x < 290 then
            if is_new then try_rotate() end
          else
            try_move(1)
          end
        elseif is_new then
          try_down()
        end
      end
      held = true
    end

    fall_timer = fall_timer + TICK_MS
    if fall_timer >= fall_ms then
      fall_timer = 0
      if not try_down() and piece then lock() end
    end
  end

  if dirty then draw() end
end
