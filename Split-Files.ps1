function Split-Files{
param( [string] $fileName, [string] $targetPath)

$tempPath = '.\tempUnzipped'

if (test-path($tempPath)){
    Remove-Item $tempPath -Recurse -Force
}

if (-not (test-path($targetPath))){
    New-Item $targetPath -ItemType Directory
}

expand-archive -path $fileName -destinationpath '.\tempUnzipped' 

Get-ChildItem -Path $tempPath -Filter '*.zip' | expand-archive -destinationpath $tempPath 

Get-ChildItem -Path $tempPath -Filter 'Enable*.txt' | compress-archive -destination "$targetPath\Enable.zip" -Force

Get-ChildItem -Path $tempPath -Filter 'Disable*.txt' | compress-archive -destination "$targetPath\Disable.zip" -Force

if (test-path($tempPath)){
    Remove-Item $tempPath -Recurse -Force
}


}