# Compatibility entry point for the current API-backed migration tests.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Test-WindhawkStorage.ps1')
