-- =============================================================================
--  Spoon: ProToolsAutomator (Enhanced Edition v4.0)
-- =============================================================================
--  Crea una paleta de botones flotantes para abrir plugins de AudioSuite
--  y ejecutar macros personalizadas en Pro Tools.
-- =============================================================================

local obj = {}

-- =============================================================================
--  1. METADATOS DEL SPOON
-- =============================================================================
obj.name = "ProToolsAutomator"
obj.version = "4.0"
obj.author = "Eugenio Azurmendi <Chugeno>"
obj.homepage = "https://github.com/Chugeno/protools-hammerspoon-config"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- =============================================================================
--  2. CONFIGURACIÓN DE PANTALLA Y ESTÉTICA
-- =============================================================================
obj.targetScreenIndex = 1  -- Pantalla donde aparecerán los botones
obj.proToolsAppName = "Pro Tools"
obj.buttonBackgroundColor = { red = 0.2, green = 0.25, blue = 0.3, alpha = 0.95 }
obj.buttonTextColor = { red = 0.9, green = 0.95, blue = 1.0, alpha = 1.0 }
obj.buttonSize = 80
obj.buttonRadius = 10
obj.marginRight = 20
obj.marginBottom = 100
obj.buttonSpacing = 10
-- Devuelve el marginBottom apropiado según el número de pantalla
function obj:marginForScreen(index)
    if index == 2 then
        return 20
    end
    return 100
end

-- =============================================================================
--  3. SISTEMA DE CONFIGURACIÓN PERSISTENTE
-- =============================================================================
obj.configFile = hs.configdir .. "/ProToolsAutomator_config.json"

function obj:loadConfig()
    local file = io.open(obj.configFile, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local success, config = pcall(hs.json.decode, content)
        if success then
            return config
        end
    end
    return nil
end

function obj:saveConfig(config)
    local file = io.open(obj.configFile, "w")
    if file then
        file:write(hs.json.encode(config))
        file:close()
        return true
    end
    return false
end

-- =============================================================================
--  4. CAPTURADOR DE COORDENADAS (FLUJO GUIADO)
-- =============================================================================
obj.coordinateCapture = {
    isActive = false,
    overlay = nil,
    eventTap = nil
}

-- A. PRIMER PASO: Instrucciones y Preparación
function obj:startGuidedCapture()
    -- Obtenemos la ruta del archivo actual para decírsela al usuario
    local currentPath = debug.getinfo(1, "S").source:sub(2)
    
    hs.focus()
    
    -- Watcher para mantener el diálogo al frente
    local focusWatcher = hs.application.watcher.new(function(appName, eventType, app)
        if eventType == hs.application.watcher.activated and appName ~= "Hammerspoon" then
            hs.timer.doAfter(0.05, function() hs.focus() end)
        end
    end)
    focusWatcher:start()
    
    local clickedButton = hs.dialog.blockAlert(
        "PREPARACIÓN PARA CAPTURA",
        "Antes de capturar, prepara Pro Tools:\n\n" ..
        "1. Selecciona un Track Mono.\n" ..
        "2. Presiona 'E' para que ocupe toda la pantalla.\n\n" ..
        "⚠️ IMPORTANTE: Debes cerrar este diálogo antes de poder\n" ..
        "manipular Pro Tools (el diálogo siempre está al frente).\n\n" ..
        "Cuando estés listo, presiona '🎯 Activar Captura'\n" ..
        "y luego haz click en el número de paneo del track.",
        "🎯 Activar Captura", -- Botón principal
        "Cancelar"            -- Botón secundario
    )
    
    focusWatcher:stop()

    if clickedButton == "🎯 Activar Captura" then
        -- Pequeño delay para que te de tiempo a soltar el mouse antes de activar
        hs.timer.doAfter(0.5, function() 
            self:startCoordinateCaptureMode() 
        end)
    end
end

-- B. SEGUNDO PASO: Modo Captura (Overlays)
function obj:startCoordinateCaptureMode()
    if obj.coordinateCapture.isActive then return end
    obj.coordinateCapture.isActive = true
    
    -- Instrucciones visuales en todas las pantallas
    local screens = hs.screen.allScreens()
    obj.coordinateCapture.overlays = {}
    
    for i, screen in ipairs(screens) do
        local frame = screen:fullFrame()
        local canvas = hs.canvas.new(frame)
        
        -- Fondo gris semi-transparente
        canvas[1] = {
            type = "rectangle",
            action = "fill",
            fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.3 },
            frame = { x = 0, y = 0, w = frame.w, h = frame.h }
        }
        
        -- Texto gigante
        canvas[2] = {
            type = "text",
            text = "🎯 HAZ CLICK EN EL OBJETIVO",
            textFont = "Helvetica Bold",
            textSize = 50,
            textColor = { red = 1, green = 0.2, blue = 0.2, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h/2 - 50, w = frame.w, h = 100 }
        }
        
        canvas:show()
        canvas:level(hs.canvas.windowLevels.overlay)
        table.insert(obj.coordinateCapture.overlays, canvas)
    end
    
    -- C. TERCER PASO: Detectar el Click
    obj.coordinateCapture.eventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
        local clickPos = hs.mouse.absolutePosition()
        
        -- 1. Calcular datos
        local screens = hs.screen.allScreens()
        local screenNumber = 1
        local relativeX = 0
        local relativeY = 0
        
        for i, screen in ipairs(screens) do
            local frame = screen:fullFrame()
            if clickPos.x >= frame.x and clickPos.x < (frame.x + frame.w) and
               clickPos.y >= frame.y and clickPos.y < (frame.y + frame.h) then
                screenNumber = i
                -- Convertir a enteros
                relativeX = math.floor(clickPos.x - frame.x + 0.5)
                relativeY = math.floor(clickPos.y - frame.y + 0.5)
                break
            end
        end
        
        -- 2. Guardar en config.json
        local config = self:loadConfig() or {}
        config.splitMonoCoordinates = {
            screen = screenNumber,
            x = relativeX,
            y = relativeY
        }
        self:saveConfig(config)
        
        -- 3. IMPORTANTE: Salir del modo INMEDIATAMENTE (antes de la alerta)
        self:stopCoordinateCapture()
        
        -- 4. Mostrar confirmación
        hs.timer.doAfter(0.1, function()
            hs.focus()
            
            local focusWatcher = hs.application.watcher.new(function(appName, eventType, app)
                if eventType == hs.application.watcher.activated and appName ~= "Hammerspoon" then
                    hs.timer.doAfter(0.05, function() hs.focus() end)
                end
            end)
            focusWatcher:start()
            
            hs.dialog.blockAlert(
                "✅ Coordenadas Guardadas",
                string.format(
                    "Coordenadas guardadas automáticamente:\n\n" ..
                    "Pantalla: %d\n" ..
                    "X: %d\n" ..
                    "Y: %d\n\n" ..
                    "Ya están listas para usar en Split Mono.",
                    screenNumber, relativeX, relativeY
                ),
                "Perfecto"
            )
            
            focusWatcher:stop()
        end)
        
        return true -- Bloquear el click real para no afectar a Pro Tools
    end):start()
    
    -- Tecla ESC para cancelar
    obj.coordinateCapture.escapeHotkey = hs.hotkey.bind({}, "escape", function()
        self:stopCoordinateCapture()
        hs.alert.show("❌ Cancelado")
    end)
end

function obj:stopCoordinateCapture()
    if obj.coordinateCapture.eventTap then
        obj.coordinateCapture.eventTap:stop()
        obj.coordinateCapture.eventTap = nil
    end
    
    if obj.coordinateCapture.overlays then
        for _, canvas in ipairs(obj.coordinateCapture.overlays) do
            canvas:delete()
        end
        obj.coordinateCapture.overlays = {}
    end
    
    if obj.coordinateCapture.escapeHotkey then
        obj.coordinateCapture.escapeHotkey:delete()
        obj.coordinateCapture.escapeHotkey = nil
    end
    
    obj.coordinateCapture.isActive = false
end

-- =============================================================================
--  5. IDENTIFICADOR DE PANTALLAS (INTEGRADO)
-- =============================================================================
obj.screenOverlays = {}
obj.screenIdentifierEnabled = true

function obj:showScreenIdentifier()
    self:clearScreenIdentifier()
    
    -- IMPORTANTE: NO ordenamos, usamos el orden nativo de Hammerspoon
    local screens = hs.screen.allScreens()
    print("\n=== IDENTIFICADOR DE PANTALLAS ===")
    
    for i, screen in ipairs(screens) do
        local frame = screen:fullFrame()
        local name = screen:name()
        local isPrimary = screen == hs.screen.primaryScreen()
        local primaryText = isPrimary and " ⭐ PRINCIPAL" or ""
        
        print(string.format("Pantalla %d: %s%s", i, name, primaryText))
        print(string.format("  Posición: x=%d, y=%d", frame.x, frame.y))
        print(string.format("  Tamaño: %dx%d", frame.w, frame.h))
        
        local canvas = hs.canvas.new(frame)
        
        -- Fondo semi-transparente
        canvas[1] = {
            type = "rectangle",
            action = "fill",
            fillColor = { red = 0, green = 0, blue = 0, alpha = 0.7 },
            frame = { x = 0, y = 0, w = frame.w, h = frame.h }
        }
        
        -- Número de pantalla grande
        canvas[2] = {
            type = "text",
            text = string.format("PANTALLA %d%s", i, primaryText),
            textFont = "Helvetica Bold",
            textSize = 120,
            textColor = { red = 1, green = 1, blue = 1, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h/2 - 150, w = frame.w, h = 150 }
        }
        
        -- Información detallada
        local detailText = string.format(
            "%s\nPosición: (%d, %d)\nTamaño: %dx%d",
            name, frame.x, frame.y, frame.w, frame.h
        )
        
        canvas[3] = {
            type = "text",
            text = detailText,
            textFont = "Menlo",
            textSize = 24,
            textColor = { red = 0.8, green = 0.8, blue = 0.8, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h/2 + 20, w = frame.w, h = 200 }
        }
        
        -- Instrucción
        canvas[4] = {
            type = "text",
            text = "Presiona ESC o haz click para cerrar",
            textFont = "Helvetica",
            textSize = 20,
            textColor = { red = 1, green = 1, blue = 0.3, alpha = 1 },
            textAlignment = "center",
            frame = { x = 0, y = frame.h - 100, w = frame.w, h = 50 }
        }
        
        canvas:show()
        canvas:clickActivating(false)
        canvas:canvasMouseEvents(true, true)
        canvas:mouseCallback(function(c, m, id, x, y)
            if m == "mouseDown" then
                self:clearScreenIdentifier()
            end
        end)
        
        table.insert(obj.screenOverlays, canvas)
    end
    
    -- Auto-cerrar después de 15 segundos
    hs.timer.doAfter(15, function()
        self:clearScreenIdentifier()
    end)
    
    -- Hotkey ESC para cerrar
    obj.screenEscapeHotkey = hs.hotkey.bind({}, "escape", function()
        self:clearScreenIdentifier()
        if obj.screenEscapeHotkey then
            obj.screenEscapeHotkey:delete()
            obj.screenEscapeHotkey = nil
        end
    end)
end

function obj:clearScreenIdentifier()
    for _, canvas in ipairs(obj.screenOverlays) do
        canvas:delete()
    end
    obj.screenOverlays = {}
    
    if obj.screenEscapeHotkey then
        obj.screenEscapeHotkey:delete()
        obj.screenEscapeHotkey = nil
    end
end

-- =============================================================================
--  5. ASISTENTE DE PRIMERA VEZ
-- =============================================================================
function obj:firstTimeSetup()
    local alert = hs.alert.show("👋 ¡Bienvenido a ProToolsAutomator!\n\nIdentificando tus pantallas...", 3)
    
    hs.timer.doAfter(0.5, function()
        self:showScreenIdentifier()
        
        hs.timer.doAfter(2, function()
            hs.focus()
            hs.timer.usleep(100000)
            hs.focus()
            local button, screenNumber = hs.dialog.textPrompt(
                "Configuración de Pantalla",
                "¿En qué número de pantalla quieres que aparezcan los botones?\n\n" ..
                "(Mira los números grandes en cada pantalla)",
                "1",
                "Guardar", "Cancelar"
            )
            
            self:clearScreenIdentifier()
            
            if button == "Guardar" and screenNumber then
                local num = tonumber(screenNumber)
                if num and num > 0 then
                    obj.targetScreenIndex = num
                    
                    -- Determinar y aplicar marginBottom según la pantalla
                    obj.marginBottom = obj:marginForScreen(num)

                    -- Guardar configuración
                    local config = {
                        targetScreenIndex = num,
                        marginBottom = obj.marginBottom,
                        firstTimeSetupCompleted = true,
                        version = obj.version
                    }
                    
                    if self:saveConfig(config) then
                        hs.alert.show("✅ Configuración guardada!\nPantalla: " .. num, 2)
                        self:setupAllButtons()
                    else
                        hs.alert.show("⚠️ No se pudo guardar la configuración", 2)
                    end
                else
                    hs.alert.show("❌ Número de pantalla inválido", 2)
                end
            else
                hs.alert.show("Usando pantalla 1 por defecto", 2)
            end
        end)
    end)
end

-- ==================================================
-- 6. FUNCIÓN AUXILIAR PARA COORDENADAS EN MÚLTIPLES PANTALLAS
-- ==================================================
function getAbsoluteCoordinates(screenNumber, relativeX, relativeY)
    local screens = hs.screen.allScreens()
    
    if screenNumber > #screens then
        hs.alert.show("⚠️ Pantalla " .. screenNumber .. " no existe")
        return nil, nil
    end
    
    local targetScreen = screens[screenNumber]
    local screenFrame = targetScreen:fullFrame()
    
    local absoluteX = screenFrame.x + relativeX
    local absoluteY = screenFrame.y + relativeY
    
    return absoluteX, absoluteY
end

-- =============================================================================
--  7. CONFIGURACIÓN DE BOTONES
-- =============================================================================
obj.buttonsConfig = {
    -- --- PLUGINS NORMALES ---
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 Voice De-noise", buttonText = "RX Voice\nDe-noise" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 Spectral De-noise", buttonText = "RX Spectral\nDe-noise" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-clip", buttonText = "RX\nDe-clip" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-click", buttonText = "RX\nDe-click" },
    { group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-crackle", buttonText = "RX\nDe-crackle" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeClick 2", buttonText ="Acon\nDeClick" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeClip 2", buttonText ="Acon\nDeClip" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeVerberate 3", buttonText ="Acon\nDeVerb" },
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital DeNoise 2", buttonText ="Acon\nDeNoise" },    
    { group = "Acon", categoryName = "Noise Reduction", pluginName = "Acon Digital Extract:Dialogue", buttonText ="Acon\nDialogue" },    
    
    -- Botones sin grupo
    { categoryName = "Noise Reduction", pluginName = "Hush Mix", buttonText = "Hush\nMix" },
    { categoryName = "Dynamics", pluginName = "RDeEsser Stereo", buttonText = "RDeEsser\nStereo" },
    { categoryName = "Other", pluginName = "Blue Cat's PatchWork", buttonText = "Blue Cat's\nPatchWork" },

    -- =====================================================================
    --  BOTÓN: SPLIT MONO
    -- =====================================================================
    {
        buttonText = "Split\ninto Mono",
        customColor = { red = 0.0, green = 0.6, blue = 0.2, alpha = 1.0 },
        isCustomAction = true,
        action = function()
            -- Validar que existan coordenadas guardadas
            local config = obj:loadConfig() or {}
            if not config.splitMonoCoordinates then
                hs.alert.show("⚠️ Primero debes capturar coordenadas desde el menú 🎯")
                return
            end
            
            local tiempo_base = 0.2
            local pt = hs.application.get("Pro Tools")
            if not pt then hs.alert.show("Pro Tools no está activo") return end

            local function esperar(multiplicador) 
                local m = multiplicador or 1
                hs.timer.usleep(tiempo_base * 1000000 * m) 
            end

            print("\n--- SECUENCIA SPLIT & CENTER ---")
            
            if not pt:selectMenuItem({"Track", "Split into Mono"}) then
                hs.alert.show("❌ Falló Split") return
            end
            esperar(1) 

            hs.eventtap.keyStroke({}, "P")
            esperar(1) 
            hs.eventtap.keyStroke({}, "ñ")
            esperar(1)
            hs.eventtap.keyStroke({}, "ñ")
            esperar(1)

            hs.eventtap.keyStroke({}, "E")
            esperar(1) 
            
            -- Cargar coordenadas desde config
            local config = obj:loadConfig() or {}
            local coords = config.splitMonoCoordinates
            
            if not coords then
                hs.alert.show("⚠️ Primero captura coordenadas desde el menú")
                return
            end
            
            local SCREEN_TO_USE = coords.screen
            local relativeX = coords.x
            local relativeY = coords.y

            local targetX, targetY = getAbsoluteCoordinates(SCREEN_TO_USE, relativeX, relativeY)

            if targetX and targetY then
                local center = { x = targetX, y = targetY }
                
                local mouseDown = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, center, {"alt"})
                mouseDown:post()
                
                esperar(0.5) 
                
                local mouseUp = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, center, {"alt"})
                mouseUp:post()
                
                hs.alert.show("✅")
            end

            esperar(1) 
            hs.eventtap.keyStroke({}, "E") 
            esperar(1)

            hs.eventtap.keyStroke({}, "P") 
            esperar(1)
            hs.eventtap.keyStroke({"shift"}, "P")
            esperar(1)
            
            pt:selectMenuItem({"Track", "Delete..."})
            esperar(1)
            hs.eventtap.keyStroke({}, "return")
        end
    }
}

-- =============================================================================
--  8. VARIABLES INTERNAS
-- =============================================================================
obj.canvasButtons = {}
obj.buttonsVisible = true
obj.toggleMenu = nil
obj.screenWatcher = nil
obj.activeGroups = {}
obj.groupColors = {}

-- =============================================================================
--  9. LÓGICA DEL SPOON (RESTO DE FUNCIONES - SIN CAMBIOS)
-- =============================================================================

function obj:_generateGroupColor(groupName)
    if obj.groupColors[groupName] then return obj.groupColors[groupName] end
    math.randomseed(string.byte(groupName, 1) * string.byte(groupName, -1) * #groupName)
    
    local hue = math.random(0, 360)
    local saturation = math.random(40, 70) / 100
    local brightness = math.random(35, 55) / 100
    
    local function hsvToRgb(h, s, v)
        local c = v * s
        local x = c * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - c
        local r, g, b
        if h < 60 then r,g,b=c,x,0 elseif h < 120 then r,g,b=x,c,0 elseif h < 180 then r,g,b=0,c,x elseif h < 240 then r,g,b=0,x,c elseif h < 300 then r,g,b=x,0,c else r,g,b=c,0,x end
        return { red = r + m, green = g + m, blue = b + m, alpha = 0.95 }
    end
    
    local color = hsvToRgb(hue, saturation, brightness)
    obj.groupColors[groupName] = color
    math.randomseed(os.time())
    return color
end

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
        hs.alert.show("❌ Error Plugin", 1)
    end
end

function obj:_organizeButtons()
    local groups = {}
    local ungrouped = {}
    
    for _, config in ipairs(obj.buttonsConfig) do
        if config.group then
            if not groups[config.group] then groups[config.group] = {} end
            table.insert(groups[config.group], config)
        else
            table.insert(ungrouped, config)
        end
    end
    return groups, ungrouped
end

function obj:_toggleGroup(groupName)
    obj.activeGroups[groupName] = not obj.activeGroups[groupName]
    obj:setupAllButtons()
end

function obj:_createPluginButton(config, posX, posY)
    local canvas = hs.canvas.new({ x = posX, y = posY, w = obj.buttonSize, h = obj.buttonSize })
    canvas:level(hs.canvas.windowLevels.floating)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    canvas:clickActivating(false)

    local bgColor = obj.buttonBackgroundColor
    if config.customColor then
        bgColor = config.customColor
    elseif config.group then
        bgColor = obj:_generateGroupColor(config.group)
    end

    canvas:replaceElements({
        { type = "rectangle", action = "fill", fillColor = bgColor, roundedRectRadii = { xRadius = obj.buttonRadius, yRadius = obj.buttonRadius }, frame = { x = 0, y = 0, w = obj.buttonSize, h = obj.buttonSize } },
        { type = "text", text = config.buttonText, textColor = obj.buttonTextColor, textSize = 13, textAlignment = "center", frame = { x = 3, y = 21, w = obj.buttonSize - 6, h = obj.buttonSize } }
    })

    canvas:canvasMouseEvents(true, true)

    canvas:mouseCallback(function(c, msg, id, x, y)
        if msg == "mouseDown" then
            if config.isCustomAction and config.action then
                config.action()
            else
                hs.alert.show("⏳", 0.3)
                hs.timer.doAfter(0.05, function()
                    obj:_openPluginViaMenu(config.categoryName, config.pluginName)
                end)
            end
        end
    end)

    canvas:show()
    return canvas
end

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
        if msg == "mouseDown" then obj:_toggleGroup(groupName) end
    end)

    canvas:show()
    return canvas
end

function obj:setupAllButtons()
    for _, canvas in ipairs(obj.canvasButtons) do canvas:delete() end
    obj.canvasButtons = {}

    -- IMPORTANTE: NO ordenamos, usamos el orden directo de allScreens()
    local screens = hs.screen.allScreens()
    
    local targetScreen = screens[obj.targetScreenIndex] or screens[1]
    local screenFrame = targetScreen:fullFrame()

    print(string.format("📍 Creando botones en Pantalla %d (%s)", 
        obj.targetScreenIndex, targetScreen:name()))

    local buttonsPerRow = math.floor((screenFrame.w - obj.marginRight - obj.buttonSpacing) / (obj.buttonSize + obj.buttonSpacing))
    
    local startX = (screenFrame.x + screenFrame.w) - obj.marginRight - obj.buttonSize
    local startY = (screenFrame.y + screenFrame.h) - obj.marginBottom - obj.buttonSize

    local groups, ungrouped = obj:_organizeButtons()
    local buttonsToShow = {}
    
    for groupName, groupButtons in pairs(groups) do
        table.insert(buttonsToShow, { type = "group", name = groupName })
        if obj.activeGroups[groupName] then
            for _, config in ipairs(groupButtons) do table.insert(buttonsToShow, { type = "plugin", config = config }) end
        end
    end
    
    for _, config in ipairs(ungrouped) do
        table.insert(buttonsToShow, { type = "plugin", config = config })
    end

    for i, item in ipairs(buttonsToShow) do
        local columnIndex = (i - 1) % buttonsPerRow
        local rowIndex = math.floor((i - 1) / buttonsPerRow)
        
        local posX = startX - (columnIndex * (obj.buttonSize + obj.buttonSpacing))
        local posY = startY - (rowIndex * (obj.buttonSize + obj.buttonSpacing))

        if item.type == "group" then
            table.insert(obj.canvasButtons, obj:_createGroupButton(item.name, posX, posY))
        else
            table.insert(obj.canvasButtons, obj:_createPluginButton(item.config, posX, posY))
        end
    end
end

function obj:toggleButtons()
    obj.buttonsVisible = not obj.buttonsVisible
    for _, canvas in ipairs(obj.canvasButtons) do
        if obj.buttonsVisible then canvas:show() else canvas:hide() end
    end
end

-- =============================================================================
--  10. MÉTODOS PÚBLICOS
-- =============================================================================
function obj:start()
    self:stop()
    
    -- 1. Intentar cargar configuración guardada
    local config = self:loadConfig()
    
    if config then
        -- Si hay archivo guardado, usamos esa pantalla
        obj.targetScreenIndex = config.targetScreenIndex or 1
        -- Prioriza el marginBottom guardado en config; si no existe, usa la regla por pantalla
        if config.marginBottom then
            obj.marginBottom = config.marginBottom
        else
            obj.marginBottom = obj:marginForScreen(obj.targetScreenIndex)
        end
        print("✅ ProToolsAutomator: Configuración cargada. Pantalla: " .. obj.targetScreenIndex .. ", marginBottom: " .. obj.marginBottom)
    else
        -- Si NO hay archivo, usamos la 1 por defecto
        obj.targetScreenIndex = 1
        obj.marginBottom = obj:marginForScreen(1)
        print("ℹ️ ProToolsAutomator: Sin configuración previa. Usando Pantalla 1 por defecto. marginBottom: " .. obj.marginBottom)
    end
    
    -- Menú en barra
    self.toggleMenu = hs.menubar.new()
    if self.toggleMenu then
        self.toggleMenu:setTooltip("ProTools Automator")
        
        -- Menú con opciones
        self.toggleMenu:setMenu({
            { title = "Mostrar/Ocultar Botones", fn = function() obj:toggleButtons() end },
            { title = "-" },
            { title = "🎯 Capturar Coordenadas", fn = function() obj:startGuidedCapture() end },
            { title = "📺 Identificar Pantallas", fn = function() obj:showScreenIdentifier() end },
            { title = "⚙️ Reconfigurar Pantalla", fn = function() obj:firstTimeSetup() end },
            { title = "-" },
            { title = "Pantalla actual: " .. obj.targetScreenIndex, disabled = true }
        })
        
        local protoolsIcon = hs.image.imageFromPath(hs.spoons.resourcePath("protools.png"))
        if protoolsIcon then 
            self.toggleMenu:setIcon(protoolsIcon) 
        else 
            self.toggleMenu:setTitle("🎵") 
        end
    end
    
    -- Actualizar botones si cambia la pantalla
    self.screenWatcher = hs.screen.watcher.new(function() 
        obj:setupAllButtons() 
    end):start()
    
    -- Crear botones inmediatamente
    self:setupAllButtons()
end

function obj:stop()
    if self.toggleMenu then self.toggleMenu:delete(); self.toggleMenu = nil end
    if self.screenWatcher then self.screenWatcher:stop(); self.screenWatcher = nil end
    for _, canvas in ipairs(self.canvasButtons) do canvas:delete() end
    obj.canvasButtons = {}
    obj.activeGroups = {}
    self:clearScreenIdentifier()
    self:stopCoordinateCapture()
end

function obj:init() end

return obj