-- Async file watcher implementation using coroutines
local FileWatcher = {
    files = {},
    callbacks = {},
    interval = 1, -- Check interval in seconds
    running = false
}

local function hot_reload_callback(filename)
    return function(event)
        if event == 'modified' then
            local module_name = filename:gsub('%.%w+$', '')
            package.loaded[module_name] = nil
            if _G[module_name] then
                _G[module_name] = nil
            end

            local success, result = pcall(require, module_name)
            if not success then
                error("Failed to reload module '" .. module_name .. "': " .. tostring(result))
            else
                print('Reloaded ' .. module_name)
            end
        end
    end
end

-- Get file information
function FileWatcher:get_file_info(filepath)
    local attributes =
        assert(
        io.popen(
            'stat -f "%m" "' ..
                filepath .. '" 2>/dev/null || stat -c "%Y" "' .. filepath .. '" 2>/dev/null'
        )
    ):read('*n')
    if attributes then
        return {
            mtime = attributes,
            exists = true
        }
    end
    return nil
end

-- Add a file to watch
function FileWatcher:watch(filepath, callback)
    local info = self:get_file_info(filepath)
    if info then
        self.files[filepath] = info
        self.callbacks[filepath] = callback
        print('Watching ' .. filepath)
        return true
    end
    print('Failed to watch ' .. filepath)
    return false
end

-- Add a file to watch
function FileWatcher:hot_reload(filepath)
    self:watch(filepath, hot_reload_callback(filepath))
end

-- Check for file changes
function FileWatcher:check_files()
    for filepath, old_info in pairs(self.files) do
        local new_info = self:get_file_info(filepath)
        if not new_info then
            -- File was deleted
            self.callbacks[filepath]('deleted')
            self.files[filepath] = nil
            self.callbacks[filepath] = nil
        elseif new_info.mtime ~= old_info.mtime then
            -- File was modified
            self.callbacks[filepath]('modified')
            self.files[filepath] = new_info
        end
    end
end

-- Create the watcher coroutine
function FileWatcher:create_watcher()
    return coroutine.create(
        function()
            while self.running do
                self:check_files()
                coroutine.yield()
            end
        end
    )
end

-- Start watching files
function FileWatcher:start()
    if not self.running then
        self.running = true
        self.watcher = self:create_watcher()
        return true
    end
    return false
end

-- Stop watching files
function FileWatcher:stop()
    self.running = false
    self.watcher = nil
end

-- Update the watcher (call this in your main loop)
function FileWatcher:update()
    if self.running and self.watcher then
        if coroutine.status(self.watcher) == 'dead' then
            self.watcher = self:create_watcher()
        end

        local now = os.time()
        if not self.last_update or (now - self.last_update) >= self.interval then
            coroutine.resume(self.watcher)
            self.last_update = now
        end
    end
end

-- Set check interval
function FileWatcher:set_interval(seconds)
    self.interval = seconds
end

return FileWatcher
