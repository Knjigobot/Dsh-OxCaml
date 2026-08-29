# server.ps1 - Native Cordis-OxCaml Web Daemon & SSE Engine (Zero-Python)
$Port = 8090
$Root = $PSScriptRoot
$FilePath = Join-Path $Root "index.html"

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:$Port/")
$Listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $Listener.Start()
    Write-Host "[Cordis-OxCaml] Native Daemon running on http://localhost:$Port (Zero-Python Auto-HMR)" -ForegroundColor Green
} catch {
    Write-Host "[Cordis-OxCaml] Port $Port busy or already running." -ForegroundColor Yellow
    exit 0
}

while ($Listener.IsListening) {
    try {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response
        $Path = $Request.Url.AbsolutePath

        if ($Path -eq "/events" -or $Path -eq "/_cordis_live") {
            $Response.ContentType = "text/event-stream"
            $Response.Headers.Add("Cache-Control", "no-cache, no-transform")
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
            $Response.SendChunked = $true
            
            $Stream = $Response.OutputStream
            $LastFileTicks = 0
            if (Test-Path $FilePath) {
                $LastFileTicks = (Get-Item $FilePath).LastWriteTimeUtc.Ticks
            }
            
            $InitData = [System.Text.Encoding]::UTF8.GetBytes("data: {`"type`":`"connected`",`"fileTicks`":$LastFileTicks,`"status`":`"active`"}`n`n")
            $Stream.Write($InitData, 0, $InitData.Length)
            $Stream.Flush()
            
            # Persistent file watcher loop
            $TickCount = 14
            while ($true) {
                Start-Sleep -Milliseconds 300
                $TickCount++
                
                # Check for file updates
                if (Test-Path $FilePath) {
                    $CurrentFileTicks = (Get-Item $FilePath).LastWriteTimeUtc.Ticks
                    if ($CurrentFileTicks -ne $LastFileTicks) {
                        $LastFileTicks = $CurrentFileTicks
                        $ReloadMsg = [System.Text.Encoding]::UTF8.GetBytes("data: {`"type`":`"reload`",`"fileTicks`":$CurrentFileTicks}`n`n")
                        $Stream.Write($ReloadMsg, 0, $ReloadMsg.Length)
                        $Stream.Flush()
                    }
                }
                
                # Send periodic heartbeat
                if ($TickCount % 5 -eq 0) {
                    $Heartbeat = [System.Text.Encoding]::UTF8.GetBytes("data: {`"type`":`"tick`",`"tick`":$TickCount}`n`n")
                    $Stream.Write($Heartbeat, 0, $Heartbeat.Length)
                    $Stream.Flush()
                }
            }
        }
        elseif ($Path -eq "/_cordis_version" -or $Path -eq "/version") {
            $CurrentFileTicks = 0
            if (Test-Path $FilePath) {
                $CurrentFileTicks = (Get-Item $FilePath).LastWriteTimeUtc.Ticks
            }
            $Response.ContentType = "application/json"
            $Response.Headers.Add("Cache-Control", "no-cache")
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
            $Json = '{"status":"ok","fileTicks":' + $CurrentFileTicks + ',"timestamp":' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + '}'
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.Close()
        }
        elseif ($Path -eq "/api/status" -or $Path -eq "/_cordis_sync") {
            $Response.ContentType = "application/json"
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
            $Json = '{"status":"ok","engine":"Cordis-OxCaml","formal_layer":"Cubical-Agda/Rzk","poly":"active"}'
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.Close()
        }
        else {
            if (Test-Path $FilePath) {
                $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
                $Response.ContentType = "text/html; charset=utf-8"
                $Response.Headers.Add("Cache-Control", "no-cache")
                $Response.Headers.Add("Access-Control-Allow-Origin", "*")
                $Response.ContentLength64 = $Bytes.Length
                $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            } else {
                $Response.StatusCode = 404
            }
            $Response.Close()
        }
    } catch {
        # Client disconnect or stream complete
    }
}
