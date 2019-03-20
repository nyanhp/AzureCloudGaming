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
    Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.5.0.0
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 8.5.0.0
    Import-DscResource -ModuleName xPendingReboot -ModuleVersion 0.4.0.0
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion 7.0.0.0

    LocalConfigurationManager 
    {
        RebootNodeIfNeeded = $true
        ActionAfterReboot  = 'ContinueConfiguration'
    }

    #region Disklayout
    <#Disk tempDisk # Until StorageDsc can reliably work with MBR disks as well
    {
        DiskId      = 1
        DiskIdType  = 'Number'
        DriveLetter = 'X'
    }#>
    Disk dataDisk
    {
        DiskId      = 2
        DriveLetter = 'L'
        #DependsOn   = '[Disk]tempDisk'
        DiskIdType  = 'Number'
        FSFormat    = 'NTFS'
        FSLabel     = 'LibraryData'
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

    foreach ($package in @('goggalaxy', 'steam', 'ultravnc', 'origin', 'uplay'))
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

    #region UltraVNC customization
    File uvncIni
    {
        DestinationPath = 'C:\Program Files\uvnc bvba\UltraVNC\ultravnc.ini'
        Type            = 'File'
        Ensure          = 'Present'
        Force           = $true
        DependsOn       = '[PackageManagement]ultravnc'
        Contents        = @'
[ultravnc]
passwd=28AD591A62B4AD949F
passwd2=8BF749ADC043135FED
[admin]
UseRegistry=0
SendExtraMouse=1
MSLogonRequired=0
NewMSLogon=0
DebugMode=0
Avilog=0
path=C:\Program Files\uvnc bvba\UltraVNC
accept_reject_mesg=
DebugLevel=0
DisableTrayIcon=0
rdpmode=0
LoopbackOnly=0
UseDSMPlugin=0
AllowLoopback=1
AuthRequired=1
ConnectPriority=0
DSMPlugin=
AuthHosts=
DSMPluginConfig=
AllowShutdown=1
AllowProperties=1
AllowEditClients=1
FileTransferEnabled=1
FTUserImpersonation=1
BlankMonitorEnabled=1
BlankInputsOnly=0
DefaultScale=1
primary=1
secondary=0
SocketConnect=1
HTTPConnect=1
AutoPortSelect=1
PortNumber=5900
HTTPPortNumber=5800
IdleTimeout=0
IdleInputTimeout=0
RemoveWallpaper=0
RemoveAero=0
QuerySetting=2
QueryTimeout=10
QueryDisableTime=0
QueryAccept=0
QueryIfNoLogon=1
InputsEnabled=1
LockSetting=0
LocalInputsDisabled=0
EnableJapInput=0
EnableWin8Helper=0
kickrdp=0
clearconsole=0
[admin_auth]
group1=
group2=
group3=
locdom1=0
locdom2=0
locdom3=0
[poll]
TurboMode=1
PollUnderCursor=0
PollForeground=0
PollFullScreen=1
OnlyPollConsole=0
OnlyPollOnEvent=0
MaxCpu=40
EnableDriver=0
EnableHook=1
EnableVirtual=0
SingleWindow=0
SingleWindowName=        
'@
    }
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
    }
    
    Service audio
    {
        Name        = 'audiosrv'
        StartupType = 'Automatic'
        State       = 'Running'
    }
    #endregion

    #region Display driver
    xRemoteFile TeslaM60	
    {	
        Uri             = 'http://us.download.nvidia.com/tesla/412.29/412.29-tesla-desktop-winserver2016-international.exe'
        DestinationPath = 'C:\DscDownloads\412.29-tesla-desktop-winserver2016-international.exe'	
    }	

     Package TeslaM60Install	
    {	
        Name      = 'NVIDIA Install Application'	
        DependsOn = '[xRemoteFile]TeslaM60'	
        Path      = 'C:\DscDownloads\412.29-tesla-desktop-winserver2016-international.exe'	
        ProductId = ''	
        Arguments = '/s /n'	
    }

    Script TeslaConfig
    {
        DependsOn = '[Package]TeslaM60Install'
        GetScript  = {@{Result = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Foreach-Object { if ($_ -match "(?<Guid>\d{8}:\d{2}:\d{2}\.\d)") {$Matches.Guid}}}}
        TestScript = {[bool](& "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Foreach-Object { if ($_ -match "\s*WDDM\s*") {$Matches.0}})}
        SetScript  = {
            $guid = & "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" | Foreach-Object { if ($_ -match "(?<Guid>\d{8}:\d{2}:\d{2}\.\d)") {$Matches.Guid}}
            [void] (& "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" -g $guid -dm 0)
            $global:DSCMachineStatus = 1
        }
    }

    xPendingReboot teslaReboot
    {
        Name      = 'TeslaReboot'
        DependsOn = '[Script]TeslaConfig'
    }
    #endregion
    
    #region Firewall
    Firewall UvncIn
    {
        Name      = 'Ultra VNC Server 5900 TCP IN'
        LocalPort = 5900
        Action    = 'Allow'
        Protocol  = 'TCP'
        Profile   = 'Domain', 'Private', 'Public'
    }

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
