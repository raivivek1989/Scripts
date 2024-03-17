# Set the name of the CSV file containing resource IDs and tag values
$csvFilePath = "resource_tags.csv"
$logFilePath = "tagging_status.log"

# Initialize an array to store status messages
$statusMessages = @()

try {
    # Read the CSV file
    $resources = Import-Csv -Path $csvFilePath

    foreach ($resource in $resources) {
        $resourceId = $resource.ResourceId
        $tagKey = $resource.TagKey
        $tagValue = $resource.TagValue
        
        # Extract Subscription ID from Resource ID
        $subscriptionId = ($resourceId -split '/')[2]

        try {
            # Connect to Azure
            Connect-AzAccount

            # Select the Azure subscription
            Select-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Stop

            # Get the resource by ID
            $azureResource = Get-AzResource -ResourceId $resourceId -ErrorAction Stop

            # Add the tag to the resource
            $tags = $azureResource.Tags
            $tags[$tagKey] = $tagValue

            # Update the tags of the resource
            Set-AzResource -Tag $tags -ResourceId $resourceId -Force -ErrorAction Stop

            $statusMessages += "Tag added successfully to resource: $resourceId"
        }
        catch {
            $errorMessage = $_.Exception.Message
            $statusMessages += "Error adding tag to resource: $resourceId - $errorMessage"
        }
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $statusMessages += "Error reading CSV file: $errorMessage"
}

# Write status messages to log file
$statusMessages | Out-File -FilePath $logFilePath

Write-Host "Tagging process completed. Check $logFilePath for details."


# # # Sample CSV
# # # ResourceId,TagKey,TagValue
# # # /subscriptions/your_subscription_id/resourceGroups/your_resource_group/providers/Microsoft.Compute/virtualMachines/your_virtual_machine,Environment,Production
# # # /subscriptions/your_subscription_id/resourceGroups/your_resource_group/providers/Microsoft.Storage/storageAccounts/your_storage_account,Environment,Development
