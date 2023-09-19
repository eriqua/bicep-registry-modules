function Publish-ToPublicBicepRegistry {


    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplateFilePath,

        [Parameter(Mandatory = $true)]
        [secureString] $PublicRegistryServer
    )

    # Load used functions
    . (Join-Path $PSScriptRoot 'Test-ModuleQualifiesForPublish.ps1')
    . (Join-Path $PSScriptRoot 'Get-ModuleTargetVersion.ps1')
    . (Join-Path $PSScriptRoot 'Get-BRMRepositoryName.ps1')
    . (Join-Path $PSScriptRoot 'Get-ModuleReadmeLink.ps1')
    . (Join-Path $PSScriptRoot 'Publish-ModuleToPrivateBicepRegistry.ps1')

    $moduleRelativePath = Split-Path $TemplateFilePath -Parent
    $moduleJsonFilePath = Join-Path $moduleRelativePath 'main.json'

    # 1. Test if module qualifies for publishing
    if (-not (Test-ModuleQualifiesForPublish -ModuleRelativePath $moduleRelativePath)) {
        Write-Verbose "No changes detected. Skipping publishing" -Verbose
        return
    }

    # 2. Calculate the version that we would publish with
    $targetVersion = Get-ModuleTargetVersion -ModuleRelativePath $moduleRelativePath

    # 3. Get Target Published Module Name
    $publishedModuleName = Get-BRMRepositoryName -TemplateFilePath $TemplateFilePath

    # 4. Get the documentation link
    $documentationUri = Get-ModuleReadmeLink -ModuleRelativePath $moduleRelativePath

    # 5. Replace telemetry version value (in JSON)
    $tokenConfiguration = @{
        FilePathList = @($moduleJsonFilePath)
        Tokens       = @{
            'ModuleTelemetryVersion' = $targetVersion # TODO : Check if we need to replace '.' with '-'
        }
        TokenPrefix  = '[['
        TokenSuffix  = ']]'
    }
    $null = Convert-TokensInFileList @tokenConfiguration

    #################
    ##   Publish   ##
    #################
    $plainPublicRegistryServer = ConvertFrom-SecureString $PublicRegistryServer -AsPlainText

    $publishInput = @(
        $moduleJsonFilePath
        '--target', ("br:{0}/public/bicep/{1}:{2}" -f $plainPublicRegistryServer, $publishedModuleName, $targetVersion)
        '--documentationUri', $documentationUri
        '--force'
    )
    # bicep publish @publishInput
}