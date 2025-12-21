local ok, _ = pcall(require, "telescope")
if ok then
    require("telescope").load_extension("marksman")
end
