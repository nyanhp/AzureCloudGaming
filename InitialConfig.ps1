configuration CloudGamingClient
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential]
        $Credential
    )

    Import-DscResource -ModuleName PackageManagement -ModuleVersion 1.3.1
    Import-DscResource -ModuleName PSDSCResources -ModuleVersion 2.10.0.0
    Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.6.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 8.6.0.0
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion 7.1.0.0



    Disk dataDisk
    {
        DiskId      = 2
        DriveLetter = 'L'
        #DependsOn   = '[Disk]tempDisk'
        DiskIdType  = 'Number'
        FSFormat    = 'NTFS'
        FSLabel     = 'LibraryData'
    }

    foreach ($lib in @('gog','steam','blizzard','origin','uplay'))
    {
        File $lib
        {
            DestinationPath = "L:\$lib"
            Type = 'Directory'
            Ensure = 'Present'
            DependsOn = '[Disk]dataDisk'
        }
    }
    #endregion

    #region Package install
    PackageManagementSource Chocolatey
    {
        Ensure             = 'Present'
        Name               = 'Chocolatey'
        ProviderName       = 'Chocolatey'
        SourceLocation     = 'http://chocolatey.org/api/v2/'  
        InstallationPolicy = 'Trusted'
    }

    PackageManagementSource PSGallery
    {
        Ensure             = 'Present'
        Name               = 'PSGallery'
        ProviderName       = 'PowerShellGet'
        SourceLocation     = 'https://www.powershellgallery.com/api/v2'  
        InstallationPolicy = 'Trusted'
    }

    foreach ($package in @('goggalaxy', 'steam', 'origin', 'uplay'))
    {
        PackageManagement $package
        {
            Name         = $package
            ProviderName = 'Chocolatey'
            DependsOn    = '[PackageManagementSource]Chocolatey'
        }
    }

    <# Extra handling for parsec, which is currently beta    
    PackageManagement parsec
    {
        Name                 = 'parsec'
        ProviderName         = 'Chocolatey'
        DependsOn            = '[PackageManagementSource]Chocolatey'
        RequiredVersion      = "1.0.0.20180613-beta"
    }#>

    #endregion

    #region Auto-logon
    Registry AutoAdminLogon
    {
        Key       = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueName = 'AutoAdminLogon'
        ValueData = 1
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }
    Registry AutoAdminCount
    {
        Key       = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueName = 'AutoLogonCount'
        ValueData = 9999
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }
    Registry DefaultUserName
    {
        Key       = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueName = 'DefaultUserName'
        ValueData = $Credential.UserName
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }
    Registry DefaultPassword # This is not secure in any way! Auto-logon needs to be configured for Parsec to work
    {
        Key       = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        ValueName = 'DefaultPassword'
        ValueData = $Credential.GetNetworkCredential().Password
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }
    Registry LockScreen
    {
        Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
        ValueName = 'NoLockScreen'
        ValueData = 1
        ValueType = 'DWord'
        Ensure    = 'Present'
        Force     = $true
    }
    #endregion

    #region virtual audio cable setup - not on Chocolatey :-(
    xRemoteFile VACDownload
    {
        DestinationPath = 'C:\DscDownloads\VAC460.zip'
        Uri             = 'https://software.muzychenko.net/trials/vac460.zip'
    }

    xRemoteFile ParsecClient
    {
        DestinationPAth = 'C:\DscDownloads\Parsec.exe'
        Uri             = 'https://s3.amazonaws.com/parsec-build/package/parsec-windows.exe'
    }

    Archive VACExtract
    {
        DependsOn   = '[xRemoteFile]VACDownload'
        Path        = 'C:\DscDownloads\VAC460.zip'
        Destination = 'C:\DscDownloads\VACSetup'
        Force       = $true
    }

    xPackage VACInstall
    {
        Path      = 'C:\DscDownloads\VACSetup\setup64.exe'
        Arguments = '-s -k 30570681-0a8b-46e5-8cb2-d835f43af0c5'
        Name      = 'Virtual Audio Cable'
        ProductId = '83ed7f0e-2028-4956-b0b4-39c76fdaef1d'
        Ensure    = 'Present'
        DependsOn = '[Archive]VACExtract'
    }
    
    Service audio
    {
        Name        = 'audiosrv'
        StartupType = 'Automatic'
        State       = 'Running'
    }
    #endregion

    #region Display driver
    xRemoteFile GRIDDriverAzure
    {
        DestinationPath = 'C:\DscDownloads\grid.exe'
        Uri             = 'https://go.microsoft.com/fwlink/?linkid=874181'
    }

    xPackage GRIDDriverAzureInstall
    {
        Path      = 'C:\DscDownloads\grid.exe'
        Arguments = '/s /n'
        Name      = 'NVIDIA Install Application'
        ProductId = ''
        Ensure    = 'Present'
        DependsOn = '[xRemoteFile]GRIDDriverAzure'
    }


    Script TeslaConfig
    {
        GetScript  = {
            $Result = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Foreach-Object { if ($_ -match "(?<Guid>\d{8}:\d{2}:\d{2}\.\d)") {$Matches.Guid}}
            Write-Verbose -Message "Found GUIDS: $(-join $Result)"
            @{Result = $Result}
        }
        TestScript = {
            Write-Verbose -Message 'Testing if WDDM is enabled or not'
            $state = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Select-String "\s*WDDM\s*" -Quiet
            Write-Verbose -Message "WDDM enabled: $state"
            return $state
        }
        SetScript  = {
            $guid = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Foreach-Object { if ($_ -match "(?<Guid>\d{8}:\d{2}:\d{2}\.\d)") {$Matches.Guid}}
            Write-Verbose -Message "Found GUIDS: $(-join $Result)"
            $result = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" -i $guid -dm 0
            Write-Verbose -Message "nvidia-smi returned: $($result | Out-String)"
            $global:DSCMachineStatus = 1
        }
    }

    #endregion
    
    #region Firewall
    Firewall ParsecIn
    {
        Name      = 'Parsec inbound traffic'
        LocalPort = @(21277..21279)
        Action    = 'Allow'
        Protocol  = 'UDP'
        Profile   = 'Domain', 'Private', 'Public'
    }
    #endregion
}
