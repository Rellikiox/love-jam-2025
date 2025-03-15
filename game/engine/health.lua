-- Class
Health = Object:extend()

function Health:init(args)
    self.max_health = args.max_health
    self.health = self.max_health
    self.invulnerable = false
    self.on_damage_taken = args.on_damage_taken
    self.is_alive = self.health > 0
end

function Health:damage(value, damage_type)
    if self.invulnerable or not self.is_alive then
        return
    end
    self.health = math.max(self.health - value, 0)
    self.is_alive = self.health > 0
    if self.on_damage_taken then
        self.on_damage_taken(self.health, value, damage_type)
    end
end
