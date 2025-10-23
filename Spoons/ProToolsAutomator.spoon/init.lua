-- =============================================================================
--  Spoon: ProToolsAutomator
-- =============================================================================
--  Crea una paleta de botones flotantes para abrir plugins de AudioSuite
--  en Pro Tools.
-- =============================================================================

local obj = {}

-- =============================================================================
--  1. METADATOS DEL SPOON
-- =============================================================================
obj.name = "ProToolsAutomator"
obj.version = "1.0"
obj.author = "Eugenio Azurmendi <Chugeno>"
obj.homepage = "https://github.com/Chugeno/protools-hammerspoon-config"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- =============================================================================
--  2. CONFIGURACIÓN DE BOTONES - ¡AGREGAR BOTONES AQUÍ!
-- =============================================================================
obj.buttonsConfig = {
    { categoryName = "Noise Reduction", pluginName = "RX 11 Voice De-noise", buttonText = "RX Voice\nDe-noise" },
    { categoryName = "Noise Reduction", pluginName = "RX 11 Spectral De-noise", buttonText = "RX Spectral\nDe-noise" },
    { categoryName = "Noise Reduction", pluginName = "RX 11 De-clip", buttonText = "RX\nDe-clip" },
    { categoryName = "Noise Reduction", pluginName = "RX 11 De-click", buttonText = "RX\nDe-click" },
    { categoryName = "Noise Reduction", pluginName = "Hush Mix", buttonText = "Hush\nMix" },
    { categoryName = "Dynamics", pluginName = "RDeEsser Stereo", buttonText = "RDeEsser\nStereo" },
}

-- =============================================================================
--  3. CONFIGURACIÓN GENERAL
-- =============================================================================
obj.proToolsAppName = "Pro Tools"
obj.buttonBackgroundColor = { red = 0.2, green = 0.25, blue = 0.3, alpha = 0.95 }
obj.buttonTextColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 1.0 }
obj.buttonHoverColor = { red = 0.3, green = 0.35, blue = 0.4, alpha = 0.95 }
obj.buttonSize = 80
obj.buttonRadius = 10
obj.marginRight = 20
obj.marginBottom = 0
obj.buttonSpacing = 10

-- =============================================================================
--  4. VARIABLES INTERNAS
-- =============================================================================
obj.canvasButtons = {}
obj.buttonsVisible = true
obj.toggleMenu = nil
obj.screenWatcher = nil

-- =============================================================================
--  5. LÓGICA DEL SPOON
-- =============================================================================

-- Abre el plugin usando AppleScript
function obj:_openPluginViaMenu(categoryName, pluginName)
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
    ]], obj.proToolsAppName, pluginName, categoryName)

    local success, result = hs.osascript.applescript(script)

    if not success or (result and result:match("^error:")) then
        hs.alert.show("❌ Error", 1)
    end
end

-- Crea un botón individual
function obj:_createButton(config, posX, posY)
    local canvas = hs.canvas.new({ x = posX, y = posY, w = obj.buttonSize, h = obj.buttonSize })
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:clickActivating(false)

    local isHovering = false

    local function updateButtonAppearance()
        local bgColor = isHovering and obj.buttonHoverColor or obj.buttonBackgroundColor
        canvas:replaceElements({
            { type = "rectangle", action = "fill", fillColor = bgColor, roundedRectRadii = { xRadius = obj.buttonRadius, yRadius = obj.buttonRadius }, frame = { x = 0, y = 0, w = obj.buttonSize, h = obj.buttonSize } },
            { type = "text", text = config.buttonText, textColor = obj.buttonTextColor, textSize = 13, textAlignment = "center", frame = { x = 3, y = 21, w = obj.buttonSize - 6, h = obj.buttonSize } }
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
                obj:_openPluginViaMenu(config.categoryName, config.pluginName)
            end)
        end
    end)

    canvas:show()
    return canvas
end

-- Dibuja o redibuja todos los botones
function obj:setupAllButtons()
    for _, canvas in ipairs(obj.canvasButtons) do
        canvas:delete()
    end
    obj.canvasButtons = {}

    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local buttonsPerRow = math.floor((screenFrame.w - obj.marginRight - obj.buttonSpacing) / (obj.buttonSize + obj.buttonSpacing))
    local startX = screenFrame.w - obj.marginRight - obj.buttonSize
    local startY = screenFrame.h - obj.marginBottom - obj.buttonSize

    for i, config in ipairs(obj.buttonsConfig) do
        local columnIndex = (i - 1) % buttonsPerRow
        local rowIndex = math.floor((i - 1) / buttonsPerRow)
        local posX = startX - (columnIndex * (obj.buttonSize + obj.buttonSpacing))
        local posY = startY - (rowIndex * (obj.buttonSize + obj.buttonSpacing))

        local button = obj:_createButton(config, posX, posY)
        table.insert(obj.canvasButtons, button)
    end
end

-- Muestra u oculta los botones
function obj:toggleButtons()
    obj.buttonsVisible = not obj.buttonsVisible
    for _, canvas in ipairs(obj.canvasButtons) do
        if obj.buttonsVisible then
            canvas:show()
        else
            canvas:hide()
        end
    end
end

-- =============================================================================
--  6. MÉTODOS PÚBLICOS DEL SPOON (start, stop, init)
-- =============================================================================

-- Método para iniciar el Spoon
function obj:start()
    self:stop() -- Asegura que no haya instancias previas

    -- Crear los botones
    self:setupAllButtons()

    -- Crear el ítem en la barra de menú
    self.toggleMenu = hs.menubar.new()
    if self.toggleMenu then
        self.toggleMenu:setTooltip("Toggle Pro Tools Buttons")
        self.toggleMenu:setClickCallback(function() obj:toggleButtons() end)

        -- Cargar el ícono desde la ruta del Spoon
        local protoolsIcon = hs.image.imageFromPath(hs.spoons.resourcePath("protools.png"))
        if protoolsIcon then
            self.toggleMenu:setIcon(protoolsIcon)
        else
            self.toggleMenu:setTitle("🎵")
            print("⚠️ " .. self.name .. ": No se pudo cargar 'protools.png'.")
        end
    end

    -- Observador para cambios de pantalla
    self.screenWatcher = hs.screen.watcher.new(function() obj:setupAllButtons() end):start()
    print("🎵 " .. self.name .. " cargado.")
end

-- Método para detener el Spoon
function obj:stop()
    if self.toggleMenu then
        self.toggleMenu:delete()
        self.toggleMenu = nil
    end
    if self.screenWatcher then
        self.screenWatcher:stop()
        self.screenWatcher = nil
    end
    for _, canvas in ipairs(self.canvasButtons) do
        canvas:delete()
    end
    self.canvasButtons = {}
end

-- Método de inicialización (se llama automáticamente con hs.loadSpoon)
function obj:init()
    -- Este método se llama cuando se carga el Spoon. No es necesario para cargar el ícono.
end

return obj