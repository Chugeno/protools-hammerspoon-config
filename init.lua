--[[
-- =============================================================================
--  Hammerspoon - Boton de clear consola
-- =============================================================================
--]]

hs.console.toolbar():addItems(
    {
        id = "clearConsole",
        image   = hs.image.imageFromName("NSTrashFull"),
        fn      = function(...) hs.console.clearConsole() end,
        label   = "Clear",
        tooltip = "Clear Console",
    }
):insertItem("clearConsole", #hs.console.toolbar():visibleItems() + 1)

-- /Users/eugenioazurmendi/.hammerspoon/init.lua (SCRIPT DE PRUEBA TEMPORAL)
-- =============================================================================
--  Hammerspoon - Configuración Principal
-- =============================================================================
--  Este archivo carga todos los Spoons (plugins) y configuraciones.
-- =============================================================================

--[[
--  Carga del Spoon para Pro Tools
--]]
hs.application.enableSpotlightForNameSearches(true)

hs.loadSpoon("ProToolsAutomator")
spoon.ProToolsAutomator:start()