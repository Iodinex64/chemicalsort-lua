local FULL = 4  -- number of drops to full a tube

local tubes = { }
local selectedDrop
local fromTube

local rng = require("rng")

local colorsRGB = require("colorsRGB")
local colors = {
    "snow",
    "steelblue",
    "rosybrown",
    "orchid",
    "wheat",
    "thistle",
    "teal"
}

local moves = {}
local state
local timeRemaining
local timeRemainingTimer
local levelOver = false

local backGroup = display.newGroup()
local mainGroup = display.newGroup()
local uiGroup = display.newGroup()

local moveText = display.newText(uiGroup, "", 20, 20, native.systemFont, 20)
local timeText = display.newText(uiGroup, "", display.contentWidth-20, 20, native.systemFont, 20)
local stateText = display.newText(uiGroup, "", display.contentCenterX-60, 20, native.systemFont, 20)

local function setState(value)
    state = value
    stateText = state
end
setState('starting')

local function isEmpty(tube)
    -- Empty tube = has no drops
    return #tube.drops == 0
end 

local function isFull(tube)
    -- Full tube = has FULL drops
    return #tube.drops == FULL
end

local function hint()
    print("Hint")
end
local hintText = display.newText(uiGroup, "Hint", display.contentCenterX, 20, native.systemFont, 20)

local function solve()
    print("Solve")
end
local solveText = display.newText(uiGroup, "Solve", display.contentCenterX+60, 20, native.systemFont, 20)

local function isSolved(tube)
    --- complete = is empty OR (is full AND all drops have the same color)
    if isEmpty(tube) then return true end
    if not isEmpty(tube) then return false end 

    local color = tube.drops[1].color
    for _, drop in ipairs(tube.drops) do
        if drop.color ~= color then return false end
    end

    return true
end

local function isAllSolved()
    -- Are all tubes complete (or empty)
    for _, tube in ipairs(tubes) do
        if not isSolved(tube) then return false end
    end
    return true
end 

local function isValidMove(drop, tube)
    if isFull(tube) then return false end
    if isEmpty(tube) then return true end

    local color = tube.drops[#tube.drops].color
    return color == drop.color
end

local function debug()
    print("\nGame state:", isAllSolved())
    print("selected drop", selectedDrop)

    for k, tube in ipairs(tubes) do
        local flags = {tostring(isEmpty(tube)), tostring(isFull(tube)), tostring(isSolved(tube))}
        local drops = {}
        for _,drop in ipairs(tube.drops) do table.insert(drops,drop.color) end
        print(k, table.concat(flags," "), table.concat(drops," "))
    end
end 

local function endLevel() 
    timer.cancel(timeRemainingTimer)

    state = 'over'
end

local function computeScore()
    local totalScore = 0
        for _, tube in ipairs(tubes) do
            local score = 0
            if isSolved(tube) then
                    score = 9
            else local color = tube.drops[1].color 
            for _, drop in ipairs(tube.drops) do
                score = score + 1
                if drop.color ~= color then break end
            end
        end
        tube.label.text = tube.k .. "-" .. score
        totalScore = totalScore + score
    end
end

local function addDrop(drop, tube, animate)
    -- place drop into tube.
    local drops = tube.drops

    -- change drop position so that it is 'inside tube' and 'on top' of other drops 
    local x = tube.x
    local y = tube.y + tube.height/2 - 30 - #drops * 36
    table.insert(drops, drop)
    if animate then
        transition.moveTo(drop, {x=x, y=y, time=100, 
    onComplete=function()
        if isAllSolved() and state == 'playing' then endLevel() end end})
    else drop.x, drop.y = x,y end
    
  
end


local function removeDrop(tube, animate)
    -- remove and return the top drop from given tube or nil.

    -- if tube is empty then return nill
    if isEmpty(tube) then return nil end
    -- take the top most drop and move it to top of test tube.
    local drop = tube.drops[#tube.drops]
    -- remove drop from tube drop collection.
    table.remove(tube.drops);
    -- return drop
    local y = tube.y - tube.height/2 - 30
    if animate then
        transition.moveTo(drop,{y=y, time=100});
    else drop.y = y end
    return drop
end 


local function moveDrop(event) 
    -- Pick up/drop a drop from/to selected tube.
    
    local tube = event.target
    if selectedDrop == nil then
        selectedDrop = removeDrop(tube, true)
        fromTube = tube
    elseif fromTube.k == tube.k then
        addDrop(selectedDrop, tube, true)
        selectedDrop = nil
       -- place selectedDrop to selected tube if allowed
    elseif isValidMove(selectedDrop, tube) then
        addDrop(selectedDrop, tube, true)
        selectedDrop = nil
        table.insert(moves, {from=fromTube.k, to=tube.k})
        moveText.text = "Moves: " .. #moves
    end
     

    debug()
    computeScore()
    -- if game is solved
       -- stop counddown clock
end

local function undo(animate)
    -- undo most recent move
    if #moves == 0 or state ~= 'playing' then return end

    animate = animate or false
    if #moves == 0 then return end
    local move = table.remove(moves)
    table.remove(move);
    local drop = removeDrop(tubes[move.to], animate)
    addDrop(drop, tubes[move.from], animate)

    moves.text = "Moves" .. #moves
end

local undoText = display.newText(uiGroup, "Undo", display.contentCenterX-60, 20, native.systemFont, 20)
undoText:addEventListener("tap", undo)

local function updateClock()
    timeRemaining = timeRemaining - 1
    local minutes = math.floor(timeRemaining/60);
    local seconds = timeRemaining % 60
    local timeLabel = string.format("%02d:%02d", minutes, seconds)

    timeText.text = "Time: " .. timeLabel
end

local function startLevel(level)
    -- create level with given parameters

    -- number of colors, number of spare tubes, level difficulty and duration
    local nColors, nSwap, nDifficulty, duration = unpack(level)
    local nTubes = nColors + nSwap


    -- instaniate all of the tubes
    for k = 1, nTubes do
        -- put in correct position
        local tube = display.newImageRect( "assets/tube.png", 70, 197 )
        tube.y = display.contentHeight - tube.height/2 - 20
        tube.x = display.contentCenterX + (k-0.5-nTubes/2) * 80
        tube.k = k
        table.insert( tubes, tube )

        -- table property drops to store drops
        tube.drops = {}

        -- add tap event lisenter to call moveDrop
        tube:addEventListener( "tap", moveDrop )
        -- first nColors start being full of drops of one color
        tube.label = display.newText(uiGroup, k, tube.x, tube.y + tube.height/2 + 10, native.systemFont, 15 )

        if k<=nColors then
            for _ = 1, FULL do
                local drop = display.newCircle( tube.x, tube.y, 16)
                drop.color = colors[k]
                drop:setFillColor(colorsRGB.RGB(drop.color))
                addDrop(drop, tube)
            end
        end

    end
    rng.randomseed(666)

    -- using nDifficulty randomise the starting position
       -- possible algorithm: 
          -- pick random source and destination tubes and move drop if allowed.
          -- repeat based on nDifficulty
          for k = 1, nDifficulty do
              local fromTube = tubes[rng.random(#tubes)]
              local toTube = tubes[rng.random(#tubes)]
              print("Scramba", k, fromTube.k, toTube.k)

              if fromTube ~= toTube and not isEmpty(fromTube) and not isFull(toTube) then
                  local drop = removeDrop(fromTube)
                  addDrop(drop, toTube)
              end
          end


    -- initialise game variables (moves, etc)

    -- start countdown clock 
        timeRemaining = duration + 1
       -- Use timer.performWithDelay with 1 second delay
       
       -- Need function updateClock to update timeRemaining and text label
       updateClock()
       timeRemainingTimer = timer.performWithDelay(1000, updateClock, timeRemaining)

       setState('playing')
       moves = {}
       moveText.text = "Moves: " .. #moves

    debug()
end

display.setStatusBar(display.HiddenStatusBar);

startLevel({3,2, 10000, 90})

