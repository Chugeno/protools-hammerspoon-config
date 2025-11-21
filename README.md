# 🎵 ProToolsAutomator Spoon for Hammerspoon

Este es un "Spoon" para [Hammerspoon](https://www.hammerspoon.org/) que acelera el flujo de trabajo en Avid Pro Tools.

## ✨ Funcionalidad Principal

1.  **Paleta Flotante:** Crea una botonera en pantalla que automatiza la carga de plugins de AudioSuite, navegando por los menús automáticamente pudiendo crear grupos facilmente.
2.  **Macro "Split into mono":** Una automatización avanzada para dividir tracks estéreo a mono, limpiar el track original y resetear el paneo en un solo clic.

## 📥 Instalación

1.  Descarga la última versión desde la página de Releases.
2.  Descomprime el archivo y haz doble clic en `ProToolsAutomator.spoon`. Hammerspoon lo instalará automáticamente.

## ⚙️ Configuración Básica

Añade el siguiente código a tu archivo `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("ProToolsAutomator")
spoon.ProToolsAutomator:start()
```

---

## 🖥️ Configuración de Pantalla (Si no ves los botones)

Por defecto, la botonera aparece en la **Pantalla 1**. Si tienes múltiples monitores y los botones no aparecen donde quieres (o no los ves):

1.  Busca el icono de Pro Tools en la barra de menú superior de tu Mac.
2.  Selecciona **"⚙️ Reconfigurar Pantalla"**.
3.  Escribe el número de la pantalla donde deseas que vivan los botones.

---

## 🎛️ Configuración de la Macro "SPLIT FIX"

El botón **Split Mono** ejecuta una secuencia compleja para limpiar audios estéreo separados en mono:
1.  Ejecuta *Split into Mono*.
2.  Elimina el track estéreo original.
3.  **Hace Alt+Click en el paneo** del nuevo track mono para centrarlo.

### 🚨 Calibración Obligatoria

Para que el paso de "Alt+Click" funcione, **necesitas enseñar al script dónde hacer clic** en tu pantalla, ya que esto varía según tu resolución.

1.  Ve al menú del Spoon (logo de ProTools) y selecciona **"🎯 Capturar Coordenadas"**.
2.  Estas instrucciones apareceran en pantalla no te preocupes (harás clic sobre el valor de paneo que para resetear).
3.  El script copiará un código en tu portapapeles automáticamente.
4.  Abre el archivo `init.lua` del Spoon ubicado en:

`~/Users/tunombredeusuario~/.hammerspoon/Spoons/ProToolsAutomator.spoon/init.lua`,

 busca la **LÍNEA 440** (aproximadamente) y pega el código reemplazando los valores existentes.

```lua
-- Ejemplo de lo que pegarás:
local SCREEN_TO_USE = 1
local relativeX = 500
local relativeY = 300
```

---

## 🎨 Personalización

Puedes agregar o quitar botones fácilmente modificando la tabla `obj.buttonsConfig` al inicio del archivo `init.lua` del Spoon.

```lua
-- Ejemplo de configuración:
{ group = "RX", categoryName = "Noise Reduction", pluginName = "RX 11 De-click", buttonText = "RX\nDe-click" },
```

*   **group:** Agrupa botones bajo un mismo color desplegable.
*   **categoryName:** El nombre exacto de la categoría en el menú AudioSuite.
*   **pluginName:** El nombre exacto del plugin.

[Cafe](https://buymeacoffee.com/chugeno)