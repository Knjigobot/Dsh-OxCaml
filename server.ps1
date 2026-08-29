# server.ps1 - Native Cordis-OxCaml Web Daemon & SSE Engine (Zero-Python)
$Port = 8090
$Root = $PSScriptRoot

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:$Port/")
$Listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $Listener.Start()
    Write-Host "[Cordis-OxCaml] Native Daemon running on http://localhost:$Port (Zero-Python)" -ForegroundColor Green
} catch {
    Write-Host "[Cordis-OxCaml] Port $Port busy or already running." -ForegroundColor Yellow
    exit 0
}

$Version = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

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
            $InitData = [System.Text.Encoding]::UTF8.GetBytes("data: {`"type`":`"connected`",`"version`":$Version,`"status`":`"active`"}`n`n")
            $Stream.Write($InitData, 0, $InitData.Length)
            $Stream.Flush()
            
            # Send live ticks
            for ($i = 1; $i -le 10; $i++) {
                Start-Sleep -Milliseconds 1500
                $TickData = [System.Text.Encoding]::UTF8.GetBytes("data: {`"type`":`"tick`",`"tick`":$i,`"ast_state`":`"stable`",`"memory_slots`":500}`n`n")
                $Stream.Write($TickData, 0, $TickData.Length)
                $Stream.Flush()
            }
            $Response.Close()
        }
        elseif ($Path -eq "/api/status" -or $Path -eq "/_cordis_sync") {
            $Response.ContentType = "application/json"
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
            $Json = '{"status":"ok","engine":"Cordis-OxCaml","formal_layer":"Cubical-Agda/Rzk","poly":"active","version":' + $Version + '}'
            $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
            $Response.ContentLength64 = $Bytes.Length
            $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
            $Response.Close()
        }
        else {
            $FilePath = Join-Path $Root "index.html"
            if (Test-Path $FilePath) {
                $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
                $Response.ContentType = "text/html; charset=utf-8"
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
