local bump = require "lib.bump"
local flux = require "lib.flux"
local moonshine = require "lib.moonshine"
local Camera = require "lib.Camera"

local function approach(val, target, max_move)
    if val > target then
        return math.max(val - max_move, target)
    else
        return math.min(val + max_move, target)
    end
end

local function sign(v)
    return (v > 0 and 1) or (v < 0 and -1) or 0
end

local function playerFilter(item, other)
    if other.isHazard or other.isCheckpoint then return "cross" end
    return "slide"
end

local Engine = {}

Engine.ObjectPool = {}
Engine.ObjectPool.__index = Engine.ObjectPool

function Engine.ObjectPool:new(maxSize, createFunc)
    local pool = setmetatable({}, Engine.ObjectPool)
    pool.objects = {}
    pool.freeIndices = {}
    pool.maxSize = maxSize
    for i = 1, maxSize do
        pool.objects[i] = createFunc()
        pool.objects[i]._active = false
        pool.freeIndices[i] = i
    end
    return pool
end

function Engine.ObjectPool:spawn(setupFunc)
    if #self.freeIndices == 0 then return nil end
    local idx = table.remove(self.freeIndices)
    local obj = self.objects[idx]
    obj._active = true
    obj._poolIdx = idx
    if setupFunc then setupFunc(obj) end
    return obj
end

function Engine.ObjectPool:free(obj)
    if not obj._active then return end
    obj._active = false
    table.insert(self.freeIndices, obj._poolIdx)
end

function Engine.ObjectPool:update(dt, updateFunc)
    for i = 1, self.maxSize do
        local obj = self.objects[i]
        if obj._active then
            local alive = updateFunc(obj, dt)
            if not alive then
                self:free(obj)
            end
        end
    end
end

function Engine.ObjectPool:draw(drawFunc)
    for i = 1, self.maxSize do
        local obj = self.objects[i]
        if obj._active then
            drawFunc(obj)
        end
    end
end

Engine.particles = Engine.ObjectPool:new(200, function()
    return {x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 0, size = 0}
end)

Engine.FSM = {}
Engine.FSM.__index = Engine.FSM

function Engine.FSM:new(target)
    local fsm = setmetatable({}, Engine.FSM)
    fsm.target = target
    fsm.states = {}
    fsm.currentName = nil
    fsm.current = nil
    return fsm
end

function Engine.FSM:addState(name, state)
    self.states[name] = state
end

function Engine.FSM:change(name, ...)
    if self.current and self.current.exit then
        self.current.exit(self.target)
    end
    self.currentName = name
    self.current = self.states[name]
    if self.current and self.current.enter then
        self.current.enter(self.target, ...)
    end
end

function Engine.FSM:update(...)
    if self.current and self.current.update then
        self.current.update(self.target, ...)
    end
end

Engine.isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

Engine.Input = {
    left = false, right = false, up = false, down = false,
    jump = false, dash = false, grab = false,
    wasJump = false, wasDash = false, wasGrab = false,
    btnSize = 0,
    leftBtn = {}, rightBtn = {}, jumpBtn = {}, dashBtn = {}, grabBtn = {},
    touchAlpha = 1,
    fadingIn = false,
    fadingOut = false,
    lastInputType = "touch"
}

function Engine.Input.update(dt)
    Engine.Input.wasJump = Engine.Input.jump
    Engine.Input.wasDash = Engine.Input.dash
    Engine.Input.wasGrab = Engine.Input.grab

    Engine.Input.left = love.keyboard.isDown("left", "a")
    Engine.Input.right = love.keyboard.isDown("right", "d")
    Engine.Input.up = love.keyboard.isDown("up", "w")
    Engine.Input.down = love.keyboard.isDown("down", "s")
    Engine.Input.jump = love.keyboard.isDown("space", "c")
    Engine.Input.dash = love.keyboard.isDown("x")
    Engine.Input.grab = love.keyboard.isDown("z", "v")

    if Engine.isMobile then
        if Engine.Input.lastInputType == "key" and Engine.Input.touchAlpha > 0 and not Engine.Input.fadingOut then
            Engine.Input.fadingOut = true
            Engine.Input.fadingIn = false
            flux.to(Engine.Input, 0.4, { touchAlpha = 0 })
        elseif Engine.Input.lastInputType == "touch" and Engine.Input.touchAlpha < 1 and not Engine.Input.fadingIn then
            Engine.Input.fadingIn = true
            Engine.Input.fadingOut = false
            flux.to(Engine.Input, 0.4, { touchAlpha = 1 })
        end

        if Engine.Input.touchAlpha > 0.05 then
            local touches = love.touch.getTouches()
            for _, id in ipairs(touches) do
                local tx, ty = love.touch.getPosition(id)
                if tx >= Engine.Input.leftBtn.x and tx <= Engine.Input.leftBtn.x + Engine.Input.leftBtn.w and ty >= Engine.Input.leftBtn.y and ty <= Engine.Input.leftBtn.y + Engine.Input.leftBtn.h then
                    Engine.Input.left = true
                end
                if tx >= Engine.Input.rightBtn.x and tx <= Engine.Input.rightBtn.x + Engine.Input.rightBtn.w and ty >= Engine.Input.rightBtn.y and ty <= Engine.Input.rightBtn.y + Engine.Input.rightBtn.h then
                    Engine.Input.right = true
                end
                if tx >= Engine.Input.jumpBtn.x and tx <= Engine.Input.jumpBtn.x + Engine.Input.jumpBtn.w and ty >= Engine.Input.jumpBtn.y and ty <= Engine.Input.jumpBtn.y + Engine.Input.jumpBtn.h then
                    Engine.Input.jump = true
                end
                if tx >= Engine.Input.dashBtn.x and tx <= Engine.Input.dashBtn.x + Engine.Input.dashBtn.w and ty >= Engine.Input.dashBtn.y and ty <= Engine.Input.dashBtn.y + Engine.Input.dashBtn.h then
                    Engine.Input.dash = true
                end
                if tx >= Engine.Input.grabBtn.x and tx <= Engine.Input.grabBtn.x + Engine.Input.grabBtn.w and ty >= Engine.Input.grabBtn.y and ty <= Engine.Input.grabBtn.y + Engine.Input.grabBtn.h then
                    Engine.Input.grab = true
                end
            end
        end
    end
end

function Engine.Input.resize(w, h)
    if not Engine.isMobile then return end
    local sw, sh = love.graphics.getDimensions()
    Engine.Input.btnSize = sh * 0.15
    local bs = Engine.Input.btnSize
    Engine.Input.leftBtn  = { x = 40, y = sh - bs - 40, w = bs, h = bs }
    Engine.Input.rightBtn = { x = 60 + bs, y = sh - bs - 40, w = bs, h = bs }
    Engine.Input.jumpBtn  = { x = sw - bs - 40, y = sh - bs - 40, w = bs, h = bs }
    Engine.Input.dashBtn  = { x = sw - (bs*2) - 60, y = sh - bs - 40, w = bs, h = bs }
    Engine.Input.grabBtn  = { x = sw - (bs*3) - 80, y = sh - bs - 40, w = bs, h = bs }
end

function Engine.Input.draw()
    if not Engine.isMobile or Engine.Input.touchAlpha <= 0.01 then return end
    love.graphics.setColor(1, 1, 1, Engine.Input.touchAlpha)
    
    love.graphics.rectangle("line", Engine.Input.leftBtn.x, Engine.Input.leftBtn.y, Engine.Input.leftBtn.w, Engine.Input.leftBtn.h)
    love.graphics.rectangle("line", Engine.Input.rightBtn.x, Engine.Input.rightBtn.y, Engine.Input.rightBtn.w, Engine.Input.rightBtn.h)
    love.graphics.rectangle("line", Engine.Input.jumpBtn.x, Engine.Input.jumpBtn.y, Engine.Input.jumpBtn.w, Engine.Input.jumpBtn.h)
    love.graphics.rectangle("line", Engine.Input.dashBtn.x, Engine.Input.dashBtn.y, Engine.Input.dashBtn.w, Engine.Input.dashBtn.h)
    love.graphics.rectangle("line", Engine.Input.grabBtn.x, Engine.Input.grabBtn.y, Engine.Input.grabBtn.w, Engine.Input.grabBtn.h)
    
    love.graphics.printf("<", Engine.Input.leftBtn.x, Engine.Input.leftBtn.y + Engine.Input.btnSize/2 - 7, Engine.Input.leftBtn.w, "center")
    love.graphics.printf(">", Engine.Input.rightBtn.x, Engine.Input.rightBtn.y + Engine.Input.btnSize/2 - 7, Engine.Input.rightBtn.w, "center")
    love.graphics.printf("JUMP", Engine.Input.jumpBtn.x, Engine.Input.jumpBtn.y + Engine.Input.btnSize/2 - 7, Engine.Input.jumpBtn.w, "center")
    love.graphics.printf("DASH", Engine.Input.dashBtn.x, Engine.Input.dashBtn.y + Engine.Input.btnSize/2 - 7, Engine.Input.dashBtn.w, "center")
    love.graphics.printf("GRAB", Engine.Input.grabBtn.x, Engine.Input.grabBtn.y + Engine.Input.btnSize/2 - 7, Engine.Input.grabBtn.w, "center")
    
    love.graphics.setColor(1, 1, 1, 1)
end

Engine.PlayerStates = {}

Engine.PlayerStates.Normal = {
    update = function(p, dt, moveX, moveY)
        if Engine.Input.grab and p.vy >= 0 and p:checkWall(p.facing) then
            p.fsm:change("climb")
            p.vx = 0
            return
        end

        if Engine.Input.dash and not Engine.Input.wasDash and p.dashCooldownTimer <= 0 and p.dashes > 0 then
            p.fsm:change("dash")
            return
        end

        if p.forceMoveXTimer > 0 then
            p.vx = p.forceMoveX
        else
            local mult = p.isGrounded and 1 or p.air_mult
            if math.abs(p.vx) > p.max_run and sign(p.vx) == moveX then
                p.vx = approach(p.vx, p.max_run * moveX, p.run_reduce * mult * dt)
            else
                p.vx = approach(p.vx, p.max_run * moveX, p.run_accel * mult * dt)
            end
        end

        if not p.isGrounded then
            local max_fall = p.max_fall
            
            if moveY == 1 and p.vy >= p.max_fall then
                max_fall = p.fast_max_fall
                p.vy = approach(p.vy, max_fall, p.fast_max_accel * dt)
            end

            if moveX == p.facing and moveY ~= 1 and p.vy >= 0 and p:checkWall(p.facing) then
                p.wallSlideTimer = math.max(p.wallSlideTimer - dt, 0)
                max_fall = p.wall_slide_start_max
            end

            local mult = 1
            if math.abs(p.vy) < p.half_grav_threshold and Engine.Input.jump then
                mult = 0.5
            end

            p.vy = approach(p.vy, max_fall, p.gravity * mult * dt)
        end

        if p.varJumpTimer > 0 then
            if Engine.Input.jump then
                p.vy = math.min(p.vy, p.jump_speed)
            else
                p.varJumpTimer = 0
            end
        end

        if p.jumpBuffer > 0 then
            if p.jumpGraceTimer > 0 then
                p.vy = p.jump_speed
                p.vx = p.vx + p.jump_h_boost * moveX
                p.varJumpTimer = p.var_jump_time
                p.jumpGraceTimer = 0
                p.jumpBuffer = 0
            else
                if p:checkWall(1) then
                    p:wallJump(-1)
                    p.jumpBuffer = 0
                elseif p:checkWall(-1) then
                    p:wallJump(1)
                    p.jumpBuffer = 0
                end
            end
        end
    end
}

Engine.PlayerStates.Dash = {
    enter = function(p)
        p.dashes = p.dashes - 1
        p.dashTimer = p.dash_time
        p.dashCooldownTimer = p.dash_cooldown
        p.freezeTimer = 0.05
        
        local moveX = (Engine.Input.right and 1 or 0) - (Engine.Input.left and 1 or 0)
        local moveY = (Engine.Input.down and 1 or 0) - (Engine.Input.up and 1 or 0)
        local dx, dy = moveX, moveY
        if dx == 0 and dy == 0 then dx = p.facing end
        local len = math.sqrt(dx*dx + dy*dy)
        p.dashDirX, p.dashDirY = dx / len, dy / len
        
        p.vx = p.dashDirX * p.dash_speed
        p.vy = p.dashDirY * p.dash_speed
        
        for i = 1, 15 do
            Engine.particles:spawn(function(part)
                part.x = p.x + p.w / 2
                part.y = p.y + p.h / 2
                part.vx = (math.random() - 0.5) * 400 - (p.dashDirX * 100)
                part.vy = (math.random() - 0.5) * 400 - (p.dashDirY * 100)
                part.life = 0.2 + math.random() * 0.2
                part.maxLife = 0.4
                part.size = math.random(4, 8)
            end)
        end
    end,
    update = function(p, dt, moveX, moveY)
        p.dashTimer = p.dashTimer - dt
        p.vx = p.dashDirX * p.dash_speed
        p.vy = p.dashDirY * p.dash_speed

        Engine.particles:spawn(function(part)
            part.x = p.x + math.random() * p.w
            part.y = p.y + math.random() * p.h
            part.vx = -p.dashDirX * math.random(50, 150)
            part.vy = -p.dashDirY * math.random(50, 150)
            part.life = 0.2
            part.maxLife = 0.2
            part.size = math.random(3, 6)
        end)

        if p.jumpBuffer > 0 then
            if p:checkWall(1) then
                p:wallJump(-1)
                p.jumpBuffer = 0
                p.fsm:change("normal")
                return
            elseif p:checkWall(-1) then
                p:wallJump(1)
                p.jumpBuffer = 0
                p.fsm:change("normal")
                return
            end
        end

        if p.dashTimer <= 0 then
            p.fsm:change("normal")
            if p.dashDirY <= 0 then
                p.vx = p.dashDirX * p.end_dash_speed
                p.vy = p.dashDirY * p.end_dash_speed
            end
            if p.vy < 0 then
                p.vy = p.vy * p.end_dash_up_mult
            end
        end
    end
}

Engine.PlayerStates.Climb = {
    update = function(p, dt, moveX, moveY)
        if not Engine.Input.grab or p.stamina <= 0 or not p:checkWall(p.facing) then
            p.fsm:change("normal")
            return
        end

        local targetY = 0
        if moveY == -1 then
            targetY = p.climb_up_speed
            p.stamina = p.stamina - p.climb_up_cost * dt
        elseif moveY == 1 then
            targetY = p.climb_down_speed
        else
            p.stamina = p.stamina - p.climb_still_cost * dt
        end

        p.vy = approach(p.vy, targetY, p.climb_accel * dt)

        if p.jumpBuffer > 0 then
            p.jumpBuffer = 0
            if moveX == -p.facing then
                p:wallJump(-p.facing)
            else
                p.vy = p.jump_speed
                p.vx = 0
                p.stamina = p.stamina - p.climb_jump_cost
                p.varJumpTimer = p.var_jump_time
            end
            p.fsm:change("normal")
        end
    end
}

local SCALE = 4

Engine.Player = {}
Engine.Player.__index = Engine.Player

function Engine.Player:new(world, x, y)
    local p = setmetatable({}, Engine.Player)
    p.world = world
    p.x, p.y = x, y
    p.spawnX, p.spawnY = x, y
    p.w, p.h = 32, 32
    p.vx, p.vy = 0, 0
    p.dead = false
    p.visualScale = 1
    p.facing = 1
    p.isGrounded = false
    p.jumpBuffer = 0
    p.jumpGraceTimer = 0
    p.varJumpTimer = 0
    p.dashCooldownTimer = 0
    p.dashTimer = 0
    p.forceMoveXTimer = 0
    p.forceMoveX = 0
    p.wallSlideTimer = 0
    p.freezeTimer = 0
    p.dashes = 1
    p.stamina = 110
    
    p.max_fall = 160 * SCALE
    p.gravity = 900 * SCALE
    p.half_grav_threshold = 40 * SCALE
    p.fast_max_fall = 240 * SCALE
    p.fast_max_accel = 300 * SCALE
    p.max_run = 90 * SCALE
    p.run_accel = 1000 * SCALE
    p.run_reduce = 400 * SCALE
    p.air_mult = 0.65
    p.jump_speed = -120 * SCALE
    p.jump_h_boost = 40 * SCALE
    p.jump_grace_time = 0.1
    p.var_jump_time = 0.2
    p.wall_jump_check_dist = 3 * SCALE
    p.wall_jump_force_time = 0.16
    p.wall_jump_h_speed = (90 + 40) * SCALE
    p.wall_slide_start_max = 20 * SCALE
    p.wall_slide_time = 1.2
    p.dash_speed = 240 * SCALE
    p.end_dash_speed = 160 * SCALE
    p.end_dash_up_mult = 0.75
    p.dash_time = 0.15
    p.dash_cooldown = 0.2
    p.climb_max_stamina = 110
    p.climb_up_cost = 100 / 2.2
    p.climb_still_cost = 100 / 10
    p.climb_jump_cost = 110 / 4
    p.climb_up_speed = -45 * SCALE
    p.climb_down_speed = 80 * SCALE
    p.climb_accel = 900 * SCALE

    p.world:add(p, p.x, p.y, p.w, p.h)

    p.fsm = Engine.FSM:new(p)
    p.fsm:addState("normal", Engine.PlayerStates.Normal)
    p.fsm:addState("dash", Engine.PlayerStates.Dash)
    p.fsm:addState("climb", Engine.PlayerStates.Climb)
    p.fsm:change("normal")

    return p
end

function Engine.Player:die()
    if self.dead then return end
    self.dead = true
    self.vx, self.vy = 0, 0
    
    flux.to(self, 0.15, { visualScale = 0 }):ease("backin"):oncomplete(function()
        self.x, self.y = self.spawnX, self.spawnY
        self.world:update(self, self.x, self.y)
        self.dashes = 1
        self.stamina = self.climb_max_stamina
        self.fsm:change("normal")
        
        flux.to(self, 0.2, { visualScale = 1 }):ease("elasticout"):oncomplete(function()
            self.dead = false
        end)
    end)
end

function Engine.Player:checkWall(dir)
    local solidFilter = function(item) return item.isSolid end
    local items, len = self.world:queryRect(self.x + (dir == 1 and self.w or -self.wall_jump_check_dist), self.y + 2, self.wall_jump_check_dist, self.h - 4, solidFilter)
    return len > 0
end

function Engine.Player:wallJump(dir)
    self.vy = self.jump_speed
    self.vx = self.wall_jump_h_speed * dir
    self.varJumpTimer = self.var_jump_time
    self.forceMoveX = self.wall_jump_h_speed * dir
    self.forceMoveXTimer = self.wall_jump_force_time
end

function Engine.Player:update(dt, level)
    if self.dead then return end

    if self.freezeTimer > 0 then
        self.freezeTimer = self.freezeTimer - dt
        return
    end

    if Engine.Input.jump and not Engine.Input.wasJump then self.jumpBuffer = 0.1 end
    if self.jumpBuffer > 0 then self.jumpBuffer = self.jumpBuffer - dt end

    if self.varJumpTimer > 0 then self.varJumpTimer = self.varJumpTimer - dt end
    if self.jumpGraceTimer > 0 then self.jumpGraceTimer = self.jumpGraceTimer - dt end
    if self.dashCooldownTimer > 0 then self.dashCooldownTimer = self.dashCooldownTimer - dt end
    if self.forceMoveXTimer > 0 then self.forceMoveXTimer = self.forceMoveXTimer - dt end
    if self.wallSlideTimer > 0 then self.wallSlideTimer = self.wallSlideTimer - dt end

    local moveX = (Engine.Input.right and 1 or 0) - (Engine.Input.left and 1 or 0)
    local moveY = (Engine.Input.down and 1 or 0) - (Engine.Input.up and 1 or 0)

    if moveX ~= 0 and self.fsm.currentName ~= "climb" then
        self.facing = moveX
    end

    self.fsm:update(dt, moveX, moveY)

    local goalX = self.x + self.vx * dt
    local goalY = self.y + self.vy * dt

    local actualX, actualY, cols, len = self.world:move(self, goalX, goalY, playerFilter)
    self.x, self.y = actualX, actualY

    self.isGrounded = false
    local died = false

    for i = 1, len do
        local other = cols[i].other
        if other.isHazard then
            died = true
        elseif other.isCheckpoint then
            if not other.active then
                other.active = true
                self.spawnX = other.x + (other.w / 2) + 25 - (self.w / 2)
                self.spawnY = other.y + other.h - self.h
                flux.to(other, 0.6, { flagY = other.y }):ease("backout")
            end
        else
            local normal = cols[i].normal
            if normal.y == -1 then
                self.isGrounded = true
                self.vy = 0
                self.dashes = 1
                self.stamina = self.climb_max_stamina
            elseif normal.y == 1 then
                self.vy = 0
                self.varJumpTimer = 0
            elseif normal.x ~= 0 then
                self.vx = 0
            end
        end
    end

    if self.isGrounded then
        self.jumpGraceTimer = self.jump_grace_time
    end

    if died or (level and self.y > level.killPlaneY) then
        self:die()
    end
end

function Engine.Player:draw()
    love.graphics.setColor(1, 1, 1)
    local bx, by = self.x + self.w/2, self.y + self.h
    local drawW, drawH = self.w * self.visualScale, self.h * self.visualScale
    love.graphics.rectangle("fill", math.floor(bx - drawW/2), math.floor(by - drawH), drawW, drawH)
end

Engine.Level = {}
Engine.Level.__index = Engine.Level

function Engine.Level:new(world, solidsData, hazardsData, checkpointsData, killPlaneY)
    local l = setmetatable({}, Engine.Level)
    l.world = world
    l.solids = {}
    l.hazards = {}
    l.checkpoints = {}
    l.killPlaneY = killPlaneY or 1000

    for _, pd in ipairs(solidsData) do
        local p = {x = pd.x, y = pd.y, w = pd.w, h = pd.h, isSolid = true}
        table.insert(l.solids, p)
        l.world:add(p, p.x, p.y, p.w, p.h)
    end

    for _, hd in ipairs(hazardsData) do
        local h = {x = hd.x, y = hd.y, w = hd.w, h = hd.h, isHazard = true}
        table.insert(l.hazards, h)
        l.world:add(h, h.x, h.y, h.w, h.h)
    end

    for _, cd in ipairs(checkpointsData) do
        local c = {x = cd.x, y = cd.y, w = cd.w, h = cd.h, isCheckpoint = true, active = false, flagY = cd.y + cd.h - 20}
        table.insert(l.checkpoints, c)
        l.world:add(c, c.x, c.y, c.w, c.h)
    end

    return l
end

function Engine.Level:draw()
    love.graphics.setColor(1, 1, 1)
    for _, p in ipairs(self.solids) do
        love.graphics.rectangle("line", math.floor(p.x), math.floor(p.y), p.w, p.h)
    end

    for _, h in ipairs(self.hazards) do
        local w = 20
        local count = math.floor(h.w / w)
        local aw = h.w / count
        for i = 0, count - 1 do
            local sx = h.x + i * aw
            love.graphics.polygon("fill", 
                sx, h.y + h.h, 
                sx + aw / 2, h.y, 
                sx + aw, h.y + h.h
            )
        end
    end

    for _, c in ipairs(self.checkpoints) do
        love.graphics.rectangle("fill", math.floor(c.x + c.w/2 - 2), math.floor(c.y), 4, c.h)
        love.graphics.polygon("fill", 
            c.x + c.w/2, c.flagY, 
            c.x + c.w/2 + 30, c.flagY + 10, 
            c.x + c.w/2, c.flagY + 20
        )
    end
end

local world
local camera
local effect
local player
local level

function love.load()
    love.window.setMode(1280, 720, {resizable = true, highdpi = true})
    
    world = bump.newWorld(64)
    
    local solids = {
        {x = 0, y = 600, w = 800, h = 100},
        {x = 1000, y = 600, w = 900, h = 100},
        {x = 1300, y = 500, w = 200, h = 32},
        {x = 1650, y = 400, w = 200, h = 32},
        {x = 2050, y = 600, w = 800, h = 100},
        {x = -50, y = 0, w = 50, h = 1000}
    }

    local hazards = {
        {x = 800, y = 650, w = 200, h = 50},
        {x = 1900, y = 650, w = 150, h = 50}
    }

    local checkpoints = {
        {x = 1150, y = 500, w = 64, h = 100},
        {x = 2200, y = 500, w = 64, h = 100}
    }
    
    level = Engine.Level:new(world, solids, hazards, checkpoints, 900)
    player = Engine.Player:new(world, 100, 400)
    
    camera = Camera()
    camera:setFollowLerp(0.15)
    
    local w, h = love.graphics.getDimensions()
    camera.w = w
    camera.h = h
    
    effect = moonshine(moonshine.effects.crt)
    
    Engine.Input.resize(w, h)
end

function love.update(dt)
    flux.update(dt)
    Engine.Input.update(dt)
    
    player:update(dt, level)
    
    Engine.particles:update(dt, function(p, delta)
        p.life = p.life - delta
        p.x = p.x + p.vx * delta
        p.y = p.y + p.vy * delta
        return p.life > 0
    end)

    camera:follow(math.floor(player.x + player.w / 2), math.floor(player.y + player.h / 2))
    camera:update(dt)
end

function love.draw()
    effect(function()
        camera:attach()
        love.graphics.clear(0, 0, 0)
        level:draw()
        
        Engine.particles:draw(function(p)
            local alpha = math.max(0, p.life / p.maxLife)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.rectangle("fill", p.x - p.size/2, p.y - p.size/2, p.size, p.size)
        end)
        
        love.graphics.setColor(1, 1, 1, 1)

        player:draw()
        camera:detach()
    end)
    
    Engine.Input.draw()
end

function love.resize(w, h)
    Engine.Input.resize(w, h)
    if effect and effect.resize then
        effect.resize(w, h)
    end
    if camera then
        camera.w = w
        camera.h = h
        if camera.updateResolution then
            camera:updateResolution(w, h)
        end
    end
end

function love.keypressed(key)
    Engine.Input.lastInputType = "key"
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    Engine.Input.lastInputType = "touch"
end
