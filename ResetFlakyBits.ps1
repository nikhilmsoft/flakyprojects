param (
    [string] [Parameter(Mandatory = $true)] $AccountName,
    [string] [Parameter(Mandatory = $true)] $TeamProject,
    [string] [Parameter(Mandatory = $true)] $AccessToken,
    [string] [Parameter(Mandatory = $true)] $BuildNumber
)

function Write-UsageMessage
{
   Write-Host 'Syntax: .\ResetFlakyBits.ps1 -AccountName <account name> -TeamProject <project name> -AccessToken <Pat token> -BuildNumber <build number>'
   
   Write-Host 'Example: .\ResetFlakyBits.ps1 -AccountName "testplan" -TeamProject "testplan" -AccessToken "<pat-token>" -BuildNumber "8'
}

function Find-Flaky
{
    param (
    [PSObject[]] [Parameter(Mandatory = $true)] $resultModels,
    [string] [Parameter(Mandatory = $true)] $fieldName,
    [string] [Parameter(Mandatory = $true)] $fieldValue
    )

    begin
    {
        $filteredSequence = @()
    }

    process
    {
      Foreach ($resultModel in $resultModels) 
      {
       if($resultModel.customFields -ne $null)
       {
         $resultModel.customFields | Where-Object { $_.fieldName.Contains($fieldName) -and $_.value -eq $fieldValue } | ForEach-Object { $filteredSequence += $resultModel }
       }
      }
    }

    end
    {
        return $filteredSequence
    }
}

if ((-not $CollectionUri) -or (-not $TeamProject) -or (-not $AccessToken))
{
   Write-UsageMessage
   throw "Incorrect arguments"
}

Write-Host "Parameters:"
Write-Host "AccountName: $AccountName"
Write-Host "TeamProject: $TeamProject"
Write-Host "AccessToken: $AccessToken"
Write-Host "BuildNumber: $BuildNumber"

$basicAuth = ("{0}:{1}" -f "dummy", $AccessToken)
$basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
$basicAuth = [System.Convert]::ToBase64String($basicAuth)
$headers = @{Authorization=("Basic {0}" -f $basicAuth)} + @{"Accept"="application/json;api-version=2.1-preview.2"}

$Url = "https://dev.azure.com/$AccountName/$TeamProject/_apis/test/runs?buildUri=vstfs:///Build/Build/$BuildNumber"
Write-Host "Querying total run with build number $BuildNumber"
$response = Invoke-RestMethod -Uri $Url -headers $headers -ContentType 'application/json' -Method Get
Write-Host "response: Total run count found with given build number is" $response.count

for($runCount = 0;$runCount -lt $response.count;$runCount++)
{
    $runModel = $response.value[$runCount]
    Write-Host "Processing Run Id :" $runModel.id
    
    $RunUrl = "https://dev.azure.com/$AccountName/$TeamProject/_apis/test/runs/"+$runModel.id
    Write-Host "Getting branch Name for run id:" $runModel.id
    $runresponse = Invoke-RestMethod -Uri $RunUrl -headers $headers -ContentType 'application/json' -Method Get
    
    if([string]::IsNullOrEmpty($runresponse.buildConfiguration.targetBranchName))
    {
     $branchName = $runresponse.buildConfiguration.branchName
    }
    else
    {
     $branchName = $runresponse.buildConfiguration.targetBranchName
    }
    Write-Host "branch name is" $branchName

    $ResultUrl = "https://dev.azure.com/$AccountName/$TeamProject/_apis/test/runs/"+$runModel.id+"/results"
    Write-Host "Getting Results from Run Id:" $runModel.id ...
    $resultresponse = Invoke-RestMethod -Uri $ResultUrl -headers $headers -ContentType 'application/json' -Method Get
    
    Write-Host "response: Total result count found with given run id : " $resultresponse.count
    
    if($resultresponse.count -gt 0)
    {
        Write-Host "Processing Results to find flaky bits"
        
        $flakyresults = Find-Flaky -resultModels $resultresponse.value -fieldName 'IsTestResultFlaky' -fieldValue 'true'
        Write-Host "Total flaky results found : " $flakyresults.count
        
        Write-Host "Processing flaky testcase refs: "
        Foreach ($flakyresult in $flakyresults) 
        {
         $jsonbody = '{ "flakyIdentifiers":[{"branchName":"'+$branchName+'","isFlaky": false}]}'
         $FlakyUrl = "https://vstmr.dev.azure.com/$AccountName/$TeamProject/_apis/testresults/results/ResultMetaData/"+$flakyresult.testCaseReferenceId+"?api-version=5.2-preview.3"
         Write-Host "UnMarking Flaky Testcaseref id: " $flakyresult.testCaseReferenceId
         $FlakyResponse = Invoke-RestMethod -Uri $FlakyUrl -headers $headers -ContentType 'application/json' -Method Patch -Body $jsonbody
         Write-Host "Testcaseref id:" $FlakyResponse.testCaseReferenceId " is unmarked flaky"
        }
    }
    
}
