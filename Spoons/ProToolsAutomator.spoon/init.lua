-- =============================================================================
--  Spoon: ProToolsAutomator
-- =============================================================================
--  Crea una paleta de botones flotantes para abrir plugins de AudioSuite
--  en Pro Tools, con soporte para grupos de botones.
-- =============================================================================

local obj = {}

-- =============================================================================
--  1. METADATOS DEL SPOON
-- =============================================================================
obj.name = "ProToolsAutomator"
obj.version = "2.1"
obj.author = "Eugenio Azurmendi <Chugeno>"
obj.homepage = "https://github.com/Chugeno/protools-hammerspoon-config"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- =============================================================================
--  2. CONFIGURACIÓN DE BOTONES - ¡AGREGAR BOTONES AQUÍ!
-- =============================================================================
obj.buttonsConfig = {
    -- Botones agrupados bajo "RX"
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 Voice De-noise", buttonText = "RX Voice\nDe-noise" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 Spectral De-noise", buttonText = "RX Spectral\nDe-noise" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-clip", buttonText = "RX\nDe-clip" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-click", buttonText = "RX\nDe-click" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-crackle", buttonText = "RX\nDe-crackle" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeClick ", buttonText ="Acon\nDeClick2" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeClip 2", buttonText ="Acon\nDeClip2" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeHum 2", buttonText ="Acon\nDeHum2" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeNoise 2", buttonText ="Acon\nDeNoise2" },    
    -- Botones sin grupo (se muestran siempre)
    { categoryName = "Noise Reduction", pluginName = "Hush Mix", buttonText = "Hush\nMix" },
    { categoryName = "Dynamics", pluginName = "RDeEsser Stereo", buttonText = "RDeEsser\nStereo" },
}

-- =============================================================================
--  3. CONFIGURACIÓN GENERAL
-- =============================================================================
obj.proToolsAppName = "Pro Tools"
obj.buttonBackgroundColor = { red = 0.2, green = 0.25, blue = 0.3, alpha = 0.95 }
obj.buttonTextColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 1.0 }
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
obj.activeGroups = {} -- Guarda qué grupos están expandidos
obj.groupColors = {} -- Guarda los colores asignados a cada grupo

-- =============================================================================
--  5. LÓGICA DEL SPOON
-- =============================================================================

-- Genera un color aleatorio agradable para un grupo
function obj:_generateGroupColor(groupName)
    -- Si ya tiene un color asignado, devolverlo
    if obj.groupColors[groupName] then
        return obj.groupColors[groupName]
    end
    
    -- Usar el nombre del grupo como seed para consistencia
    math.randomseed(string.byte(groupName, 1) * string.byte(groupName, -1) * #groupName)
    
    -- Generar colores en rangos agradables (evitando colores muy oscuros o muy claros)
    local hue = math.random(0, 360)
    local saturation = math.random(40, 70) / 100  -- Entre 0.4 y 0.7
    local brightness = math.random(35, 55) / 100  -- Entre 0.35 y 0.55
    
    -- Convertir HSV a RGB
    local function hsvToRgb(h, s, v)
        local c = v * s
        local x = c * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - c
        
        local r, g, b
        if h < 60 then
            r, g, b = c, x, 0
        elseif h < 120 then
            r, g, b = x, c, 0
        elseif h < 180 then
            r, g, b = 0, c, x
        elseif h < 240 then
            r, g, b = 0, x, c
        elseif h < 300 then
            r, g, b = x, 0, c
        else
            r, g, b = c, 0, x
        end
        
        return {
            red = r + m,
            green = g + m,
            blue = b + m,
            alpha = 0.95
        }
    end
    
    local color = hsvToRgb(hue, saturation, brightness)
    obj.groupColors[groupName] = color
    
    -- Resetear el seed random
    math.randomseed(os.time())
    
    return color
end

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

-- Agrupa los botones por grupo y extrae los botones sin grupo
function obj:_organizeButtons()
    local groups = {}
    local ungrouped = {}
    
    for _, config in ipairs(obj.buttonsConfig) do
        if config.group then
            if not groups[config.group] then
                groups[config.group] = {}
            end
            table.insert(groups[config.group], config)
        else
            table.insert(ungrouped, config)
        end
    end
    
    return groups, ungrouped
end

-- Toggle de un grupo específico
function obj:_toggleGroup(groupName)
    obj.activeGroups[groupName] = not obj.activeGroups[groupName]
    obj:setupAllButtons()
end

-- Crea un botón individual (plugin)
function obj:_createPluginButton(config, posX, posY)
    local canvas = hs.canvas.new({ x = posX, y = posY, w = obj.buttonSize, h = obj.buttonSize })
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:clickActivating(false)

    -- Si el botón pertenece a un grupo, usar el color del grupo
    local bgColor = obj.buttonBackgroundColor
    if config.group then
        bgColor = obj:_generateGroupColor(config.group)
    end

    canvas:replaceElements({
        { type = "rectangle", action = "fill", fillColor = bgColor, roundedRectRadii = { xRadius = obj.buttonRadius, yRadius = obj.buttonRadius }, frame = { x = 0, y = 0, w = obj.buttonSize, h = obj.buttonSize } },
        { type = "text", text = config.buttonText, textColor = obj.buttonTextColor, textSize = 13, textAlignment = "center", frame = { x = 3, y = 21, w = obj.buttonSize - 6, h = obj.buttonSize } }
    })

    canvas:canvasMouseEvents(true, true)

    canvas:mouseCallback(function(c, msg, id, x, y)
        if msg == "mouseDown" then
            hs.alert.show("⏳", 0.3)
            hs.timer.doAfter(0.05, function()
                obj:_openPluginViaMenu(config.categoryName, config.pluginName)
            end)
        end
    end)

    canvas:show()
    return canvas
end

-- Crea un botón de grupo
function obj:_createGroupButton(groupName, posX, posY)
    local canvas = hs.canvas.new({ x = posX, y = posY, w = obj.buttonSize, h = obj.buttonSize })
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:clickActivating(false)

    local isExpanded = obj.activeGroups[groupName] or false
    local displayText = isExpanded and (groupName .. "\n▼") or (groupName .. "\n▶")
    local groupColor = obj:_generateGroupColor(groupName)

    canvas:replaceElements({
        { type = "rectangle", action = "fill", fillColor = groupColor, roundedRectRadii = { xRadius = obj.buttonRadius, yRadius = obj.buttonRadius }, frame = { x = 0, y = 0, w = obj.buttonSize, h = obj.buttonSize } },
        { type = "text", text = displayText, textColor = obj.buttonTextColor, textSize = 13, textAlignment = "center", frame = { x = 3, y = 21, w = obj.buttonSize - 6, h = obj.buttonSize } }
    })

    canvas:canvasMouseEvents(true, true)

    canvas:mouseCallback(function(c, msg, id, x, y)
        if msg == "mouseDown" then
            obj:_toggleGroup(groupName)
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

    local groups, ungrouped = obj:_organizeButtons()
    
    -- Construir lista de botones a mostrar
    local buttonsToShow = {}
    
    -- Primero agregar botones de grupos
    for groupName, groupButtons in pairs(groups) do
        table.insert(buttonsToShow, { type = "group", name = groupName })
        
        -- Si el grupo está expandido, agregar sus botones
        if obj.activeGroups[groupName] then
            for _, config in ipairs(groupButtons) do
                table.insert(buttonsToShow, { type = "plugin", config = config })
            end
        end
    end
    
    -- Luego agregar botones sin grupo
    for _, config in ipairs(ungrouped) do
        table.insert(buttonsToShow, { type = "plugin", config = config })
    end

    -- Crear los botones
    for i, item in ipairs(buttonsToShow) do
        local columnIndex = (i - 1) % buttonsPerRow
        local rowIndex = math.floor((i - 1) / buttonsPerRow)
        local posX = startX - (columnIndex * (obj.buttonSize + obj.buttonSpacing))
        local posY = startY - (rowIndex * (obj.buttonSize + obj.buttonSpacing))

        local button
        if item.type == "group" then
            button = obj:_createGroupButton(item.name, posX, posY)
        else
            button = obj:_createPluginButton(item.config, posX, posY)
        end
        
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
    obj.canvasButtons = {}
    obj.activeGroups = {}
end

-- Método de inicialización (se llama automáticamente con hs.loadSpoon)
function obj:init()
    -- Este método se llama cuando se carga el Spoon. No es necesario para cargar el ícono.
end

return obj