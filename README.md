![gameplay gif](https://image2url.com/r2/default/gifs/1774631085329-0565b0af-fcb0-4db2-89bb-50134338f4d8.gif)

**this template is recommended for assetless jam games, however it coul‌d also be used for commercial games.**

### features:

os auto detection for mobile vs desktop

on screen touch controls that dynamically resize with window dimensions

input tracking for previous frames to prevent accidental double inputs

velocity calculation using a custom approach function

different acceleration and friction values for grounded vs airborne movement

gravity scaling with a half gravity threshold at the jump apex

maximum fall speed and holding down to fast fall

jump buffering

coyote time jump grace period

variable jump height by releasing the jump button early

wall sliding with a delay timer before sliding starts

directional wall jumping that forces horizontal movement for a set duration

wall grabbing and climbing

stamina system

restoring dashes and stamina upon touching the ground

eight way directional dashing based on input or current facing direction

brief freeze frame hitstop when initiating a dash

dash cooldown timer

end of dash speed reduction and upward momentum dampening

player facing direction tracking

entity collision filtering to slide on walls but cross through hazards and checkpoints

finite state machine

o(1) object pool for zero garbage particle recycling

spike hazards drawn as repeating polygons

bottom of the world kill plane

checkpoint system that updates spawn coordinates and animates a flag

death animation

lerping camera that follows the player and updates on window resize

dash particle bursts and continuous dash trail particles

crt post processing effect

### libraries used:

[moonshine](https://github.com/vrld/moonshine)

[bump.lua](https://github.com/kikito/bump.lua)

[flux](https://github.com/rxi/flux)

[STALKER-X](https://github.com/a327ex/STALKER-X)

### to be added:

determinism

baton support

procedural generation

in-game level editor using Slab

json support

Tiled/LDtk support





**special thanks to:**

Maddy Thorson & Noel Berry





*made by plopceleste using the [LÖVE](https://www.love2d.org/) framework.*
