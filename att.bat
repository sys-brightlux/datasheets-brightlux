@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ==========================================================
REM CONFIGURACAO
REM ==========================================================
set "JSON_FILE=dados.json"
set "TARGET_DIR=arquivos"
set "REPO_BRANCH=main"
set "TEMP_PS=temp_script_gen.ps1"

echo.
echo [1/5] Verificando ambiente...

REM Verifica GIT
git --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Git nao encontrado. Instale o Git for Windows.
    goto :ERRO_FATAL
)

REM Cria pasta de arquivos se nao existir
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
    echo [INFO] Pasta '%TARGET_DIR%' criada.
)

REM ==========================================================
REM 2. COPIAR ARQUIVOS (Mantem original na raiz)
REM ==========================================================
echo [2/5] Replicando PDFs para a pasta do repositorio...
if exist *.pdf (
    REM Usa COPY em vez de MOVE para manter os originais
    copy /Y "*.pdf" "%TARGET_DIR%\" >nul
    echo [INFO] Arquivos copiados para '%TARGET_DIR%'. Originais mantidos.
) else (
    echo [INFO] Nenhum PDF encontrado na raiz para copiar.
)

REM ==========================================================
REM 3. GERAR SCRIPT POWERSHELL
REM ==========================================================
echo [3/5] Gerando logica de atualizacao do JSON...

REM Limpa arquivo anterior
if exist "%TEMP_PS%" del "%TEMP_PS%"

REM Escreve o script PowerShell linha por linha
echo $jsonPath = '%JSON_FILE%' >> "%TEMP_PS%"
echo $dirPath = '%TARGET_DIR%' >> "%TEMP_PS%"
echo $baseUrl = 'arquivos' >> "%TEMP_PS%"
echo. >> "%TEMP_PS%"
echo if (-not (Test-Path $jsonPath)) { >> "%TEMP_PS%"
echo     Write-Host '[AVISO] dados.json nao encontrado. Sera criado.' >> "%TEMP_PS%"
echo     $jsonContent = @() >> "%TEMP_PS%"
echo } else { >> "%TEMP_PS%"
echo     try { >> "%TEMP_PS%"
echo         $jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8 ^| ConvertFrom-Json >> "%TEMP_PS%"
echo     } catch { >> "%TEMP_PS%"
echo         Write-Host '[AVISO] JSON invalido. Recriando...' >> "%TEMP_PS%"
echo         $jsonContent = @() >> "%TEMP_PS%"
echo     } >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo if (-not $jsonContent) { $jsonContent = @() } >> "%TEMP_PS%"
echo. >> "%TEMP_PS%"
echo $existingFiles = @() >> "%TEMP_PS%"
echo if ($jsonContent.Count -gt 0) { $existingFiles = $jsonContent.arquivo } >> "%TEMP_PS%"
echo. >> "%TEMP_PS%"
echo $filesOnDisk = Get-ChildItem -Path $dirPath -Filter *.pdf >> "%TEMP_PS%"
echo $updated = $false >> "%TEMP_PS%"
echo. >> "%TEMP_PS%"
echo foreach ($file in $filesOnDisk) { >> "%TEMP_PS%"
echo     $relativePath = '{0}/{1}' -f $baseUrl, $file.Name >> "%TEMP_PS%"
echo     if ($existingFiles -notcontains $relativePath) { >> "%TEMP_PS%"
echo         Write-Host ('[NOVO] Adicionando ao indice: ' + $file.Name) >> "%TEMP_PS%"
echo         $maxId = 0 >> "%TEMP_PS%"
echo         if ($jsonContent.Count -gt 0) { >> "%TEMP_PS%"
echo             $ids = $jsonContent.id >> "%TEMP_PS%"
echo             if ($ids) { $maxId = ($ids ^| Measure-Object -Maximum).Maximum } >> "%TEMP_PS%"
echo         } >> "%TEMP_PS%"
echo         $newId = $maxId + 1 >> "%TEMP_PS%"
echo         $newObj = [PSCustomObject]@{ >> "%TEMP_PS%"
echo             id = $newId >> "%TEMP_PS%"
echo             produto = $file.BaseName >> "%TEMP_PS%"
echo             descricao = ('Documento técnico ou folha de dados para o produto {0}.' -f $file.BaseName) >> "%TEMP_PS%"
echo             arquivo = $relativePath >> "%TEMP_PS%"
echo         } >> "%TEMP_PS%"
echo         $jsonContent += $newObj >> "%TEMP_PS%"
echo         $updated = $true >> "%TEMP_PS%"
echo     } >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"
echo. >> "%TEMP_PS%"
echo if ($updated) { >> "%TEMP_PS%"
echo     $jsonContent ^| ConvertTo-Json -Depth 5 ^| Set-Content -Path $jsonPath -Encoding UTF8 >> "%TEMP_PS%"
echo     exit 0 >> "%TEMP_PS%"
echo } else { >> "%TEMP_PS%"
echo     Write-Host '[INFO] O indice JSON esta atualizado.' >> "%TEMP_PS%"
echo     exit 2 >> "%TEMP_PS%"
echo } >> "%TEMP_PS%"

REM ==========================================================
REM 4. EXECUTAR
REM ==========================================================
echo [4/5] Processando JSON...

if not exist "%TEMP_PS%" (
    echo [ERRO CRITICO] Script temporario nao foi gerado.
    goto :ERRO_FATAL
)

powershell -ExecutionPolicy Bypass -File "%TEMP_PS%"
set PS_EXIT_CODE=%ERRORLEVEL%

REM Limpa temp
del "%TEMP_PS%" >nul 2>&1

if %PS_EXIT_CODE% EQU 0 (
    echo [SUCESSO] dados.json atualizado.
) else if %PS_EXIT_CODE% EQU 2 (
    echo [INFO] Sem novos registros para adicionar.
) else (
    echo [ERRO] Falha no processamento. Codigo: %PS_EXIT_CODE%
    goto :ERRO_FATAL
)

REM ==========================================================
REM 5. GIT PUSH
REM ==========================================================
echo [5/5] Sincronizando repositorio...

git add %JSON_FILE%
git add %TARGET_DIR%/*.pdf

git diff-index --quiet HEAD
if %ERRORLEVEL% NEQ 0 (
    echo [GIT] Enviando alteracoes para '%REPO_BRANCH%'...
    git commit -m "auto: atualizacao de datasheets e json"
    git push origin %REPO_BRANCH%
    echo [GIT] Concluido com sucesso.
) else (
    echo [GIT] Tudo atualizado. Nada para enviar.
)

goto :FIM

:ERRO_FATAL
echo.
echo [!] Erro critico. Verifique as mensagens acima.
color 4

:FIM
echo.
echo Pressione qualquer tecla para sair...
pause >nul