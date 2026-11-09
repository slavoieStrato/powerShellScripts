Add-MpPreference -ExclusionPath    P:\repos
Add-MpPreference -ExclusionPath    P:\Temp
Add-MpPreference -ExclusionPath    P:\.cache
Add-MpPreference -ExclusionPath    P:\AppData
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Roaming\Cursor
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\Cursor
Add-MpPreference -ExclusionPath    C:\esp
Add-MpPreference -ExclusionPath    C:\Espressif
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\com.espressif.eim.dev
Add-MpPreference -ExclusionPath    P:\.cursor
Add-MpPreference -ExclusionPath    P:\.claude
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\.cursor
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\.claude
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\.codex
Add-MpPreference -ExclusionPath    P:\.codex

Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\Programs\cursor
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\OpenAI
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0


Add-MpPreference -ExclusionPath    P:\AppData\Roaming\Claude
Add-MpPreference -ExclusionPath    P:\AppData\Local\Claude
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Roaming\Claude
Add-MpPreference -ExclusionPath    C:\Users\SLavoie\AppData\Local\Claude


Add-MpPreference -ExclusionProcess C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\stm32c\ubeide.exe 
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-gcc.exe
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-g++.exe
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-objcopy.exe
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\lib\gcc\arm-none-eabi\13.3.1\cc1.exe
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeCLT_1.19.0\CMake\bin\cmake.exe
Add-MpPreference -ExclusionProcess C:\Users\SLavoie\MyFiles\bin\ccache.exe
Add-MpPreference -ExclusionProcess C:\Users\SLavoie\AppData\Local\Programs\cursor\Cursor.exe
Add-MpPreference -ExclusionProcess C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\stm32cubeide.exe
Add-MpPreference -ExclusionProcess "C:\Program Files\TortoiseGit\bin\TortoiseGitProc.exe"
Add-MpPreference -ExclusionProcess "C:\Program Files\Git\bin\git.exe"
Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.make.win32_2.2.0.202409170845\tools\bin\make.exe"
Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.0.202411081344\tools\bin\arm-none-eabi-gcc.exe"
Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.0.202411081344\tools\lib\gcc\arm-none-eabi\13.3.1\cc1.exe"
Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.13.3.rel1.win32_1.0.0.202411081344\tools\lib\gcc\arm-none-eabi\13.3.1\cc1plus.exe"

Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeCLT_1.19.0\Ninja\bin\ninja.exe"

Add-MpPreference -ExclusionProcess claude.exe
Add-MpPreference -ExclusionProcess codex.exe
Add-MpPreference -ExclusionProcess ChatGPT.exe
Add-MpPreference -ExclusionProcess "C:\Users\SLavoie\AppData\Local\Programs\cursor\resources\app\resources\helpers\node.exe"
Add-MpPreference -ExclusionProcess "C:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\arm-none-eabi\bin\as.exe"

Add-MpPreference -ExclusionProcess P:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\stm32cubeide.exe 
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-gcc.exe
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-g++.exe
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\bin\arm-none-eabi-objcopy.exe
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeCLT_1.19.0\GNU-tools-for-STM32\lib\gcc\arm-none-eabi\13.3.1\cc1.exe
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeCLT_1.19.0\CMake\bin\cmake.exe
Add-MpPreference -ExclusionProcess P:\ST\STM32CubeIDE_1.19.0\STM32CubeIDE\stm32cubeide.exe


Add-MpPreference -ExclusionPath "C:\ST"
Add-MpPreference -ExclusionPath "P:\ST"
Add-MpPreference -ExclusionPath "C:\Program Files\Git"



Add-MpPreference -ExclusionExtension .cyclo
Add-MpPreference -ExclusionExtension .list
Add-MpPreference -ExclusionExtension .d
Add-MpPreference -ExclusionExtension .c
Add-MpPreference -ExclusionExtension .h
Add-MpPreference -ExclusionExtension .cpp
Add-MpPreference -ExclusionExtension .hpp
Add-MpPreference -ExclusionExtension .o
Add-MpPreference -ExclusionExtension .su
Add-MpPreference -ExclusionExtension elf
Add-MpPreference -ExclusionExtension log
Add-MpPreference -ExclusionExtension obj
Add-MpPreference -ExclusionExtension s
