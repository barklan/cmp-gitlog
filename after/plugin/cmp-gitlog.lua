local ok, cmp = pcall(require, "cmp")

if ok then
    cmp.register_source("gitlog", require("cmp-gitlog").new())
end
