-- Server entry point.

local DataService = require(script.Parent.DataService)
local GameService = require(script.Parent.GameService)
local MonetizationService = require(script.Parent.MonetizationService)

GameService.start()
MonetizationService.start()
DataService.start()
