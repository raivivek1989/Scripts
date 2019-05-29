function Get-TestDBName{
param( [string] $fileName, [string] $targetPath)

$tempPath = '.\tempUnzipped'

if (test-path($tempPath)){
        Remove-Item $tempPath -Recurse -Force
    }


if (-not (test-path($targetPath))){
        New-Item $targetPath -ItemType Directory
    }

expand-archive -path $fileName -destinationpath '.\tempUnzipped' 

Get-ChildItem -Path $tempPath -Filter '*.zip' | ForEach-Object{ 
    $fileName = $_.Name.Replace(".zip","")
    expand-archive -Path $tempPath\$_ -destinationpath "$tempPath\$fileName"
    
    $files = $(Get-Childitem -Path "$tempPath\$fileName")
     
    foreach($file in $files) {
        
        copy-item $file.fullname -destination  "$targetPath" -Force

        $newFilename = $fileName.Split(".")[0] + $file.extension

        if (test-path("$targetPath\$newFilename")){
        Remove-Item  "$targetPath\$file"    
        }
        else
        {
        rename-item         "$targetPath\$file"    "$newFilename"          
        }
        }

    }


    if (test-path($tempPath)){
    Remove-Item $tempPath -Recurse -Force
    }


}