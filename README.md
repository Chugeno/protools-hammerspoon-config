# 🎵 ProToolsAutomator Spoon for Hammerspoon

Este es un "Spoon" para [Hammerspoon](https://www.hammerspoon.org/) que acelera el flujo de trabajo en Pro Tools.

## Funcionalidad Principal

Crea una paleta de botones flotantes en la pantalla. Cada botón está asignado para abrir un plugin específico de AudioSuite, automatizando la navegación por los menús de Pro Tools.

## Instalación

1.  Descarga la última versión desde la página de Releases.
2.  Descomprime el archivo y haz doble clic en `ProToolsAutomator.spoon`. Hammerspoon lo instalará automáticamente.

## Configuración

Añade el siguiente código a tu archivo `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("ProToolsAutomator")
spoon.ProToolsAutomator:start()
```

Puedes agregar o quitar botones fácilmente modificando la tabla `buttonsConfig` dentro del archivo `init.lua` del Spoon.
