local component = require("component")
local term = require("term")

gpu = component.getPrimary("gpu")
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
local x, y = gpu.maxResolution()
gpu.setResolution(x, y)
gpu.fill(1, 1, x, y, " ")

term.setCursor(1,1)