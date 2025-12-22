-- lua/telescope/_extensions/marksman/init.lua

local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
    vim.notify('Telescope plugin not found. Marksman picker disabled.', vim.log.levels.WARN)
    return {}
end

-- Remove the setup function entirely since we're handling config in the main plugin
return telescope.register_extension {
    exports = {
        marks = require('telescope._extensions.marksman.picker').marks,
    },
}
