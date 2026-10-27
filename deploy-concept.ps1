# Dahlia Feeling App - Concept Page Deploy to SiteGround
# Uploads index.html to https://understandingit.biz/feeling-app/
#
# Usage:
#   .\deploy-concept.ps1           # SFTP mode (auto-detected)
#   .\deploy-concept.ps1 -UseFtp  # force FTPS/curl fallback

param(
    [string]$FtpHost   = "gcam1270.siteground.biz",
    [int]$FtpPort      = 21,
    [int]$SshPort      = 18765,
    [string]$FtpUser   = "adm_jcf@understandingit.biz",
    [string]$RemoteDir = "/understandingit.biz/public_html/feeling-app",
    [switch]$UseFtp
)

$LocalFile  = Join-Path $PSScriptRoot "index.html"
$RemotePath = $RemoteDir + "/index.html"

if (-not (Test-Path $LocalFile)) {
    Write-Host "ERROR: index.html not found at $LocalFile" -ForegroundColor Red
    exit 1
}

# Credentials
$SecurePass = Read-Host "SiteGround FTP/SSH password" -AsSecureString
$PlainPass  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
)

# Mode detection (PS 5-compatible null check)
$sftpCmd = Get-Command sftp.exe -ErrorAction SilentlyContinue
$useSftp = ($null -ne $sftpCmd) -and (-not $UseFtp)

Write-Host ""
Write-Host "Deploying Feeling App concept page to SiteGround..." -ForegroundColor Cyan
if ($useSftp) {
    Write-Host "Mode   : SFTP (SSH port $SshPort)"
} else {
    Write-Host "Mode   : FTPS/curl (port $FtpPort)"
}
Write-Host "Remote : $RemotePath"
Write-Host ""

# SFTP upload
if ($useSftp) {
    $batchFile = Join-Path $env:TEMP ("dahlia_concept_sftp_" + [System.IO.Path]::GetRandomFileName() + ".txt")
    $line1 = "put `"$LocalFile`" `"$RemotePath`""
    $line2 = "bye"
    @($line1, $line2) | Set-Content $batchFile -Encoding ASCII

    Write-Host "  Uploading index.html via SFTP..."
    & sftp.exe -b $batchFile -P $SshPort -o "StrictHostKeyChecking=no" "${FtpUser}@${FtpHost}"
    $exitCode = $LASTEXITCODE
    Remove-Item $batchFile -Force -ErrorAction SilentlyContinue

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "Done!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Live at: https://understandingit.biz/feeling-app/" -ForegroundColor Cyan
        Write-Host "No WordPress cache to flush for a static page - just visit the URL."
    } else {
        Write-Host "SFTP failed (exit $exitCode)." -ForegroundColor Red
        Write-Host "Try the FTP fallback: .\deploy-concept.ps1 -UseFtp" -ForegroundColor Yellow
        exit 1
    }
    exit 0
}

# FTPS fallback via curl
$uri = "ftp://${FtpHost}:${FtpPort}${RemotePath}"
Write-Host "  Uploading index.html via FTPS..." -NoNewline

$result = & curl.exe --ssl-reqd --insecure --ftp-pasv --ftp-create-dirs `
    --retry 4 --retry-delay 6 -s -S `
    -u "${FtpUser}:$PlainPass" -T $LocalFile $uri 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host " OK" -ForegroundColor Green
    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green
    Write-Host "Live at: https://understandingit.biz/feeling-app/" -ForegroundColor Cyan
} else {
    Write-Host " FAILED: $result" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try uploading manually via SiteGround File Manager (cPanel):" -ForegroundColor Yellow
    Write-Host "  Path: /public_html/feeling-app/index.html"
    exit 1
}
