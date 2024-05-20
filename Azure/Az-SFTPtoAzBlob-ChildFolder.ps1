## Sync File share to Blob

# Define Azure Storage account details
$storageAccountName = "<storageAccountName>"
$resourceGroupName = "<resourceGroupName>"
$localBaseFolderPath = "S:\HU-FTP"
$storageAccountUrl = "$storageAccountName.file.core.windows.net"
#$storagebloburl = "$storageAccountName.blob.core.windows.net"
$fileshareName = "<fileshareName>"
$AgencysPath = $(AgencyPath)

try {
    # Connect to Azure account
    Connect-AzAccount -Identity
    #Connect-AzAccount
    Set-AzContext -Subscription "sub-crop-nanc-prod-01"
    
    Write-Output "Mounting Fileshare:$FileshareName to S:\ drive is Started..."
    $connectTestResult = Test-NetConnection -ComputerName $storageAccountUrl -Port 445
    if ($connectTestResult.TcpTestSucceeded) {
        # Mount the drive
        $null=New-PSDrive -Name S -PSProvider FileSystem -Root "\\$storageAccountUrl\$fileshareName" -Persist
        Write-Output "Mounting Fileshare:$FileshareName to S:\ drive is Completed..."
    } 
    else 
    {
        Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
    }

    # Get storage account context
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction Stop
    $ctx = $storageAccount.Context

    foreach($Agency in $AgencysPath){
        # Get a list of all subdirectories (folders) in the base local folder
        $localFolders = Get-ChildItem -Path "$localBaseFolderPath\$Agency" -Directory
       
        # Iterate over each local folder and upload contents to corresponding blob container
        foreach ($folder in $localFolders) {
            $folderName = $folder.Name
            # Use folder name as lowercase container name (replace spaces with '-')
            $containerName = $folderName.ToLower() -replace '\s','' -replace '[^\w-]','-' -replace '_+','-' -replace '(-)+','-' 
            $localFolderPath = $folder.FullName

            # Create container if it doesn't exist
            $container = Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue
            if (!$container) {
                Write-Output "Before new az storage container creation"
                $container = New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off
                Write-Output "Created container '$containerName' in storage account '$storageAccountName'."
            }

            # Upload files from local folder to blob container (skip files that already exist)
            $localFiles = Get-ChildItem -Path $localFolderPath -File -Recurse 

            foreach($file in $localFiles){
                $destBlob = @()
                $destBlob = Get-AzStorageBlob -Container $containerName -Context $ctx -Blob $file.Name -ErrorAction SilentlyContinue
                $blobpath = $file.FullName -replace [regex]::Escape("$localFolderPath\"), ""

                if(-not $destBlob -or $file.LastWriteTimeUtc -gt $destBlob.LastModified.UtcDateTime){
                    $null=Set-AzStorageBlobContent -File $file.FullName -Container $containerName -Blob $blobpath -Context $ctx -Force
                    Write-Output "Uploaded file '$blobpath' to container '$containerName'."
                }
                else {
                    Write-Output "At '$containerName'-'$blobpath' :No files are modified or no new files are created!"
                }
            }
        }
    }
    
    Write-Output "File upload to Azure Blob Storage completed successfully."
}
catch {
    Write-Error "$_"
    
}
finally {
    if(Get-PSDrive -Name S)
    {
        Remove-PSDrive -Name S -Force
        Write-Output "Drive unmounted Successfully"
    }
    else{
        Write-Output "Drive not found!"
    }
}