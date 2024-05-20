[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][String]$SqlServerHostName,
    [Parameter(Mandatory=$true)][String]$Subscription,
    [Parameter(Mandatory=$true)][String]$StorageAccountName,
    [Parameter(Mandatory=$true)][String]$StorageContainerName,
    [Parameter(Mandatory=$true)][String]$StorageResourceGroupName,
    [Parameter(Mandatory=$true)][String]$pathPrefixToSearch,
    [Parameter(Mandatory=$true)][String]$svcUser,
    [Parameter(Mandatory=$true)][String]$svcPass
)

try{
    # Connect to Azure account via Identity
    Write-Output "Connecting to Azure Account and setting the Azure Context for Subscription: $Subscription"
    $null = Connect-AzAccount -Subscription $Subscription -Identity

    # Get the access key from the storage account to extract the context
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageResourceGroupName -Name $StorageAccountName -ErrorAction Stop
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageResourceGroupName -Name $StorageAccountName)[0].Value

    $Scriptblock = {
        param(
            $StorageContainerName = $StorageContainerName,
            $StorageAccountName = $StorageAccountName,
            $StorageAccountKey = $StorageAccountKey,
            $pathPrefixToSearch = $pathPrefixToSearch
        )
        $DestServer   = $env:COMPUTERNAME
        $SqlLogin     = "<ValidSQLLogin>"
        $LocalFolderPath = "<LocalFolderPathWhereTheBackupsFromStoageShallBeDroped>"
                
        #Install the below modules if not present
        $modulesToCheck = @("SqlServer", "Az*")
        foreach ($module in $modulesToCheck) {
            if (-not (Get-InstalledModule -Name $module)) {
                $module=$module.trim('*')
                Write-host "$module has not been Installed, hence initiated Installation..."
                Install-Module -Name $module -Force
                Write-Host "$module module has been installed successfully."
            } 
            else {
                $module=$module.trim('*')
                Write-Host "$module module is already installed."
            }
        }

        Function Add-UserToRole ([string] $server, [String] $Database , [string]$User, [string]$Role){
            $Svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $server
            #Check Database Name entered correctly
            $db = $svr.Databases[$Database]
            if($db -eq $null){
                Write-Output " $Database is not a valid database on $Server"
                Write-Output " Databases on $Server are :"
                $svr.Databases|select name
                break
            }
            #Check Role exists on Database
            $Rol = $db.Roles[$Role]
            if($Rol -eq $null){
                Write-Output " $Role is not a valid Role on $Database on $Server  "
                Write-Output " Roles on $Database are:"
                $db.roles|select name
                break
            }
            if(!($svr.Logins.Contains($User))){
                Write-Output "$User not a login on $server create it first"
                break
            }
            if (!($db.Users.Contains($User))){
                # Add user to database
                $usr = New-Object ('Microsoft.SqlServer.Management.Smo.User') ($db, $User)
                $usr.Login = $User
                $usr.Create()
                #Add User to the Role
                $Rol = $db.Roles[$Role]
                $Rol.AddMember($User)
                Write-Output "$User was not a login on $Database on $server"
                Write-Output "$User added to $Database on $Server and $Role Role"
            }
            else{
                #Add User to the Role
                $Rol = $db.Roles[$Role]
                $Rol.AddMember($User)
                Write-Output "$User added to $Role Role in $Database on $Server "
            }
        }                                                                                                                                                                           
        # Import .bak from storage account container ==========================================        

        If(!(test-path -PathType container $LocalFolderPath))
        {
              New-Item -ItemType Directory -Path $LocalFolderPath
              Write-host "Created $($LocalFolderPath) Folder"
        }

        # Get storage account context
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        # Get list of blobs in the container
        $BlobList = Get-AzStorageBlob -Context $StorageContext -Container $StorageContainerName -Blob "$pathPrefixToSearch*"
        # Download each blob to the local folder
        foreach ($Blob in $BlobList) {
           $BlobName = $Blob.Name.Split("/")[2]
           $LocalFilePath = Join-Path -Path $LocalFolderPath -ChildPath $BlobName
           Get-AzStorageBlobContent -Context $StorageContext -Container $StorageContainerName -Blob $Blob.Name -Destination $LocalFilePath -Force
        }
        # ========================================================
        Write-Host "Collecting BAK files from $LocalFolderPath" -ForegroundColor Green
        $TmpRestorePath = $LocalFolderPath 
        $BakFiles = Get-ChildItem -Path "FileSystem::$($TmpRestorePath)" -Filter "*.bak"
        try {
            $null=new-object ('Microsoft.SqlServer.Management.Smo.Server')$DestServer
        }
        catch{ 
            $ErrorActionPreference = "Stop"
  
            $sqlpsreg="HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps160"  
  
            if (Get-ChildItem $sqlpsreg -ErrorAction "SilentlyContinue")  
            {  
                throw "SQL Server Provider for Windows PowerShell is not installed."  
            }  
            else {  
                $item = Get-ItemProperty $sqlpsreg  
                $sqlpsPath = [System.IO.Path]::GetDirectoryName($item.Path)  
            }  
  
            $assemblylist =
            "Microsoft.SqlServer.Management.Common",  
            "Microsoft.SqlServer.Smo",  
            "Microsoft.SqlServer.Dmf ",  
            "Microsoft.SqlServer.Instapi ",  
            "Microsoft.SqlServer.SqlWmiManagement ",  
            "Microsoft.SqlServer.ConnectionInfo ",  
            "Microsoft.SqlServer.SmoExtended ",  
            "Microsoft.SqlServer.SqlTDiagM ",  
            "Microsoft.SqlServer.SString ",  
            "Microsoft.SqlServer.Management.RegisteredServers ",  
            "Microsoft.SqlServer.Management.Sdk.Sfc ",  
            "Microsoft.SqlServer.SqlEnum ",  
            "Microsoft.SqlServer.RegSvrEnum ",  
            "Microsoft.SqlServer.WmiEnum ",  
            "Microsoft.SqlServer.ServiceBrokerEnum ",  
            "Microsoft.SqlServer.ConnectionInfoExtended ",  
            "Microsoft.SqlServer.Management.Collector ",  
            "Microsoft.SqlServer.Management.CollectorEnum",  
            "Microsoft.SqlServer.Management.Dac",  
            "Microsoft.SqlServer.Management.DacEnum",  
            "Microsoft.SqlServer.Management.Utility"  
  
            foreach ($asm in $assemblylist)  
            {  
                $asm = [Reflection.Assembly]::LoadWithPartialName($asm)  
            } 
        }                                                                                                                                                                      

        # process fies
        $srv = new-object ('Microsoft.SqlServer.Management.Smo.Server')$DestServer
        $rs = new-object('Microsoft.SqlServer.Management.Smo.Restore')
        $ErrorMessages = @()

        if($pathPrefixToSearch -like "HF*"){
             $prefixDbName = "HU-AZHotFix_"
         }
         elseif($pathPrefixToSearch -like "HUG*")
         {
             $prefixDbName = "HU-AZGEN_"
         }
         else{
             $prefixDbName = ""
         }

        foreach($BakFile in $BakFiles)
        {
            # Get Dest SQL Instance/Databases
            $SqlInstance = Get-SqlInstance -ServerInstance $DestServer 
            $SqlDatabases = $SqlInstance | Get-SqlDatabase
            # Get DB Name
            $bdi = new-object ('Microsoft.SqlServer.Management.Smo.BackupDeviceItem') ($BakFile.FullName, 'File')
            $rs.Devices.Add($bdi)
            $header = $rs.ReadBackupHeader($srv)
            if($header.Rows.Count -eq 1)
            {             
                if($header.Rows[0]["DatabaseName"] -notlike "*Shared*" -and $header.Rows[0]["DatabaseName"] -notlike "*TelerikSession*" -and $header.Rows[0]["DatabaseName"] -notlike "*AgWorksServerSettings*"){
                    $DatabaseName = $prefixDbName+$header.Rows[0]["DatabaseName"]
                }
                else{
                    $DatabaseName = $header.Rows[0]["DatabaseName"]
                }
            }
            $rs.Devices.Remove($bdi) | Out-Null    
            if(![String]::IsNullOrEmpty($DatabaseName))
            {
                try{
                    $SqlInstance.KillDatabase($DatabaseName)
                }
                catch{
                    Write-Host "Error killing DB: $DatabaseName on server: $($SqlInstance.DomainInstanceName)" -ForegroundColor Yellow
                }   
            }    
            try{
                if(![String]::IsNullOrEmpty($DatabaseName))
                {
                    Write-Host "Restoring database: $DatabaseName to server: $($SqlInstance.DomainInstanceName)" -ForegroundColor Green
                    # Restore DB to dest
                    Restore-SqlDatabase -ServerInstance "$($SqlInstance.DomainInstanceName)" `
                        -Database $DatabaseName -BackupFile $BakFile.FullName -AutoRelocateFile -PassThru -ReplaceDatabase
                    # check for login
                    if(!(Get-SqlLogin -ServerInstance $DestServer | where { $_.Name -eq $SqlLogin }))
                    {
                        # add login
                        Write-Host "Creating login: $SqlLogin on server: $DestServer" -ForegroundColor Green
                        Add-SqlLogin -ServerInstance $DestServer -LoginName $SqlLogin -LoginType WindowsGroup -GrantConnectSql -Enable
                    }
                    # add roles
                    Write-Host "granting role: db_datareader for user: $SqlLogin to database: $DatabaseName on server: $DestServer " -ForegroundColor Green
                    Add-UserToRole -server $DestServer -Database $DatabaseName -User $SqlLogin -Role db_datareader
                    Write-Host "granting role: db_denydatawriter for user: $SqlLogin to database: $DatabaseName on server: $DestServer " -ForegroundColor Green
                    Add-UserToRole -server $DestServer -Database $DatabaseName -User $SqlLogin -Role db_denydatawriter
                }
            }
            catch{
                $ErrorMessages += $_
            }
            finally{
                # Cleanup file
                Write-Host "Removing file $($BakFile.FullName)" -ForegroundColor Yellow
                $BakFile | Remove-Item -Force
            }
        }
    }  
    [securestring]$secStringPassword = ConvertTo-SecureString $svcPass -AsPlainText -Force
    [pscredential]$credential = New-Object System.Management.Automation.PSCredential($svcUser, $secStringPassword)
    Invoke-Command -ComputerName $SqlServerHostName -Scriptblock $scriptblock -Credential $credential -ArgumentList $StorageContainerName,$StorageAccountName,$StorageAccountKey,$pathPrefixToSearch
} 
catch {
    Write-Error "$_"
} 
finally {
    Get-AzContext -Name $Subscription | Disconnect-AzAccount
    Write-Output "----------Disconnected Azure Connection----------"
}