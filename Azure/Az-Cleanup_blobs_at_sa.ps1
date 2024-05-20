<#
.SYNOPSIS
    This script automates the cleanup of Azure storage account blobs within specified containers.

.DESCRIPTION
    The script logs into an Azure account, retrieves the storage account context, and processes each container by deleting all blobs in sub-folders, except for the latest five backups.

.PARAMETER subscriptionName
    The name of the Azure subscription of the storage account.

.PARAMETER resourceGroupName
    The name of the resource group where the storage account resides.

.PARAMETER storageAccountName
    The name of the Azure storage account.

.PARAMETER containerNames
    An array of container names within the storage account to be processed.

.EXAMPLE
    .\CleanUp-AzureStorage.ps1 -subscriptionName <subscriptionName> -resourceGroupName <resourceGroupName> -storageAccountName <storageAccountName> -containerNames @("container1", "container2", ...)
    This example runs the script with the specified parameters to clean up the Azure storage account blobs.

.NOTES
    Make sure that the 'Az' module is installed and that you have the necessary permissions to perform the operations in the script.
#>

param(
    [Parameter(Mandatory = $true)][String]$subscriptionName,
    [Parameter(Mandatory = $true)][String]$resourceGroupName,
    [Parameter(Mandatory = $true)][String]$storageAccountName,
    [Parameter(Mandatory = $true)][String[]]$containerNames
)

# Install the Az module if it's not already installed
if (-not (Get-Module -ListAvailable -Name "Az*")) {
   Install-Module -Name Az -AllowClobber -Force
}

try {
   # Login to your Azure account
   Connect-AzAccount -Subscription $subscriptionName -Identity

   # Get the storage account context
   $storageAccountContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context
   
   # Process each container
   foreach ($containerName in $containerNames) {
       Write-Output "Processing container: $containerName"
       # Get the list of folders (assume folders are blobs with a '/' at the end of their name)
       $Allblobs = Get-AzStorageBlob -Container $containerName -Context $storageAccountContext
       #Get all the unique root folders present in the container
       $rootfolders = $Allblobs | Foreach-Object {$_.Name.split("/")[0]} | Where-Object {$_ -ne ""} | Select-Object -Unique
       #loop in each folder and get all the sub-folders present in each root folder
       ForEach ($rootfolder in $rootfolders){
            $blobs = $Allblobs | Where-Object{$_.Name -like "$rootfolder*"}
            $folders = $blobs.Name | 
            ForEach-Object {
                $lastSlashIndex = $_.LastIndexOf("/")
                $_.Substring(0, $lastSlashIndex)
            } | 
            Select-Object -Unique 
        
           # Determine folders to delete (all except the latest 5)
           $foldersToDelete = $folders | Sort-Object { [DateTime]::ParseExact($_.Split("/")[1], "yyyy-MM-dd", $null) } | Select-Object -SkipLast 5
           foreach ($folder in $foldersToDelete) {
               Write-Output "========================================================"
               Write-Output "Container: $($containerName)"
               Write-Output "Deleting blobs under folder: $($folder)"
               Write-Output "========================================================"
               # Get all blobs in the folder
               $folderBlobs = $Allblobs | Where-Object {$_.Name -like "$folder*"}
               
               # Delete all blobs in the folder
               foreach ($blob in $folderBlobs) {
                   Remove-AzStorageBlob -Blob $blob.Name -Container $containerName -Context $storageAccountContext -Force
                   Write-Output "Deleted blob: $($blob.Name)"
               }
           }
        }
    }
}
catch {
   Write-Error "An error occurred: $_"
}
finally {
   # Disconnect from Azure account
   Disconnect-AzAccount
   Write-Output "Disconnected from Azure account."
}