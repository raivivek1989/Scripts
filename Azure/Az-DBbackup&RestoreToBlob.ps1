<#
.SYNOPSIS 
    Performs SQL database backups and uploads them to an Azure Storage account.

.DESCRIPTION
    This script connects to an Azure account, backs up specified databases, and uploads the backups to an Azure Storage container.

.PARAMETER SqlServerHostName
    The SQL Server host name (defaults to the local machine).

.PARAMETER Subscription
    The Azure subscription to use.

.PARAMETER StorageAccountName
    The name of the Azure Storage account.

.PARAMETER StorageContainerName
    The name of the storage container where backups will be stored.

.PARAMETER StorageResourceGroupName
    The resource group containing the storage account.

.PARAMETER Databaselist
    A comma-separated list of database names to back up.

.PARAMETER FolderNamePrefix
    The prefix for the backup file names.

.EXAMPLE
    .\Backup-And-Upload.ps1 -SqlServerHostName "myserver" -Subscription "MySubscription" -StorageAccountName "mystorage" -StorageContainerName "backups" -StorageResourceGroupName "myresourcegroup" -Databaselist "DB1,DB2" -FolderNamePrefix "DailyBackups"

.NOTES
    Author: Nagaendraa Disamcharla
    Version: 1.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)][String]$SqlServerHostName=$env:ComputerName,
    [Parameter(Mandatory=$true)][String]$Subscription,
    [Parameter(Mandatory=$true)][String]$StorageAccountName,
    [Parameter(Mandatory=$true)][String]$StorageContainerName,
    [Parameter(Mandatory=$true)][String]$StorageResourceGroupName,
    [Parameter(Mandatory=$true)][Object]$databaselist,
    [Parameter(Mandatory=$true)][String]$FolderNamePrefix,
    [Parameter(Mandatory=$true)][String]$svcUser,
    [Parameter(Mandatory=$true)][String]$svcPass
)

try {
    # Connect to Azure account via Identity
    Write-Output "Connecting to Azure Account and setting the Azure Context for Subscription: $Subscription"
    $null = Connect-AzAccount -Subscription $Subscription -Identity

    # Set Azure context to the specified subscription
    # $null = Set-AzContext -Subscription $Subscription -Name $Subscription
    Write-Output "Connected to Azure with Context: $Subscription"

    # Get the access key from the storage account to extract the context
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageResourceGroupName -Name $StorageAccountName -ErrorAction Stop
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $StorageResourceGroupName -Name $StorageAccountName)[0].Value

    # Backup databases
    foreach ($databaseName in $Databaselist) {
        $BackupFileName = "$FolderNamePrefix/$databaseName.bak"
        $LocalBackupPath = "G:\Temp\$databaseName.bak"
        # Perform SQL database backup
        $scriptblock={
            Param ($BackupFileName,$SqlServerHostName, $databaseName, $LocalBackupPath,$StorageContainerName, $StorageAccountName, $StorageAccountKey )   
            # Perform SQL database backup
            $storageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    $SqlBackupCommand = @"
    BACKUP DATABASE [$databaseName]
    TO DISK = N'$LocalBackupPath'
    WITH FORMAT, COPY_ONLY, COMPRESSION, NAME = N'$databaseName-Full Database Backup'
"@
            Invoke-Sqlcmd -Query $SqlBackupCommand -ServerInstance $SqlServerHostName -TrustServerCertificate
            Write-Output "Uploading backup file to Azure Storage"
            Set-AzStorageBlobContent -File $LocalBackupPath -Container $StorageContainerName -Blob $BackupFileName -Context $storageAccountContext -Force
            Write-Output "Cleaning up local backup file"
            Remove-Item $LocalBackupPath -Force
            Write-Output "Backup completed and uploaded to Azure Storage."
        }
        [securestring]$secStringPassword = ConvertTo-SecureString $svcPass -AsPlainText -Force
        [pscredential]$credential = New-Object System.Management.Automation.PSCredential($svcUser, $secStringPassword)
        Invoke-Command -ComputerName $SqlServerHostName -Scriptblock $scriptblock -Credential $credential -ArgumentList $BackupFileName,$SqlServerHostName,$databaseName,$LocalBackupPath,$StorageContainerName,$StorageAccountName,$StorageAccountKey
    }
}
catch {
    Write-Error "$_"
}
finally {
    Get-AzContext -Name $Subscription | Disconnect-AzAccount
    Write-Output "----------Disconnected Azure Connection----------"
}