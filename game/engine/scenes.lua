Scenes = Object:extend()

function Scenes:init(scene_folder)
    self.scene_stack = {}
    self.scenes = {}
    for _, filename in ipairs(love.filesystem.getDirectoryItems(scene_folder)) do
        local scene_name, extension = filename:match("(.+)%.(%w+)$")
        if extension == 'lua' then
            local scene = require('game.scenes.' .. scene_name)
            self.scenes[scene_name] = scene
        end
    end
end

function Scenes:load(scene_name)
    assert(self.scenes[scene_name], 'Scene not found: ' .. scene_name)
    print('Loading scene: ' .. scene_name)
    self.scene_stack = { self.scenes[scene_name]() }
    self.scene_stack[1]:load()
end

function Scenes:stack(scene_name)
    assert(self.scenes[scene_name], 'Scene not found: ' .. scene_name)
    local new_scene = self.scenes[scene_name]()
    new_scene:load()
    table.insert(self.scene_stack, 1, new_scene)
end

function Scenes:unstack()
    assert(#self.scene_stack > 1, 'No scenes to unstack to')
    table.remove(self.scene_stack, 1)
end

function Scenes:update(delta)
    self.scene_stack[1]:update(delta)
end

function Scenes:draw()
    self.scene_stack[1]:draw()
end

return Scenes
