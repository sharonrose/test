workflow test
{
	# Specify input parameters here
	 param (
    
    [Parameter(Mandatory=$true)]
    [string] 
    $variableName,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $credentialName
    
    )
	
	 #Get the credential with the above name from the Automation Asset store
	 write-Output $accountName
	 write-Output $variableName
	 write-Output $credentialName
	 write-Output $resourceGroupName
    $Cred = Get-AutomationPSCredential -Name $CredentialAssetName
	Add-AzureRmAccount -Credential $Cred
	$myprefix = "bigipct8"
	write-Output $myprefix
$primary = Get-AutomationVariable -Name 'Log-Storage-Primary'
$secondary = Get-AutomationVariable -Name 'Log-Storage-Secondary'
$CredentialAssetName = $credentialName
	#Get the credential with the above name from the Automation Asset store
    $Cred = Get-AutomationPSCredential -Name $CredentialAssetName
    if(!$Cred) {
        Throw "Could not find an Automation Credential Asset named '${CredentialAssetName}'. Make sure you have created one in this Automation Account."
    }
	 #Connect to your Azure Account
    $Account = Add-AzureAccount -Credential $Cred
    if(!$Account) {
        Throw "Could not authenticate to Azure using the credential asset '${CredentialAssetName}'. Make sure the user name and password are correct."
    }
$primarykey = Get-AzureRmStorageAccountKey -ResourceGroupName accuweather -Name $primary
$secondarykey = Get-AzureRmStorageAccountKey -ResourceGroupName accuweather -Name $secondary

$primaryctx = New-AzureStorageContext -StorageAccountName $primary -StorageAccountKey $primarykey.Key1
$secondaryctx = New-AzureStorageContext -StorageAccountName $secondary -StorageAccountKey $secondarykey.Key1

$primarycontainers = Get-AzureStorageContainer -Context $primaryctx

# Loop through each of the containers16. foreach($container in $primarycontainers)
{
# Do a quick check to see if the secondary container exists, if not, create it.
    $secContainer = Get-AzureStorageContainer -Name $container.Name -Context $secondaryctx -ErrorAction SilentlyContinue
    if (!$secContainer)
    {
        $secContainer = New-AzureStorageContainer -Context $secondaryctx -Name $container.Name
        Write-Host "Successfully created Container" $secContainer.Name "in Account" $secondary
    }

# Loop through all of the objects within the container and copy them to the same container on the secondary account
    $primaryblobs = Get-AzureStorageBlob -Container $container.Name -Context $primaryctx

    foreach($blob in $primaryblobs)
    {
        $copyblob = Get-AzureStorageBlob -Context $secondaryctx -Blob $blob.Name -Container $container.Name -ErrorAction SilentlyContinue

# Check to see if the blob exists in the secondary account or if it has been updated since the last runtime.
        if (!$copyblob -or $blob.LastModified -gt $copyblob.LastModified) {
            $copyblob = Start-AzureStorageBlobCopy -SrcBlob $blob.Name -SrcContainer $container.Name -Context $primaryctx -DestContainer $secContainer.Name -DestContext $secondaryctx -DestBlob $blob.Name

            $status = $copyblob | Get-AzureStorageBlobCopyState
            while ($status.Status -eq "Pending")
            {
                $status = $copyblob | Get-AzureStorageBlobCopyState
                Start-Sleep 10
            }

            Write-Host "Successfully copied blob" $copyblob.Name "to Account" $secondary "in container" $container.Name
        }
    }
}
		set-automationvariable -Name $variableName -Value $myprefix
		$KeyValueContent =get-automationvariable -Name $variableName
		Write-Output "Finally KeyValueContent is "    
     Write-Output $KeyValueContent    
	

}