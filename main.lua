-- Game of Life
DESCRIPTION = {
  "  Rules:",
  "        ",
  "    1. Any live cell with fewer than two live neighbours dies, as if caused by under-population.",
  "    2. Any live cell with two or three live neighbours lives on to the next generation.",
  "    3. Any live cell with more than three live neighbours dies, as if by overcrowding.",
  "    4. Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.",
  "        "
}

MAXHEALTH = 3
HUD = {}
color = {
  red    = {231,  76,  60}, -- red
  blue   = {52,  152, 219}, -- blue
  green  = {46,  204, 113}, -- green
  yellow = {241, 196,  15}  -- yellow
}

resy         = 720
resx         = 1280
aspect_ratio = resx/resy
height       = 600

local aspect_rate_nazi = true
if aspect_rate_nazi then
  width = height * aspect_ratio
else
  width = 367
end
table.insert(DESCRIPTION, 'Aspect ratio: ' .. aspect_ratio);
table.insert(DESCRIPTION, 'Map width:    ' .. width);
table.insert(DESCRIPTION, 'Map height:   ' .. height);

scale       = 0.6
height      = math.floor(height * scale)
width       = math.floor(width  * scale)
cellwidth   = resx/width
cellheight  = resy/height

-- TODO: optimization by limiting the area rendered
limit_left  = 1
limit_right = width
limit_up    = 1
limit_down  = height

function paint(c)
  love.graphics.setColor(c[1], c[2], c[3])
end

function love.load()
  math.randomseed(os.time())
  life105_maps = load_maps("maps")
  map = genmap(height, width)
  print(life105_maps[1])
  mapindex = 1
  love.graphics.setBackgroundColor(210, 215, 205)
  font = love.graphics.newFont("fonts/UbuntuMono-R.ttf", 16)
  love.graphics.setFont(font)
  HUD["filename"] = "Game of life";
end

local running = false
function love.draw()
  love.graphics.setColor(40, 80, 60)
  love.graphics.print(HUD["filename"], 5, 5)
  for y=1, height do
    for x=1, width do
      local health = map[y][x]
      if health > 0 then
        if     health == 3 then paint(color.red)
        elseif health == 2 then paint(color.blue)
        elseif health == 1 then paint(color.green) end
        love.graphics.rectangle("fill", x*(cellwidth)-cellwidth, y*(cellheight)-cellheight, cellwidth, cellheight)
      end
    end
  end
  love.graphics.setColor(120, 120, 120)
  for i=1, #DESCRIPTION do
    love.graphics.print(DESCRIPTION[i], 5, i*15+20)
  end
  decrmap(map)
  map = nextgen(map)
end

function love.update(dt)
  if love.keyboard.isDown("up")  then
    moveMap(0, -0.2 * tileSize * dt)
  end
  if love.keyboard.isDown("down")  then
    moveMap(0, 0.2 * tileSize * dt)
  end
  if love.keyboard.isDown("left")  then
    if   mapindex == 1 then mapindex = #life105_maps
    else mapindex = mapindex - 1 end
    map = genmap(height, width)
    map = loadmap(map, life105_maps[mapindex])
  end
  if love.keyboard.isDown("right")  then
    if   mapindex == #life105_maps then mapindex = 1
    else mapindex = mapindex + 1 end
    map = genmap(height, width)
    map = loadmap(map, life105_maps[mapindex])
  end
end

function load_maps(dir)
  local maps = {}
  local files = love.filesystem.getDirectoryItems(dir)
  for k, file in ipairs(files) do
    table.insert(maps, file)
  end
  return maps
end

function load_file(path)
  local file, errstr = love.filesystem.newFile(path)
  if errstr then
    print(errstr)
    return errstr
  end
  file:open("r")
  return file:read()
end

function loadmap(map, file)
  path = 'maps/'
  file = path..file
  local contents = load_file(file)
  if string.match(contents, "^#Life 1.06") then
    map = loadmap_lif106(map, file)
  elseif string.match(contents, "^#Life 1.05") then
    map = loadmap_lif105(map, file)
  end
  return map
end

-- lif 1.05 format
-- TODO: Custom rulesets
function loadmap_lif105(map, file)
  io.input(file)
  HUD["filename"] = string.match(file, "maps/([%S^.]+)(%.%w+)")
  DESCRIPTION = {}
  local x_orig = math.floor(width  / 2)
  local y_orig = math.floor(height / 2)
  print(x_orig .. " " .. y_orig)
  for line in io.lines() do
    if string.match(line, "^#P") then
      local px, py = string.match(line, "([%-]?%d+) ([%-]?%d+)")
      x = x_orig + px
      y = y_orig + py
    elseif string.match(line, "^#N") then
      -- Apply normal rules
    elseif string.match(line, "^#R") then
      -- Apply alternate rules
    elseif string.match(line, "^#") then -- comment
      print(line)
      local desc = string.match(line, "#D (.*)\r")
      table.insert(DESCRIPTION, desc)
    else
      local i = x
      for c in line:gmatch"." do
        if c == '*' then
          map[y%height+1][i%width+1] = MAXHEALTH
        end
        i = i + 1
      end
      y = y+1
    end
  end
  return map
end

-- lif 1.06 format
function loadmap_lif106(map, file)
  io.input(file)
  for line in io.lines() do
    if string.match(line, "^%d") then
      local x, y = string.match(line, "(%d) (%d)")
      map[y+1][x+1] = MAXHEALTH
    end
  end
  return map
end

local clock = os.clock
function sleep(n)  -- seconds
  local t0 = clock()
  while clock() - t0 <= n do end
end

function genmap()
  map = {}
  for y=1, height do
    map[y] = {}
    for x=1, width do
      map[y][x] = 0
    end
  end
  return map
end

function coinflip()
  if math.random(2) == 2 then return 0 else return MAXHEALTH end
end

function randomize(map)
  for r,row in ipairs(map) do
    for c,col in ipairs(row) do
      map[r][c] = coinflip()
    end
  end
  return map
end

-- returns the number of adjacent living cells
function get_neighbors(map, y, x)
  -- handles wrapping of edges
  if y == 1      then up    = height else up    = y-1 end
  if y == height then down  = 1      else down  = y+1 end
  if x == 1      then left  = width  else left  = x-1 end
  if x == width  then right = 1      else right = x+1 end

  local neighbors = 0
  if map[up   ][left ] > 0 then neighbors = neighbors+1 end
  if map[up   ][x    ] > 0 then neighbors = neighbors+1 end
  if map[up   ][right] > 0 then neighbors = neighbors+1 end
  if map[y    ][left ] > 0 then neighbors = neighbors+1 end
  if map[y    ][right] > 0 then neighbors = neighbors+1 end
  if map[down ][left ] > 0 then neighbors = neighbors+1 end
  if map[down ][x    ] > 0 then neighbors = neighbors+1 end
  if map[down ][right] > 0 then neighbors = neighbors+1 end
  return neighbors
end

-- generate the next population
function nextgen(map)
  local nextmap = genmap(#map, #map[1])
  for r,row in ipairs(map) do
    for c,col in ipairs(row) do
      local health = get_neighbors(map, r, c)
      local alive = map[r][c] > 0
      if alive then
        if     health  < 2 then nextmap[r][c] = 0
        elseif health  > 3 then nextmap[r][c] = 0
        else                    nextmap[r][c] = col end -- if exactly 2 or 3
      elseif not alive then
        if     health == 3 then nextmap[r][c] = MAXHEALTH end
      end
    end
  end
  return nextmap
end

-- fade older cells
function decrmap(map)
  for r,row in ipairs(map) do
    for c,col in ipairs(row) do
      if col > 1 then map[r][c] = col - 1 end
    end
  end
end

function run_tests(map)
  local tests  = 16
  local failed = tests
  if get_neighbors(map, 1, 1) == 3 then failed = failed-1 end
  if get_neighbors(map, 1, 2) == 3 then failed = failed-1 end
  if get_neighbors(map, 1, 3) == 3 then failed = failed-1 end
  if get_neighbors(map, 1, 4) == 2 then failed = failed-1 end
  if get_neighbors(map, 2, 1) == 4 then failed = failed-1 end
  if get_neighbors(map, 2, 2) == 2 then failed = failed-1 end
  if get_neighbors(map, 2, 3) == 2 then failed = failed-1 end
  if get_neighbors(map, 2, 4) == 2 then failed = failed-1 end
  if get_neighbors(map, 3, 1) == 3 then failed = failed-1 end
  if get_neighbors(map, 3, 2) == 3 then failed = failed-1 end
  if get_neighbors(map, 3, 3) == 3 then failed = failed-1 end
  if get_neighbors(map, 3, 4) == 2 then failed = failed-1 end
  if get_neighbors(map, 4, 1) == 3 then failed = failed-1 end
  if get_neighbors(map, 4, 2) == 2 then failed = failed-1 end
  if get_neighbors(map, 4, 3) == 1 then failed = failed-1 end
  if get_neighbors(map, 4, 4) == 2 then failed = failed-1 end
  print("Test results:")
  print("Successful", tests - failed, "Failed", failed)
end

function test_neighbors()
  local map = genmap(4, 4)
  map[1][1] = 1
  map[1][2] = 0
  map[1][3] = 0
  map[1][4] = 0
  map[2][1] = 0
  map[2][2] = 1
  map[2][3] = 0
  map[2][4] = 1
  map[3][1] = 1
  map[3][2] = 0
  map[3][3] = 0
  map[3][4] = 0
  map[4][1] = 0
  map[4][2] = 1
  map[4][3] = 0
  map[4][4] = 0
  return map
end

