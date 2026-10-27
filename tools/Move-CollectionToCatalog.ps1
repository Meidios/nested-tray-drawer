<#
.SYNOPSIS
Validate collection transfer, or prepare a fresh catalog installation, using Windhawk's public API.
.DESCRIPTION
Run from an elevated PowerShell under the same Windows user as Explorer. Validate is the default:
temporarily pause the local mod, export through its own API, import/read back under a disposable
ID, erase the test contents, and restore the original configuration. No Explorer restart.
PrepareCatalog seeds only a not-yet-installed catalog ID, refuses conflicting existing storage,
and leaves the local mod disabled on success. Install/enable the catalog mod immediately afterward.
Never uninstall the temporary catalog configuration: only its configuration key is removed,
leaving the API-owned collection for the normal catalog installation.
#>
param([ValidateSet('Validate','PrepareCatalog')][string]$Mode='Validate')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$sourceId='local@nested-tray-drawer'
$targetId=if($Mode -eq 'Validate'){'local@ntd-transfer-test-'+[guid]::NewGuid().ToString('N')}else{'nested-tray-drawer'}
$mods='HKLM:\SOFTWARE\Windhawk\Engine\Mods'
$sourceKey=Join-Path $mods $sourceId
$targetKey=Join-Path $mods $targetId
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){throw 'Run this script as administrator under the same Windows user as Explorer.'}
$sourceConfig=Get-ItemProperty -LiteralPath $sourceKey
if($sourceConfig.Include -ne 'explorer.exe' -or $sourceConfig.LibraryFileName -notmatch '^local@nested-tray-drawer_0\.1\.[0-9]+_[0-9a-f]{12}\.dll$'){
    throw 'Unexpected local configuration; no changes made.'
}
if(Test-Path -LiteralPath $targetKey){throw 'Destination is already installed; no changes made. Resolve the existing installation first.'}
$hostName='ntd-collection-transfer-host'
if(Get-Process -Name $hostName -ErrorAction SilentlyContinue){throw 'A transfer host is already running.'}
$run=Join-Path $root ('build/collection-transfer/'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$handoff=Join-Path $run 'collection.dpapi'
$changed=@('LibraryFileName','Include','Exclude','IncludeCustom','ExcludeCustom','IncludeExcludeCustomOnly','Architecture','Version','LoggingEnabled','Disabled')
$registry=Get-Item -LiteralPath $sourceKey
$original=@{}
foreach($name in $changed){
    $exists=$registry.GetValueNames() -contains $name
    $original[$name]=@{Exists=$exists;Value=if($exists){$registry.GetValue($name)}else{$null};Kind=if($exists){$registry.GetValueKind($name).ToString()}else{$null}}
}
$original | Export-Clixml -LiteralPath (Join-Path $run 'original-configuration.xml')
$sourceBuild=& (Join-Path $PSScriptRoot 'Build-CollectionTransfer.ps1') -ModId $sourceId
$targetBuild=& (Join-Path $PSScriptRoot 'Build-CollectionTransfer.ps1') -ModId $targetId
$targetCreated=$false;$sourceChanged=$false;$verified=$false;$testCleared=$false
$summary=[ordered]@{Success=$false;Mode=$Mode;Entries=0;ExactMatch=$false;TestCopyCleared=$false;SourceConfigurationRestored=$false;SourceEnabled=$false;ExplorerRestarted=$false}
function Wait-LibraryAbsent([string]$fileName){
    for($i=0;$i -lt 150;$i++){
        $loaded=$false
        foreach($process in @(Get-Process -Name explorer -ErrorAction SilentlyContinue)){
            foreach($module in $process.Modules){if($module.ModuleName -eq $fileName){$loaded=$true;break}}
        }
        if(-not $loaded){return};Start-Sleep -Milliseconds 200
    }
    throw 'The local mod has not unloaded; configuration restoration is required.'
}
function Configure-Helper([string]$key,[string]$id,$built){
    $hash=(Get-FileHash -LiteralPath $built.Dll -Algorithm SHA256).Hash.ToLowerInvariant()
    $name=$id+'_0.0.1_'+$hash.Substring(0,12)+'.dll'
    $installed=Join-Path 'C:\ProgramData\Windhawk\Engine\Mods\64' $name
    if(Test-Path -LiteralPath $installed){
        if((Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash){throw 'Helper DLL mismatch.'}
    }else{Copy-Item -LiteralPath $built.Dll -Destination $installed}
    $item=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($key.Substring(6),$true)
    $item.SetValue('Disabled',1,[Microsoft.Win32.RegistryValueKind]::DWord)
    foreach($entry in @{LibraryFileName=$name;Include=($hostName+'.exe');Exclude='';IncludeCustom='';ExcludeCustom='';Architecture='amd64';Version='0.0.1'}.GetEnumerator()){
        $item.SetValue($entry.Key,$entry.Value,[Microsoft.Win32.RegistryValueKind]::String)
    }
    $item.SetValue('IncludeExcludeCustomOnly',0,[Microsoft.Win32.RegistryValueKind]::DWord)
    $item.SetValue('LoggingEnabled',0,[Microsoft.Win32.RegistryValueKind]::DWord)
    $item.SetValue('Disabled',0,[Microsoft.Win32.RegistryValueKind]::DWord)
    $item.Close()
}
function Run-Host([string]$operation,[string]$resultName){
    $result=Join-Path $run $resultName
    $arguments='"'+$operation+'" "'+$handoff+'" "'+$result+'"'
    $process=Start-Process -FilePath $sourceBuild.Host -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if(-not $process.WaitForExit(50000)){
        if((Get-Process -Id $process.Id).Path -eq $sourceBuild.Host){Stop-Process -Id $process.Id}
        throw 'Transfer helper timed out.'
    }
    if($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $result)){throw 'Windhawk did not complete the API helper.'}
    $value=Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
    if(-not $value.success){throw ('Transfer refused: '+$value.status)}
    return $value
}
try {
    $sourceChanged=$true
    Set-ItemProperty -LiteralPath $sourceKey -Name Disabled -Value 1
    Wait-LibraryAbsent $sourceConfig.LibraryFileName
    Configure-Helper $sourceKey $sourceId $sourceBuild
    $export=Run-Host 'export' 'export.json'
    # The host has exited before any configuration swap. The source record was read only.
    Set-ItemProperty -LiteralPath $sourceKey -Name Disabled -Value 1
    New-Item -Path $targetKey | Out-Null;$targetCreated=$true
    Configure-Helper $targetKey $targetId $targetBuild
    $import=Run-Host 'import' 'import.json'
    if($export.sha256 -ne $import.sha256 -or $export.entries -ne $import.entries){throw 'Collection verification mismatch.'}
    $summary.Entries=$export.entries;$summary.ExactMatch=$true
    if($Mode -eq 'Validate'){
        Run-Host 'clear-test' 'cleanup.json' | Out-Null
        $testCleared=$true;$summary.TestCopyCleared=$true
    }
    $verified=$true
} finally {
    try { if($targetCreated){
        # Only the key created above may be removed. API storage is never deleted here.
        if($targetKey -ne (Join-Path $mods $targetId) -or $targetId -notmatch '^(nested-tray-drawer|local@ntd-transfer-test-[a-f0-9]{32})$'){throw 'Unsafe temporary configuration cleanup.'}
        Set-ItemProperty -LiteralPath $targetKey -Name Disabled -Value 1
        if($Mode -eq 'Validate' -and -not $testCleared){
            try {Set-ItemProperty -LiteralPath $targetKey -Name Disabled -Value 0;Run-Host 'clear-test' 'cleanup-retry.json' | Out-Null;$summary.TestCopyCleared=$true}
            finally {Set-ItemProperty -LiteralPath $targetKey -Name Disabled -Value 1}
        }
        Remove-Item -LiteralPath $targetKey -Recurse
    } } finally {
    if($sourceChanged){
        $item=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($sourceKey.Substring(6),$true)
        $item.SetValue('Disabled',1,[Microsoft.Win32.RegistryValueKind]::DWord)
        foreach($name in $changed | Where-Object {$_ -ne 'Disabled'}){
            $saved=$original[$name]
            if($saved.Exists){$item.SetValue($name,$saved.Value,[Microsoft.Win32.RegistryValueKind]$saved.Kind)}
            else{$item.DeleteValue($name,$false)}
        }
        $disabled=if($verified -and $Mode -eq 'PrepareCatalog'){1}else{[int]$original.Disabled.Value}
        $item.SetValue('Disabled',$disabled,[Microsoft.Win32.RegistryValueKind]::DWord)
        foreach($name in $changed | Where-Object {$_ -ne 'Disabled'}){
            $saved=$original[$name]
            if(($item.GetValueNames() -contains $name) -ne $saved.Exists -or ($saved.Exists -and $item.GetValue($name) -ne $saved.Value)){throw 'Original configuration verification failed.'}
        }
        $summary.SourceConfigurationRestored=$true;$summary.SourceEnabled=($disabled -eq 0)
        $item.Close()
    }
    $summary.Success=$verified -and $summary.SourceConfigurationRestored -and ($Mode -ne 'Validate' -or $summary.TestCopyCleared)
    $summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'summary.json') -Encoding utf8
    # No record text or app identifiers are emitted. The encrypted backup remains private.
    $summary | ConvertTo-Json
    }
}
