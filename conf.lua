function love.conf(t)
    t.identity = "platformer"
    t.version = "11.5"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.fullscreen = false
    t.window.highdpi = true
    t.modules.touch = true
    t.modules.keyboard = true
    t.modules.joystick = false
    t.modules.audio = true
end
