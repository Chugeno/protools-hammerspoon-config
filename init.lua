-- /Users/eugenioazurmendi/.hammerspoon/init.lua (SCRIPT DE PRUEBA TEMPORAL)
-- /Users/eugenioazurmendi/.hammerspoon/init.lua (SCRIPT DE PRUEBA DE ÍCONO SIMPLE)

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


--[[
-- =============================================================================
--  Hammerspoon - Pro Tools Plugin Automator
-- =============================================================================
--  Script para crear botones flotantes que automatizan la apertura de plugins
--  de AudioSuite en Pro Tools mediante navegación de menús.
-- =============================================================================
--]]

-- =============================================================================
--  1. CONFIGURACIÓN GENERAL
-- =============================================================================

-- Habilitar Spotlight para búsqueda de aplicaciones (silencia warning)
hs.application.enableSpotlightForNameSearches(true)

-- Nombre de la aplicación de destino
local proToolsAppName = "Pro Tools"

-- Colores de los botones (estilo Pro Tools - gris azulado)
local buttonBackgroundColor = { red = 0.2, green = 0.25, blue = 0.3, alpha = 0.95 }
local buttonTextColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 1.0 }
local buttonHoverColor = { red = 0.3, green = 0.35, blue = 0.4, alpha = 0.95 }

-- Configuración de posición y tamaño
local buttonSize = 80          -- Tamaño del botón (cuadrado)
local buttonRadius = 10        -- Radio de las esquinas redondeadas
local marginRight = 20         -- Distancia desde el borde derecho
local marginBottom = 0         -- Distancia desde el borde inferior
local buttonSpacing = 10       -- Espacio entre botones

-- =============================================================================
--  2. CONFIGURACIÓN DE BOTONES - ¡AGREGAR BOTONES AQUÍ!
-- =============================================================================

local buttonsConfig = {
    
    {
        categoryName = "Noise Reduction",
        pluginName   = "RX 11 Voice De-noise",
        buttonText   = "RX Voice\nDe-noise",
    },
    
    {
        categoryName = "Noise Reduction",
        pluginName   = "RX 11 Spectral De-noise",
        buttonText   = "RX Spectral\nDe-noise",
    },

    {
        categoryName = "Noise Reduction",
        pluginName   = "RX 11 De-clip",
        buttonText   = "RX\nDe-clip",
    },

    {
        categoryName = "Noise Reduction",
        pluginName   = "RX 11 De-click",
        buttonText   = "RX\nDe-click",
    },

    {
        categoryName = "Noise Reduction",
        pluginName   = "Hush Mix",
        buttonText   = "Hush\nMix",
    },

    {
        categoryName = "Dynamics",
        pluginName   = "RDeEsser Stereo",
        buttonText   = "RDeEsser\nStereo",
    },
    
}

-- =============================================================================
--  3. LÓGICA DEL SCRIPT
-- =============================================================================

local canvasButtons = {}
local buttonsVisible = true  -- Estado de visibilidad

-- Función que navega los menús y abre el plugin usando AppleScript
local function openPluginViaMenu(categoryName, pluginName)
    local script = string.format([[
        tell application "System Events"
            tell process "%s"
                try
                    click menu item "%s" of menu 1 of menu item "%s" of menu 1 of menu bar item "AudioSuite" of menu bar 1
                    return "success"
                on error errMsg
                    return "error: " & errMsg
                end try
            end tell
        end tell
    ]], proToolsAppName, pluginName, categoryName)
    
    local success, result = hs.osascript.applescript(script)
    
    if not success or (result and result:match("^error:")) then
        hs.alert.show("❌ Error", 1)
    end
end

-- Función para crear un botón individual
local function createButton(config, posX, posY)
    local canvas = hs.canvas.new({
        x = posX,
        y = posY,
        w = buttonSize,
        h = buttonSize
    })
    
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:clickActivating(false)
    
    local isHovering = false
    
    local function updateButtonAppearance()
        local bgColor = isHovering and buttonHoverColor or buttonBackgroundColor
        
        canvas:replaceElements({
            {
                type = "rectangle",
                action = "fill",
                fillColor = bgColor,
                roundedRectRadii = { xRadius = buttonRadius, yRadius = buttonRadius },
                frame = { x = 0, y = 0, w = buttonSize, h = buttonSize }
            },
            {
                type = "text",
                text = config.buttonText,
                textColor = buttonTextColor,
                textSize = 13,
                textAlignment = "center",
                frame = { x = 3, y = 21, w = buttonSize - 6, h = buttonSize }
            }
        })
    end
    
    updateButtonAppearance()
    canvas:canvasMouseEvents(true, true)
    
    canvas:mouseCallback(function(c, msg, id, x, y)
        if msg == "mouseEnter" then
            isHovering = true
            updateButtonAppearance()
        elseif msg == "mouseExit" then
            isHovering = false
            updateButtonAppearance()
        elseif msg == "mouseDown" then
            hs.alert.show("⏳", 0.3)
            hs.timer.doAfter(0.05, function()
                openPluginViaMenu(config.categoryName, config.pluginName)
            end)
        end
    end)
    
    canvas:show()
    return canvas
end

-- Función para configurar todos los botones
local function setupAllButtons()
    for _, canvas in ipairs(canvasButtons) do
        canvas:delete()
    end
    canvasButtons = {}
    
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local buttonsPerRow = math.floor((screenFrame.w - marginRight - buttonSpacing) / (buttonSize + buttonSpacing))
    local startX = screenFrame.w - marginRight - buttonSize
    local startY = screenFrame.h - marginBottom - buttonSize
    
    for i, config in ipairs(buttonsConfig) do
        local columnIndex = (i - 1) % buttonsPerRow
        local rowIndex = math.floor((i - 1) / buttonsPerRow)
        local posX = startX - (columnIndex * (buttonSize + buttonSpacing))
        local posY = startY - (rowIndex * (buttonSize + buttonSpacing))
        
        local button = createButton(config, posX, posY)
        table.insert(canvasButtons, button)
    end
end

-- Función para toggle (mostrar/ocultar) botones
local function toggleButtons()
    if buttonsVisible then
        -- OCULTAR
        for _, canvas in ipairs(canvasButtons) do
            canvas:hide()
        end
        buttonsVisible = false
    else
        -- MOSTRAR
        for _, canvas in ipairs(canvasButtons) do
            canvas:show()
        end
        buttonsVisible = true
    end
end

-- =============================================================================
--  4. INICIALIZACIÓN
-- =============================================================================

-- Crear los botones (SIEMPRE VISIBLES al inicio)
setupAllButtons() -- Asegura que los botones se creen al inicio

-- Crear menubar item con ícono de Pro Tools
toggleMenu = hs.menubar.new()
if toggleMenu then
    -- Establecer el estado inicial y la acción de clic
    toggleMenu:setTooltip("Toggle Pro Tools Buttons")
    toggleMenu:setClickCallback(toggleButtons)

    -- Cargar y establecer el ícono único
    local protoolsIcon = hs.image.imageFromPath(os.getenv("HOME") .. "/.hammerspoon/protools.png")
    if protoolsIcon then
        toggleMenu:setIcon(protoolsIcon)
    else
        -- Fallback a texto si el ícono no carga
        toggleMenu:setTitle("🎵")
        print("⚠️ No se pudo cargar el ícono 'protools.png'. Usando ícono de texto '🎵'.")
    end
end

-- Recargar botones cuando cambie la configuración de pantalla
hs.screen.watcher.new(setupAllButtons):start()

print("🎵 Hammerspoon - Pro Tools Plugin Automator cargado.")
print("👁️ Ítem de la barra de menú para Pro Tools configurado.")
