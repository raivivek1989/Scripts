<#
.SYNOPSIS
    Create an Build Pipeline for Java Maven Projects
.DESCRIPTION
    Create an Build Pipeline for Java Maven Projects using Azure YAML pipeline format
.PARAMETER username
    User name to execute the script
.PARAMETER password
    Personal Access token to execute the script
.PARAMETER organization
    Azure DevOps Organization where the Build Pipeline will be created
.PARAMETER project
    Azure DevOps Project where the Build Pipeline will be created
.PARAMETER repository
    Azure DevOps Repository name to be created
.PARAMETER repository
    Environment lists, Ex - "DEV", "STG", "PROD"
.OUTPUTS
    None
.NOTES
    Enterprise Technical Integration Services
    Deployment script Libraries
    ----------------------------------------------------------------------------
    Platform        : DevSecOps Platform
    Product         : Java Maven Application Manifest

    Objective:
        Create an Build Pipeline for Java Maven Projects

    Environment Varaibles Needed

        C_ADO_SERVICE_ENDPOINT_BLACKDUCK_NAME       = Blackduck Endpoint name        
        CN_APP_BLACKDUCK_TOKEN                      = Blackduck Auth token
        CN_APP_BLACKDUCK_URL                        = Blackduck URL
        CN_ENVIRONMENT_LIST                         = List of required environments (i.e. DEV,STG,PROD)
    
    
.EXAMPLE
#>


param (
    [string]$username = "null",
    [String]$password = "null",
    [string]$organization = "null",
    [string]$project = "null",
    [string]$repository = "null"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\libs\adoCoreLib.ps1"
. "$PSScriptRoot\..\libs\adoHelperLib.ps1"

[string]$C_STAGING_FOLDER = "$PSScriptRoot\stg\$(New-Guid)"

# Location of the ADO Template and Manifest to initialize the Repo 
[string]$C_ADO_TEMPLATE_ORGANIZATION = "CN-DevOps"
[string]$C_ADO_TEMPLATE_PROJECT = "ADO"
[string]$C_ADO_TEMPLATE_REPONAME = "pipelines-templates"
[string]$C_ADO_TEMPLATE_BRANCH = "master"

# Json template for BUILD pipeline creation using Yaml
[string]$C_BUILD_JSONTEMPLATE_FILENAME = "$PSScriptRoot\..\common\common-build-template-yaml-v01.json"

[array]$C_ADO_TEMPLATE_FILES = @(    
    "multistage/java/maven/microservice/azure-pipelines.yml"
)

# Service Endpoint creation to access the ADO Project in CN-DevOps Organization
[string]$C_ADO_SERVICE_ENDPOINT_NAME = "ado-templates"
[string]$C_ADO_SERVICE_ENDPOINT_URL = "https://dev.azure.com/CN-DevOps/"

[string]$C_ADO_SERVICE_ENDPOINT_SONARQUBE_NAME = "SonarQube"
[string]$C_ADO_SERVICE_ENDPOINT_BLACKDUCK_NAME = "Black Duck"

# Service Endpoint permission template
[string]$C_ADO_SERVICE_ENDPOINT_PERMISSION_JSONTEMPLATE = "$PSScriptRoot\..\common\common-serviceEndPoint-permision.json"

# Json template for Environment configurations
[string]$C_ENVIRONMENT_CHECK_APPROVAL_JSONTEMPLATE_FILENAME = "$PSScriptRoot\..\common\common-environment-check-approval-template.json"
[string]$C_ENVIRONMENT_CHECK_TEMPLATE_JSONTEMPLATE_FILENAME = "$PSScriptRoot\..\common\common-environment-check-template-template.json"

# Json template for Variable Groups configurations
[string]$C_ADO_SERVICE_VARIABLEGROUP_PERMISSION_JSONTEMPLATE = "$PSScriptRoot\..\common\common-variableGroup-permision.json"

$EnvsList = $Env:CN_ENVIRONMENT_LIST.Split(",")


Write-Host "`n############################################################"
Write-Host "#                                                             "
Write-Host "# Starting the script for creating the Java Maven build pipeline "
Write-Host "#                                                             "
Write-Host "##############################################################"

if (Test-Path $C_STAGING_FOLDER) {
    Remove-Item $C_STAGING_FOLDER -Force -Recurse
}


# Necessary for the Core ADO Libraries
$Env:CN_ADO_USERNAME = $username
$Env:CN_ADO_PASSWORD = $password

Write-Host "asking input if triggered manually..."
if ($username -eq "null") {
    # $username = Read-Host -Prompt "Your cn email adress"
    throw "Your cn email adress should not blank"
}
if ($password -eq "null") {
    # $password = Read-Host -Prompt "Your PAT"
    throw "Your PAT should not blank"
}
if ($organization -eq "null") {
    # $organization = Read-Host -Prompt "Organization Name"
    throw "Organization Name should not blank"
}
if ($project -eq "null") {
    # $project = Read-Host -Prompt "Project Name"
    throw "Project Name should not blank"
}
if ($repository -eq "null") {
    # $repository = Read-Host -Prompt "repo name (comma delimited list or press enter for all repo)"
    throw "repo name (comma delimited list or press enter for all repo) should not blank"
}
Write-Host "*************************************"
Write-Host "Parameters check....."
Write-Host "username: $username"
Write-Host "organization: $organization"
Write-Host "project: $project"
Write-Host "repository: $repository"
Write-Host "EnvsList: $EnvsList"
Write-Host "*************************************"
# Setting name of Build Pipeline

$buildPipelineName = "$repository"

Write-Host "Verifying if Build Pipeline <<$buildPipelineName>> exists "
$buildPipelineObj = Find-ADOBuilDefinition -Organization:$organization -ProjectName:$project `
    -BuildName:$buildPipelineName


$repoObj = Find-ADORepoository -Organization:$organization -ProjectName:$project `
    -RepositoryName:$repository

if (-not($repoObj)) {
    throw "Repository <<$repository>> does not exists"
}

$tEnvList = ([string]$EnvsList).Split(" ")


Write-Host "**************************************"
Write-Host "* Verifying ADO Environments"
Write-Host "**************************************"

Write-Host "Verifying Environments"

foreach ($tEnvItem in $tEnvList) {
    
    $tEnvName = "MS_{0}" -f $tEnvItem.toUpper()
    Write-Host "Verifying Environment = > <<$tEnvName>>"
    $tEnvObj = Find-ADOEnvironment -Organization:$organization -ProjectName:$project `
        -EnvironmentName:$tEnvName
    if (-not($tEnvObj)) {
        Write-Host "      Env does not exists. Creating Environment "
        $tEnvDesc = "Integration Platform - MS. Environment={0}" -f $tEnvItem.toUpper()
        $tEnvObj = New-ADOEnvironment -Organization:$organization -ProjectName:$project `
            -EnvironmentName:$tEnvName -EnvironmentDescription:$tEnvDesc
    }
    else {
        Write-Host "      Environment = > <<$tEnvName>> exists."
    }
    [array]$envCheckExists =  Get-ADOEnvironmentApprovalCheck -Organization:$organization -ProjectName:$project `
        -EnvironmentId:$tEnvObj.id

    $checkApprovalExists = $false
    $checkTemplateExists = $false
    if ($envCheckExists) {
        if($envCheckExists.where{ $_.type.name -like "Approval" }){
            $checkApprovalExists = $true
        }
        if($envCheckExists.where{ $_.type.name -like "ExtendsCheck" }){
            $checkTemplateExists = $true
        }
        
    }

    if (-not($checkApprovalExists)) {
        if ("$tEnvItem" -ne "DEV") {
            Write-Host "      Adding Checks-Approvals. Environment  => <<$tEnvName>>"
            $tApprovalDefObj = Get-Content -Raw -Path $C_ENVIRONMENT_CHECK_APPROVAL_JSONTEMPLATE_FILENAME | ConvertFrom-Json
            $tApprovalDefObj.settings.instructions = "Please approve the deployment of the solution for the environment $tEnvName"
            $tApprovalDefObj.settings.approvers[0].id = 'af7e3fe1-3c44-4585-bf46-71382e67b6de'
            $tApprovalDefObj.resource.id = $tEnvObj.id
    
            $tApprovalDefStr = ConvertTo-Json $tApprovalDefObj -Depth 10

            $tApprovalObj = Set-ADOEnvironmentApprovalCheck -Organization:$organization -ProjectName:$project `
                -EnvApprovalCheckJSON:$tApprovalDefStr
        }
    }else {
        Write-Host "      Checks-Approvals exists. Environment  => <<$tEnvName>>"
    }
    if (-not($checkTemplateExists)) {
        Write-Host "      Adding Checks-Template. Environment  => <<$tEnvName>>"
        $tchkTempDefObj = Get-Content -Raw -Path $C_ENVIRONMENT_CHECK_TEMPLATE_JSONTEMPLATE_FILENAME | ConvertFrom-Json
        $tchkTempDefObj.settings.extendsChecks[0].repositoryName = "ADO/pipelines-templates"
        $tchkTempDefObj.settings.extendsChecks[0].repositoryRef = "refs/heads/master"
        $tchkTempDefObj.settings.extendsChecks[0].templatePath = "multistage/java/maven/microservice/template.yml"
        $tchkTempDefObj.resource.id = $tEnvObj.id
        
        $tchkTempDefStr = ConvertTo-Json $tchkTempDefObj -Depth 10

        $tApprovalObj = Set-ADOEnvironmentApprovalCheck -Organization:$organization -ProjectName:$project `
            -EnvApprovalCheckJSON:$tchkTempDefStr
    }else {
        Write-Host "      Checks-Template exists. Environment  => <<$tEnvName>>"
    }
}


Write-Host "**************************************"
Write-Host " Initializing Repository"
Write-Host "**************************************"

Write-Host "Starting initialization of repository <<$repository>>"

if ($repoObj.size -eq 0) {

    Write-Host "Getting YAML Templates"

    # Getting Template repo
    $urlRepoTemplate = Get-ADORepoositoryURL `
        -Organization:$C_ADO_TEMPLATE_ORGANIZATION -ProjectName:$C_ADO_TEMPLATE_PROJECT `
        -RepositoryName:$C_ADO_TEMPLATE_REPONAME

    $pathRepoTemplate = Join-Path $C_STAGING_FOLDER "template"
    New-Item -Path:$pathRepoTemplate -Force -ItemType:Directory
    git clone $urlRepoTemplate $pathRepoTemplate
    if (-not(Test-Path "$pathRepoTemplate\.git")) {
        throw "Template repository does not exists or is invalid"
    }
    Set-Location $pathRepoTemplate
    git checkout $C_ADO_TEMPLATE_BRANCH

    # Destication Repository

    Write-Host "Preparing the Repo sitory to use CI Azure YAML Templates"
    # Getting Project Repo
    $urlRepoProject = Get-ADORepoositoryURL -Organization:$organization -ProjectName:$project `
        -RepositoryName:$repository

    $pathRepoProject = Join-Path $C_STAGING_FOLDER "repoProject"
    New-Item -Path:$pathRepoProject -Force -ItemType:Directory
    
    Set-Location $pathRepoProject
    git init 

    if (-not(Test-Path "$pathRepoProject\.git")) {
        throw "Project repository does not exists or is invalid"
    }# Copying template files
    foreach ($item in $C_ADO_TEMPLATE_FILES) {
        [string]$origFile = Join-Path $pathRepoTemplate $item
        [string]$destFile = Join-Path $pathRepoProject $(Split-Path $item -Leaf)
        
        Copy-Item -Path:$origFile -Destination:$destFile -Force
    }
    
    git config user.email "$username@cn.ca"
    git config user.name "$username" 

    git add .
    git commit -m "Repository Initialized for YAML Template"
    git push --all -u $urlRepoProject

    Set-Location "$C_STAGING_FOLDER\..\"

    if (Test-Path $C_STAGING_FOLDER) {
        Remove-Item $C_STAGING_FOLDER -Force -Recurse
    }

}
else {
    Write-Host "Repository <<$repository>> already initialized "

}

Write-Host "**************************************"
Write-Host "* Creating Variables Groups - Environment Scope"
Write-Host "**************************************"

$tGroupVariables = @{ }
# Environment Variables
foreach ($tEnv in $tEnvList) {
    
    if ($tEnv -like "PROD") {
        $tDumyVariable = @{
            "TBD" = @{"value" = ""; "isSecret" = "false" }
        }    
    }else {
        $tDumyVariable = @{
            "TBD" = @{"value" = ""; "isSecret" = "false" }
        }
    }
    
    $tVarGroup = "DevSecOps_" + $tEnv
    $tVarGroupDescription = "Variable group used in all pipeline for environment $tEnv"
    $tVarGroupDescription += "`nPlease add all enviroment releated variabled defined for token replacement"
    
    $tGroupVariables["$tVarGroup"] = Get-ADOVariableGroup -ProjectName:$project -Organization:$organization -VariableGroupName:$tVarGroup
    if (-not($tGroupVariables["$tVarGroup"])) {
        Write-Host "Creating Variable Group <<$tVarGroup>>"
        $tGroupVariables["$tVarGroup"] = New-ADOVariableGroup -ProjectName:$project -Organization:$organization `
            -VariableGroupName:$tVarGroup -VariableGroupDescriptio:$tVarGroupDescription -Variables:$tDumyVariable
    }

    $tVarGroup = $repository + "_MS_" + $tEnv
    $tVarGroupDescription = "Variable group used in all pipeline for environment $tEnv"
    $tVarGroupDescription += "`nPlease add all enviroment releated variabled defined for token replacement"
    
    $tGroupVariables["$tVarGroup"] = Get-ADOVariableGroup -ProjectName:$project -Organization:$organization -VariableGroupName:$tVarGroup
    if (-not($tGroupVariables["$tVarGroup"])) {
        Write-Host "Creating Variable Group <<$tVarGroup>>"
        $tGroupVariables["$tVarGroup"] = New-ADOVariableGroup -ProjectName:$project -Organization:$organization `
            -VariableGroupName:$tVarGroup -VariableGroupDescriptio:$tVarGroupDescription -Variables:$tDumyVariable
    }

    $tVarGroup = "DevSecOps_" + $repository + "_MS_" + $tEnv
    $tVarGroupDescription = "Variable group used in all pipeline for environment $tEnv"
    $tVarGroupDescription += "`nPlease add all enviroment releated variabled defined for token replacement"
    
    $tGroupVariables["$tVarGroup"] = Get-ADOVariableGroup -ProjectName:$project -Organization:$organization -VariableGroupName:$tVarGroup
    if (-not($tGroupVariables["$tVarGroup"])) {
        Write-Host "Creating Variable Group <<$tVarGroup>>"
        $tGroupVariables["$tVarGroup"] = New-ADOVariableGroup -ProjectName:$project -Organization:$organization `
            -VariableGroupName:$tVarGroup -VariableGroupDescriptio:$tVarGroupDescription -Variables:$tDumyVariable
    }
}

Write-Host "**************************************"
Write-Host "* Setting Permision Varaibles Groups to all pipelines  "
Write-Host "**************************************"

foreach ($varGroupName in $tGroupVariables.Keys) {
    $tGroupVariableObj = $tGroupVariables[$varGroupName]
    Write-Host "Setting premision of Variable Group <<$varGroupName>>"
    $sePermissionObj = Get-Content -Raw -Path $C_ADO_SERVICE_VARIABLEGROUP_PERMISSION_JSONTEMPLATE | ConvertFrom-Json
    $sePermissionObj.id = $tGroupVariableObj.id
    $sePermissionObj.name = $varGroupName
    $tar = @()
    $tar += $sePermissionObj
    $sePermissionStr = ConvertTo-Json $tar -Depth 10
    $sePermissionObj = Set-ADOVariableGroupPermission -Organization:$organization -ProjectName:$project `
        -VariableGoupPermissionJSON:$sePermissionStr
    Write-Host "Variable Group Permission<<$C_ADO_SERVICE_ENDPOINT_NAME>> updated "
}

Write-Host "**************************************"
Write-Host " Creating YAML based Build pipeline"
Write-Host "**************************************"

Write-Host "Starting creation of Build Pipeline <<$buildPipelineName>>"
if (-not($buildPipelineObj)) {
    $builDefObj = Get-Content -Raw -Path $C_BUILD_JSONTEMPLATE_FILENAME | ConvertFrom-Json
    $builDefObj.process.yamlFilename = "azure-pipelines.yml"
    $builDefObj.name = $buildPipelineName
    $builDefObj.repository.id = $repoObj.id
    $builDefObj.repository.url = $repoObj.repository.url
    $builDefObj.repository.name = $repoObj.repository.name
    $builDefObj.path = '\\microservice'
    $builDefStr = ConvertTo-Json $builDefObj -Depth 10
    $builDefObj = New-ADOBuilDefinition -Organization:$organization -ProjectName:$project `
        -BuildDefinitionJSON:$builDefStr
    Write-Host "Build definition <<$buildPipelineName>> created"
}
else {
    Write-Host "Build definition <<$buildPipelineName>> already exists "
}


$tServConPreparedList =@{}


Write-Host "**************************************"
Write-Host " Preparing Service Enpoint   "
Write-Host "**************************************"
# Type ADO
Write-Host "Preparing Service Endpoint - Type ADO = > <<$C_ADO_SERVICE_ENDPOINT_NAME>>"
$servEndPointStr = Get-ADOHelperSrvEndpointObjADO -Name:$C_ADO_SERVICE_ENDPOINT_NAME `
    -Description:"Used to access the ADO pipeline YAML templates in CN-DevOps organization" `
    -URL:$C_ADO_SERVICE_ENDPOINT_URL -ApiToken:$Env:CN_ADO_PASSWORD

$tServConPreparedList[$C_ADO_SERVICE_ENDPOINT_NAME] = @{
    name = $C_ADO_SERVICE_ENDPOINT_NAME
    PreparedObj = $servEndPointStr
}

# Type Generic
$tSrvConnGenericList = @{
    "NexusBaseUrl" = @{
        name = "nexus base Url"
        url = "https://se-nexus01.cn.ca/"
        description = "Nexus Base URL for the CN Internal feed repository"
    }
    "NexusJavaRepository"= @{
        name = "nexus java repository"
        url = "https://se-nexus01.cn.ca/repository/jdk-distributions"
        description = "Nexus Java URL for the CN Internal feed repository"
    }
    "NexusMavenRepository"= @{
        name = "nexus maven repository"
        url = "https://se-nexus01.cn.ca/repository/maven-distributions/"
        description = "Nexus Maven URL for the CN Internal feed repository"
    }
}

foreach ($tSrvConName in $tSrvConnGenericList.keys) {
    $tSrvConObj = $tSrvConnGenericList[$tSrvConName]

    Write-Host "Preparing Service Endpoint Type-Generic = > <<$($tSrvConObj.name)>>"

    $servEndPointStr = [string](Get-ADOHelperSrvEndpointObjGeneric -Name:$tSrvConObj.name `
        -Description:$tSrvConObj.description -URL:$tSrvConObj.url)

    $tServConPreparedList[$tSrvConObj.name] = @{
        name = $tSrvConObj.name
        PreparedObj = $servEndPointStr
    }
    
}
# Type SonarQube
Write-Host "Preparing Service Endpoint - Type SonarQube = > <<$C_ADO_SERVICE_ENDPOINT_SONARQUBE_NAME>>"

$servEndPointStr = Get-ADOHelperSrvEndpointObjSonarQube -Name:$C_ADO_SERVICE_ENDPOINT_SONARQUBE_NAME `
    -Description:"Used to access the SonarQube Server for code analisys." `
    -URL:$Env:CN_APP_SONARQUBE_URL -ApiToken:$Env:CN_APP_SONARQUBE_TOKEN

$tServConPreparedList[$C_ADO_SERVICE_ENDPOINT_SONARQUBE_NAME] = @{
    name = $C_ADO_SERVICE_ENDPOINT_SONARQUBE_NAME
    PreparedObj = $servEndPointStr
}

$servEndPointStr = Get-ADOHelperSrvEndpointObjBlackduck -Name:$C_ADO_SERVICE_ENDPOINT_BLACKDUCK_NAME `
    -Description:"Used to access the Blackduck Server for code analisys." `
    -URL:$Env:CN_APP_BLACKDUCK_URL -ApiToken:$Env:CN_APP_BLACKDUCK_TOKEN

$tServConPreparedList[$C_ADO_SERVICE_ENDPOINT_BLACKDUCK_NAME] = @{
    name = $C_ADO_SERVICE_ENDPOINT_BLACKDUCK_NAME
    PreparedObj = $servEndPointStr
}

Write-Host "**************************************"
Write-Host " Creating ALL Services Enpoint  "
Write-Host "**************************************"

foreach ($itemName in $tServConPreparedList.Keys) {
    $tObj = $tServConPreparedList[$itemName]
    

    Set-ADOHelperSrvEndpoint -Organization:$organization -Project:$project `
        -ServiceEndpointName:$tObj.name -ServiceEndpointStrObj:$tObj.PreparedObj
}