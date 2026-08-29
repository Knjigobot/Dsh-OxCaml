# server.ps1 - Native Cordis-OxCaml Web Daemon & SSE Engine (Zero-Python)
 = 8088
 = 'c:\Users\asd\Documents\cordisoxcaml'

 = New-Object System.Net.HttpListener
.Prefixes.Add(http://localhost:/)
.Prefixes.Add(http://127.0.0.1:/)

try {
    .Start()
    Write-Host [Cordis-OxCaml] Native Daemon running on http://localhost: (Zero-Python) -ForegroundColor Green
} catch {
    Write-Host [Cordis-OxCaml] Port busy or already running. -ForegroundColor Yellow
    exit 0
}

 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

while (.IsListening) {
    try {
         = .GetContext()
         = .Request
         = .Response
         = .Url.AbsolutePath

        if ( -eq /events -or  -eq /_cordis_live) {
            .ContentType = text/event-stream
            .Headers.Add(Cache-Control, no-cache, no-transform)
            .Headers.Add(Access-Control-Allow-Origin, *)
            .SendChunked = True
            
             = .OutputStream
             = [System.Text.Encoding]::UTF8.GetBytes(data: {type:connected,version:,status:active}

)
            .Write(, 0, .Length)
            .Flush()
            
            # Send live ticks
            for ( = 1;  -le 10; ++) {
                Start-Sleep -Milliseconds 1500
                 = [System.Text.Encoding]::UTF8.GetBytes(data: {type:tick,tick:,ast_state:stable,memory_slots:500}

)
                .Write(, 0, .Length)
                .Flush()
            }
            .Close()
        }
        elseif ( -eq /api/status -or  -eq /_cordis_sync) {
            .ContentType = application/json
            .Headers.Add(Access-Control-Allow-Origin, *)
             = '{status:ok,engine:Cordis-OxCaml,formal_layer:Cubical-Agda/Rzk,poly:active,version:' +  + '}'
             = [System.Text.Encoding]::UTF8.GetBytes()
            .ContentLength64 = .Length
            .OutputStream.Write(, 0, .Length)
            .Close()
        }
        else {
             = Join-Path  index.html
            if (Test-Path ) {
                 = [System.IO.File]::ReadAllBytes()
                .ContentType = text/html; charset=utf-8
                .Headers.Add(Access-Control-Allow-Origin, *)
                .ContentLength64 = .Length
                .OutputStream.Write(, 0, .Length)
            } else {
                .StatusCode = 404
            }
            .Close()
        }
    } catch {
        # Client disconnect or stream complete
    }
}
