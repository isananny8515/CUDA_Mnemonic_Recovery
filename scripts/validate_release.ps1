param(
    [string]$Exe = "",
    [string]$Device = "",
    [string]$MultiDevice = "",
    [switch]$SkipExperimental
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Exe) {
    $Exe = if ($env:CMR_EXE) { $env:CMR_EXE } else { Join-Path $RepoRoot "out\build\windows-release\bin\Release\CUDA_Mnemonic_Recovery.exe" }
}
if (-not $Device) {
    $Device = if ($env:CMR_DEVICE) { $env:CMR_DEVICE } else { "0" }
}
if (-not $MultiDevice) {
    $MultiDevice = if ($env:CMR_MULTI_DEVICE) { $env:CMR_MULTI_DEVICE } else { "" }
}

if (-not (Test-Path $Exe)) {
    throw "Executable not found: $Exe"
}

$phraseExact = "adapt access alert human kiwi rough pottery level soon funny burst divorce"
$phraseOneMissing = "adapt access alert human kiwi rough pottery level soon funny burst *"
$hashCompressed = "1a4603d1ff9121515d02a6fee37c20829ca522b0"
$hashPass = "1e398598f50849236bc8a077b184fbce0aa74f4e"
$hashSolanaD1 = "553ff1f4f34d1c013fd885073a0b6b82f02bb3d0"
$hashSolanaD2 = "89dfcdfe8986448bf0ca1f5bc1720de5ad66104c"
$hashD4 = "4fd01a8da7097495668c9ee9499084bc5680199a"

$templatesFile = "examples/validation/templates-file.txt"
$templateTypo = "examples/validation/template-typo.txt"
$derivationsDefault = "examples/derivations/default.txt"
$derivationsSecp = "examples/validation/derivations-secp.txt"
$derivationsSolana = "examples/validation/derivations-solana.txt"

$ValidationOutDir = Join-Path $RepoRoot "out\validation-run"
New-Item -ItemType Directory -Force -Path $ValidationOutDir | Out-Null

function Invoke-Case {
    param(
        [string]$Name,
        [string[]]$ArgumentList,
        [string[]]$Patterns
    )

    Write-Host "[case] $Name" -ForegroundColor Cyan
    $previousErrorPreference = $ErrorActionPreference
    $previousNativePreference = $null
    if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }
    try {
        $ErrorActionPreference = "Continue"
        $output = & $Exe @ArgumentList 2>&1 | ForEach-Object { "$_" } | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorPreference
        if ($null -ne $previousNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
    if ($exitCode -ne 0) {
        throw "Case '$Name' failed with exit code $exitCode.`n$output"
    }
    foreach ($pattern in $Patterns) {
        if ($output -notmatch $pattern) {
            throw "Case '$Name' did not match required pattern '$pattern'.`n$output"
        }
    }
    Write-Host "[ok] $Name" -ForegroundColor Green
    return $output
}

function Get-FoundCount {
    param([string]$Output)
    $m = [regex]::Match($Output, "Found:\s+(\d+)")
    if (-not $m.Success) {
        throw "Could not extract Found count from output.`n$Output"
    }
    return [int]$m.Groups[1].Value
}

Push-Location $RepoRoot
try {
    Invoke-Case -Name "help" -ArgumentList @("-help") -Patterns @("-d_type 1\|2\|3\|4")

    Invoke-Case -Name "inline exact hash" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseOneMissing,
        "-d", $derivationsDefault,
        "-c", "c",
        "-hash", $hashCompressed,
        "-silent"
    ) -Patterns @("Found:\s+1")

    $singleFileOutput = Invoke-Case -Name "file exact hash" -ArgumentList @(
        "-device", $Device,
        "-recovery", "-i", $templatesFile,
        "-d", $derivationsDefault,
        "-c", "c",
        "-hash", $hashCompressed,
        "-silent"
    ) -Patterns @("Found:\s+1")

    Invoke-Case -Name "typo correction" -ArgumentList @(
        "-device", $Device,
        "-recovery", "-i", $templateTypo,
        "-d", $derivationsSecp,
        "-c", "c",
        "-hash", $hashCompressed
    ) -Patterns @("Recovery replace: 'acces' -> 'access'", "Found:\s+1")

    Invoke-Case -Name "passphrase exact hash" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseExact,
        "-d", $derivationsSecp,
        "-c", "c",
        "-pass", "TREZOR",
        "-hash", $hashPass,
        "-silent"
    ) -Patterns @("Found:\s+1")

    $saveFile = Join-Path $ValidationOutDir "save-output.txt"
    if (Test-Path $saveFile) { Remove-Item $saveFile -Force }
    Invoke-Case -Name "save output" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseOneMissing,
        "-d", $derivationsDefault,
        "-c", "c",
        "-hash", $hashCompressed,
        "-save",
        "-o", $saveFile,
        "-silent"
    ) -Patterns @("Found:\s+1")
    if (-not (Test-Path $saveFile)) {
        throw "Save output file was not created: $saveFile"
    }
    $saveContent = Get-Content $saveFile | Out-String
    if ($saveContent -notmatch "\[!\]\s+Found:") {
        throw "Save output file does not contain Found lines.`n$saveContent"
    }
    if ($saveContent -match [regex]::Escape($hashCompressed)) {
        throw "Save output still contains the raw exact hash instead of address-oriented output.`n$saveContent"
    }
    Write-Host "[ok] save output content" -ForegroundColor Green

    Invoke-Case -Name "d_type 1 solana" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseExact,
        "-d", $derivationsSolana,
        "-c", "S",
        "-d_type", "1",
        "-hash", $hashSolanaD1,
        "-silent"
    ) -Patterns @("Found:\s+1")

    Invoke-Case -Name "d_type 2 solana" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseExact,
        "-d", $derivationsSolana,
        "-c", "S",
        "-hash", $hashSolanaD2,
        "-silent"
    ) -Patterns @("Found:\s+1")

    Invoke-Case -Name "d_type 3 mixed marker" -ArgumentList @(
        "-device", $Device,
        "-recovery", $phraseExact,
        "-d", $derivationsSolana,
        "-c", "S",
        "-d_type", "3",
        "-hash", $hashSolanaD1
    ) -Patterns @("\(bip32-secp256k1\)", "Found:\s+1")

    if (-not $SkipExperimental) {
        Invoke-Case -Name "d_type 4 experimental" -ArgumentList @(
            "-device", $Device,
            "-recovery", $phraseExact,
            "-d", $derivationsSecp,
            "-c", "c",
            "-d_type", "4",
            "-hash", $hashD4
        ) -Patterns @("\(ed25519-bip32-test\)", "Found:\s+1")
    }

    if ($MultiDevice) {
        $multiOutput = Invoke-Case -Name "multi-GPU parity" -ArgumentList @(
            "-device", $MultiDevice,
            "-recovery", "-i", $templatesFile,
            "-d", $derivationsDefault,
            "-c", "c",
            "-hash", $hashCompressed,
            "-silent"
        ) -Patterns @("Found:\s+1")

        $singleFound = Get-FoundCount $singleFileOutput
        $multiFound = Get-FoundCount $multiOutput
        if ($singleFound -ne $multiFound) {
            throw "Single-GPU and multi-GPU Found counts differ: $singleFound vs $multiFound"
        }
        Write-Host "[ok] multi-GPU parity" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Validation suite completed successfully." -ForegroundColor Green
}
finally {
    Pop-Location
}
