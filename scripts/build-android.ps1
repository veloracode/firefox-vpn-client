# Builds the Android app with its core into dist\Arman-VPN-<version>-android\:
# one APK per ABI (arm64-v8a, armeabi-v7a, x86_64). It first binds the Go
# core into app\android\app\libs\core.aar with gomobile, then builds the
# Flutter app. The version is "major.minor.patch" from app\pubspec.yaml, passed
# to the app (APP_VERSION) and to the core (version.Current).
#
# Needs Go, Flutter, the Android SDK with the NDK named in
# app\android\app\build.gradle.kts, a JDK (JAVA_HOME, else Android
# Studio's), and gomobile and gobind at the x/mobile commit given in
# core\doc\DEVELOPMENT.md.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$match = Select-String -Path "$root\app\pubspec.yaml" -Pattern '^version:\s*(\d+\.\d+\.\d+)'
if (-not $match) { throw 'No version in app\pubspec.yaml' }
$version = $match.Matches[0].Groups[1].Value
$out = "$root\dist\Arman-VPN-$version-android"

if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk" }
$ndk = (Select-String -Path "$root\app\android\app\build.gradle.kts" -Pattern 'ndkVersion\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
if (-not $env:ANDROID_NDK_HOME) { $env:ANDROID_NDK_HOME = "$env:ANDROID_HOME\ndk\$ndk" }
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = "$env:ProgramFiles\Android\Android Studio\jbr" }

# Gradle reads no HTTP_PROXY/HTTPS_PROXY: it only honours the JVM's own
# system properties. Hand it the proxy the rest of the machine already uses,
# so a build downloads the way every other tool here does. Without those
# variables nothing is added and Gradle connects directly, as before.
$proxy = if ($env:HTTPS_PROXY) { $env:HTTPS_PROXY } else { $env:HTTP_PROXY }
if ($proxy) {
    try {
        $u = [uri]$proxy
        $port = if ($u.Port -gt 0) { $u.Port } else { 8080 }
        $opts = "-Dhttp.proxyHost=$($u.Host) -Dhttp.proxyPort=$port" +
                " -Dhttps.proxyHost=$($u.Host) -Dhttps.proxyPort=$port"
        $env:GRADLE_OPTS = if ($env:GRADLE_OPTS) { "$env:GRADLE_OPTS $opts" } else { $opts }
        Write-Host "Gradle will use the proxy $($u.Host):$port"
    } catch {
        Write-Warning "HTTPS_PROXY/HTTP_PROXY is not an address Gradle can use: $proxy"
    }
}
$env:PATH = "$(go env GOPATH)\bin;$env:JAVA_HOME\bin;$env:PATH"
# gomobile tidies a module of its own, where a Go older than go.mod's would
# switch to the newest patch release and download it (proxy.golang.org
# refuses some countries): the installed Go when it is new enough, else
# go.mod's version.
if (-not $env:GOTOOLCHAIN) {
    $need = (Select-String -Path "$root\core\go.mod" -Pattern '^go\s+(\S+)').Matches[0].Groups[1].Value
    $env:GOTOOLCHAIN = 'local'
    $have = (go env GOVERSION) -replace '^go', ''
    if ([version]$have -lt [version]$need) { $env:GOTOOLCHAIN = "go$need+auto" }
}

$ldflags = "-s -w -X github.com/armanlife/arman-vpn-client/core/internal/version.Current=$version"

# Optional local build settings (scripts\build-local.ps1), for a machine
# that is set up to add its own. Without that file the ordinary library is
# built, which is what this repository's sources make on their own.
$local = @{ Tags = @(); Ldflags = ''; Module = ''; Dir = '' }
if (Test-Path "$PSScriptRoot\build-local.ps1") {
    $local = & "$PSScriptRoot\build-local.ps1"
}
$ldflags += $local.Ldflags

Push-Location "$root\core"
# gomobile builds from a temporary module of its own, so a workspace file
# cannot reach a local module the way a desktop build does: gomobile's
# generated package is not a workspace member. A replace, added for this
# build only and always taken out again, links it instead. go.mod and
# go.sum are restored in the finally below even if the build throws or is
# interrupted.
$goMod = "$root\core\go.mod"
$goSum = "$root\core\go.sum"
$keepMod = Get-Content $goMod -Raw
$keepSum = Get-Content $goSum -Raw
try {
    if ($local.Tags.Count -gt 0 -and $local.Dir) {
        # Both edits stay quoted: PowerShell otherwise splits the argument
        # at the @ and go mod edit reports "need path@version".
        go mod edit "-require=$($local.Module)@v0.0.0"
        go mod edit "-replace=$($local.Module)@v0.0.0=$($local.Dir)"
        $env:GOWORK = 'off'
        # gomobile runs go mod tidy, which must not look a replaced local
        # module up on the module proxy or the checksum database.
        $env:GOPRIVATE = $local.Module
        $env:GOFLAGS = '-mod=mod'
        gomobile bind -target=android -androidapi 24 -trimpath -tags ($local.Tags -join ',') `
            -ldflags $ldflags `
            -o ..\app\android\app\libs\core.aar ./mobile
    } else {
        gomobile bind -target=android -androidapi 24 -trimpath `
            -ldflags $ldflags `
            -o ..\app\android\app\libs\core.aar ./mobile
    }
    if ($LASTEXITCODE -ne 0) { throw 'gomobile bind failed' }
} finally {
    Set-Content -Path $goMod -Value $keepMod -NoNewline
    Set-Content -Path $goSum -Value $keepSum -NoNewline
    Remove-Item Env:\GOWORK -ErrorAction SilentlyContinue
    Remove-Item Env:\GOPRIVATE -ErrorAction SilentlyContinue
    Remove-Item Env:\GOFLAGS -ErrorAction SilentlyContinue
    Pop-Location
}

Push-Location "$root\app"
try {
    # The packages from the local cache when it has them; from pub.dev
    # otherwise (a new machine). pub.dev refuses some requests from some
    # countries (its security advisories), which an offline get avoids.
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { flutter pub get }
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    flutter build apk --release --no-pub --split-per-abi --dart-define=APP_VERSION=$version
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally { Pop-Location }

New-Item -ItemType Directory -Force $out | Out-Null
foreach ($apk in Get-ChildItem "$root\app\build\app\outputs\flutter-apk\app-*-release.apk") {
    $name = $apk.Name -replace '^app-', "Arman-VPN-$version-" -replace '-release', ''
    Copy-Item $apk.FullName (Join-Path $out $name) -Force
}
Get-ChildItem $out | ForEach-Object { Write-Host ("Built {0} ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) }
