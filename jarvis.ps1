# J.A.R.V.I.S. — unattended launcher.
#
# Starts the brain and the interface, then opens the interface in a Chrome
# window placed off the edge of the desktop. Nothing is visible; you just talk.
#
# Why a real window and not headless Chrome: headless has no audio devices, so
# there would be no microphone to listen with and no speakers to answer through.
# The window has to exist — it just doesn't have to be somewhere you can see it.

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

# node and npm were added to the machine PATH after this shell's parent started,
# so read the PATH from the registry rather than trusting what we inherited.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# Private keys, kept out of git. Parsed rather than run: that file is a .cmd so
# the visible launcher can call it too, and this is PowerShell.
$secrets = Join-Path $repo 'jarvis-secrets.cmd'
if (Test-Path $secrets) {
  foreach ($line in Get-Content $secrets) {
    if ($line -match '^\s*set\s+"([^=]+)=(.*)"\s*$' -and $matches[2]) {
      Set-Item -Path ("env:" + $matches[1]) -Value $matches[2]
    }
  }
}
# A default, not an assignment. The secrets file above may already have set
# this, and that choice should survive.
if (-not $env:JARVIS_VOICE_ID) { $env:JARVIS_VOICE_ID = 'IRHApOXLvnW57QJPQH2P' }

# ---------------------------------------------------------------------------
# The brain and the interface
# ---------------------------------------------------------------------------

$running = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
           Where-Object { $_.LocalPort -eq 8787 }
if (-not $running) {
  Start-Process -FilePath 'node' -ArgumentList 'scripts/start.mjs', '--writes' `
                -WorkingDirectory $repo -WindowStyle Hidden | Out-Null
}

# Wait for the page to actually be served. Pointing a browser at a dev server
# that has not finished starting gives a connection error, and in a window you
# cannot see, that is an assistant that is simply silent for ever.
$ready = $false
for ($i = 0; $i -lt 120; $i++) {
  try {
    if ((Invoke-WebRequest 'http://localhost:5173' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200) {
      $ready = $true
      break
    }
  } catch {
    Start-Sleep -Milliseconds 500
  }
}
if (-not $ready) { exit 1 }

# ---------------------------------------------------------------------------
# A Chrome profile of its own
# ---------------------------------------------------------------------------
#
# Separate from the browser you use, for two reasons. The microphone permission
# is granted here once and permanently, which matters because nobody can click
# "Allow" on a window they cannot see — and the camera is denied in the same
# breath, because a webcam that can be switched on inside an invisible window is
# not a trade worth making. The eyes still work in the visible launcher.

$profileDir = Join-Path $env:LOCALAPPDATA 'JarvisApp'
$prefsPath = Join-Path $profileDir 'Default\Preferences'
if (-not (Test-Path $prefsPath)) {
  New-Item -ItemType Directory -Force -Path (Split-Path $prefsPath) | Out-Null
  $prefs = @{
    profile = @{
      content_settings = @{
        exceptions = @{
          media_stream_mic    = @{ 'http://localhost:5173,*' = @{ setting = 1 } }
          media_stream_camera = @{ 'http://localhost:5173,*' = @{ setting = 2 } }
          notifications       = @{ 'http://localhost:5173,*' = @{ setting = 2 } }
        }
      }
    }
  }
  $prefs | ConvertTo-Json -Depth 9 | Set-Content -Path $prefsPath -Encoding utf8
}

$chrome = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { exit 1 }

# --disable-features=CalculateNativeWinOcclusion is the load-bearing flag.
# Chrome marks a window it believes is covered or off-screen as hidden, and a
# hidden page gets its timers throttled and its animation frames stopped — which
# for this app means the wake word stops being heard. Turning the occlusion
# check off keeps the page fully live while it sits off the edge of the desktop.
#
# The quotes around the profile path are load-bearing. Start-Process joins these
# with spaces and quotes nothing, and this path contains a space — without them
# Chrome reads the argument as far as "C:\Users\ALI", takes the rest as a URL to
# open, and the window never appears at all.
$args = @(
  '--app=http://localhost:5173/?auto=1'
  "--user-data-dir=`"$profileDir`""
  '--window-position=-32000,-32000'
  '--window-size=1280,800'
  '--disable-features=CalculateNativeWinOcclusion'
  '--autoplay-policy=no-user-gesture-required'
  '--no-first-run'
  '--no-default-browser-check'
  '--disable-session-crashed-bubble'
)
Start-Process -FilePath $chrome -ArgumentList $args | Out-Null

# Chrome sometimes drags a window back onto a monitor despite the flag above, so
# put it where it belongs once it exists. Off-screen rather than minimised:
# minimised is hidden, and hidden is throttled.
Add-Type -Namespace Win -Name Api -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
'@
for ($i = 0; $i -lt 40; $i++) {
  $win = Get-Process chrome -ErrorAction SilentlyContinue |
         Where-Object { $_.MainWindowTitle -like '*J.A.R.V.I.S*' } |
         Select-Object -First 1
  if ($win) {
    [Win.Api]::MoveWindow($win.MainWindowHandle, -32000, -32000, 1280, 800, $true) | Out-Null
    break
  }
  Start-Sleep -Milliseconds 500
}
