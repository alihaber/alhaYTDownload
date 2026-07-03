# Alha YouTube Downloader - Otomatik Kurulum
# Admin yetkisi GEREKMEZ (HKCU + AppData kullanilir)

param(
    [switch]$Silent
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'
$EXTENSION_ID = 'gnfdbpoiocdehodkgfgckmhcibpaoobk'
$HOST_NAME    = 'com.alha.ytube.download.host'

function Log($msg, $color = 'White') { Write-Host $msg -ForegroundColor $color }

Log '================================================' 'Cyan'
Log '  Alha YouTube Downloader - Otomatik Kurulum   ' 'Cyan'
Log '================================================' 'Cyan'
Log ''

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallPath  = "$env:LOCALAPPDATA\Alha\YoutubeDownloader"

# ─── 1. Kaynak dosya kontrolu ─────────────────────────────────────────────
Log '1. Dosyalar kontrol ediliyor...' 'Yellow'

function Download-Dependency($url, $dest) {
    Log ("   [..] " + (Split-Path -Leaf $dest) + " bulunamadi, internetten indiriliyor...") 'Yellow'
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $webClient.DownloadFile($url, $dest)
        Log ("   [OK] " + (Split-Path -Leaf $dest) + " basariyla indirildi.") 'Green'
    }
    catch {
        Log ("   [!] Bağımlılık indirilemedi: " + $_.Exception.Message) 'Red'
    }
}

$hostSrc = @(
    "$ScriptDir\alha-ytdlp-host.exe",
    "$ScriptDir\NativeHost.exe",
    "$ScriptDir\native_host\bin\alha-ytdlp-host.exe",
    "$ScriptDir\native_host\NativeHost.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

$extSrc = @(
    "$ScriptDir\chrome_extension",
    "$ScriptDir\..\chrome_extension"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $hostSrc -or -not (Test-Path $hostSrc) -or -not $extSrc -or -not (Test-Path $extSrc)) {
    Log "HATA: Kritik eklenti veya host dosyalari bulunamadi! Kurulum tamamlanamiyor." 'Red'
    if (-not $Silent) { Read-Host 'Kapatmak icin Enter a basin' }
    exit 1
}

# Bağımlılıkları kontrol et ve gerekirse indir
$ytdlpSrc = @(
    "$ScriptDir\yt-dlp.exe",
    "$ScriptDir\native_host\yt-dlp.exe",
    "$InstallPath\yt-dlp.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $ytdlpSrc) {
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    $ytdlpSrc = "$InstallPath\yt-dlp.exe"
    Download-Dependency "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" $ytdlpSrc
}

$ffmpegSrc = @(
    "$ScriptDir\ffmpeg.exe",
    "$ScriptDir\native_host\ffmpeg.exe",
    "$InstallPath\ffmpeg.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $ffmpegSrc) {
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    $ffmpegSrc = "$InstallPath\ffmpeg.exe"
    Download-Dependency "https://github.com/alihaber/alhaYTDownload/releases/download/v1.0.9/ffmpeg.exe" $ffmpegSrc
}

if (-not (Test-Path $ytdlpSrc) -or -not (Test-Path $ffmpegSrc)) {
    Log "   [!] UYARI: Bağımlılıklar eksik veya indirilemedi. İnternet bağlantınızı kontrol edin." 'Yellow'
} else {
    Log '   [OK] Tum dosyalar ve bagimliliklar kontrol edildi.' 'Green'
}

# ─── 2. Motor dosyalarini kopyala ─────────────────────────────────────────
Log '2. Motor dosyalari kopyalaniyor...' 'Yellow'
Stop-Process -Name 'alha-ytdlp-host' -Force -ErrorAction SilentlyContinue
Stop-Process -Name 'NativeHost' -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null

function Safe-Copy($src, $dest) {
    if ($src -and (Test-Path $src)) {
        $srcFull = (Get-Item $src).FullName
        $destFull = $null
        if (Test-Path $dest) { $destFull = (Get-Item $dest).FullName }
        if ($srcFull -ne $destFull) {
            Copy-Item $src $dest -Force
        }
    }
}

Safe-Copy $hostSrc   "$InstallPath\alha-ytdlp-host.exe"
Safe-Copy $ytdlpSrc  "$InstallPath\yt-dlp.exe"
Safe-Copy $ffmpegSrc "$InstallPath\ffmpeg.exe"
Log '   [OK] Motor dosyalari kopyalandi.' 'Green'

# ─── 3. Eklenti dosyalarini kopyala ──────────────────────────────────────
Log '3. Eklenti dosyalari hazirlanıyor...' 'Yellow'
$ExtInstallPath = "$InstallPath\extension"
if ((Get-Item $extSrc).FullName -ne (Get-Item $ExtInstallPath -ErrorAction SilentlyContinue).FullName) {
    if (Test-Path $ExtInstallPath) { Remove-Item $ExtInstallPath -Recurse -Force }
    Copy-Item $extSrc $ExtInstallPath -Recurse -Force
}
Log '   [OK] Eklenti dosyalari kopyalandi.' 'Green'

# ─── 4. Native Messaging Host (HKCU - admin gerekmez) ────────────────────
Log '4. Native messaging ayarlaniyor...' 'Yellow'
$hostExe = "$InstallPath\alha-ytdlp-host.exe"
$manifestContent = ('{' + [char]10 +
  '  "name": "' + $HOST_NAME + '",' + [char]10 +
  '  "description": "Alha YouTube Downloader Native Messaging Host",' + [char]10 +
  '  "path": "' + $hostExe.Replace('\','\\') + '",' + [char]10 +
  '  "type": "stdio",' + [char]10 +
  '  "allowed_origins": [' + [char]10 +
  '    "chrome-extension://' + $EXTENSION_ID + '/"' + [char]10 +
  '  ]' + [char]10 + '}')

$manifestJsonPath = "$InstallPath\$HOST_NAME.json"
Set-Content -Path $manifestJsonPath -Value $manifestContent -Encoding UTF8

foreach ($regBase in @(
    'HKCU:\Software\Google\Chrome\NativeMessagingHosts',
    'HKCU:\Software\Microsoft\Edge\NativeMessagingHosts',
    'HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts'
)) {
    $rp = "$regBase\$HOST_NAME"
    New-Item $rp -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty $rp '(Default)' $manifestJsonPath
}
Log '   [OK] Native messaging ve registry ayarlandi (Chrome + Edge + Brave).' 'Green'

# ─── 5. Chrome'u bul ─────────────────────────────────────────────────────
Log '5. Tarayici aranıyor...' 'Yellow'

$chromeExe = @(
    "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe",
    "${env:PROGRAMFILES(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$edgeExe = @(
    "$env:PROGRAMFILES\Microsoft\Edge\Application\msedge.exe",
    "${env:PROGRAMFILES(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($chromeExe) { Log ('   [OK] Chrome bulundu: ' + $chromeExe) 'Green' }
if ($edgeExe)   { Log ('   [OK] Edge bulundu: '   + $edgeExe)   'Green' }
if (-not $chromeExe -and -not $edgeExe) {
    Log '   [!] Chrome veya Edge bulunamadi.' 'Yellow'
}

# ─── 6. Acik tarayicilari nazikce kapat ──────────────────────────────────
Log '6. Acik tarayicilar kapatiliyor...' 'Yellow'

function Close-Browser([string]$procName) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if (-not $procs) { return }
    $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    $deadline = (Get-Date).AddSeconds(6)
    while ((Get-Process -Name $procName -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
    }
    Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

if ($chromeExe) { Close-Browser 'chrome'  }
if ($edgeExe)   { Close-Browser 'msedge'  }
Log '   [OK] Tarayicilar kapatildi.' 'Green'

# ─── 7. --load-extension ile tarayiciyi ac ───────────────────────────────
Log '7. Eklenti yukleniyor...' 'Yellow'

$launched = $false
$loadArg  = '--load-extension=' + $ExtInstallPath

if ($chromeExe) {
    Log '   Chrome baslatiliyor ve eklenti yukleniyor...' 'Gray'
    Start-Process -FilePath $chromeExe -ArgumentList $loadArg, '--no-first-run', '--restore-last-session'
    $launched = $true
}
elseif ($edgeExe) {
    Log '   Edge baslatiliyor ve eklenti yukleniyor...' 'Gray'
    Start-Process -FilePath $edgeExe -ArgumentList $loadArg, '--no-first-run', '--restore-last-session'
    $launched = $true
}

if ($launched) {
    Start-Sleep -Seconds 3
    Log '   [OK] Tarayici baslatildi ve eklenti yuklendi.' 'Green'
}

# ─── Tamamlandi ───────────────────────────────────────────────────────────
Log ''
Log '================================================' 'Green'
Log '   KURULUM TAMAMLANDI!                          ' 'Green'
Log '================================================' 'Green'
Log ''
if ($launched) {
    Log '  Tarayici acildi. Eklenti listesinde gorununce hazirsiniz.' 'White'
    Log '  YouTube.com a gidin, indirme butonlari aktif olacak!' 'Cyan'
}
else {
    Log '  Tarayici bulunamadi. Tarayicinizi kendiniz acin.' 'Yellow'
    Log '  chrome://extensions adresinden "Paketlenmemis ogeyi yukle"' 'White'
    Log ('  butonuyla su klasoru secin: ' + $ExtInstallPath) 'Cyan'
}
Log ''
if (-not $Silent) {
    Read-Host 'Kapatmak icin Enter a basin'
}
