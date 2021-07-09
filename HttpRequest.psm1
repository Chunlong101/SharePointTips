#SUMMARY: Module for making REST API calls to SharePoint server (OnPrem or SPO).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"


#region Http Request
function Send-HttpRequest
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Method,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "UriComponents")]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath = "_api",

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [ValidateNotNullOrEmpty()]
        [string] $HostName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [ValidateNotNullOrEmpty()]
        [string] $Scheme = [System.Uri]::UriSchemeHttp,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port = 80,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Uri")]
        [ValidateNotNull()]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $Content = [String]::Empty,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $ContentType = "application/json",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $Accept = "application/json",

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [hashtable] $Headers = @{},

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials = $true,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($Echo)
    {
        Out-Command -Parameters $PSBoundParameters
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        "UriComponents"
        {
            if (Test-AbsoluteUri -Url $Path)
            {
                $Uri = New-Object -TypeName System.Uri($Path)
            }
            else
            {
                $ub = New-Object -TypeName System.UriBuilder
                $ub.Scheme = $Scheme
                $ub.Host = $HostName
                $ub.Port = $Port
                $ub.Path = Get-UriPath -Path $Path -Site $Site -ApiPath $ApiPath
                $ub.Query = $Query
                $ub.Fragment = $Fragment

                $Uri = $ub.Uri
            }
            break
        }
    }

    $verboseOutput = $PSBoundParameters["Verbose"] -eq $true -or $VerbosePreference -eq "Continue"

    # Request
    $request = [System.Net.WebRequest]::CreateHttp($Uri)
    $request.Method = $Method.ToUpper()

    # Add Headers
    $nvc = New-Object -TypeName System.Collections.Specialized.NameValueCollection
    $Headers.GetEnumerator() | ForEach-Object {$nvc.Add($_.Key, $_.Value)}
    $request.Headers.Add($nvc)

    # Accept
    $request.Accept = if ($AcceptXml) {"application/xml"} else {$Accept}
    if ($ODataVerbose -and $request.Accept -eq "application/json")
    {
        $request.Accept += ";odata=verbose"
    }

    # Authentication
    $request.PreAuthenticate = $true
    if (-not [String]::IsNullOrEmpty($AuthCookie))
    {
        $request.Headers.Add("Cookie", $AuthCookie)
    }
    elseif ($UseDefaultCredentials)
    {
        $request.UseDefaultCredentials = $true
    }
    elseif ($Credentials -ne $null)
    {
        $request.Credentials = $Credentials
    }
    else
    {
        $request.PreAuthenticate = $false
    }

    # Request body
    $request.ContentLength = $Content.Length
    if ($request.ContentLength -gt 0)
    {
        $request.ContentType = $ContentType
        if ($ODataVerbose -and $request.ContentType -eq "application/json")
        {
            $request.ContentType += ";odata=verbose"
        }

        Write-Stream -Content $Content -Stream $request.GetRequestStream()
    }

    if ($verboseOutput)
    {
        $sb = New-Object -TypeName System.Text.StringBuilder
        $null = $sb.AppendLine()
        Add-Trace `
            -Buffer $sb `
            -Method $request.Method `
            -Uri $request.RequestUri `
            -Headers $request.Headers `
            -Content $Content
        Write-Trace `
            -Buffer $sb.ToString()
    }

    # Reponse
    $response = $null
    try
    {
        $responseBody = $null
        $response = $request.GetResponse()

        if (-not $OutputResponse -or $verboseOutput)
        {
            if (-not $OutputResponse)
            {
                $responseBody = Read-ResponseBody -Response $response
            }

            if ($verboseOutput)
            {
                $formattedOutput = Format-Output -Content $responseBody -ContentType $response.ContentType
                $sb = New-Object -TypeName System.Text.StringBuilder
                $null = $sb.AppendLine()
                Add-Trace `
                    -Buffer $sb `
                    -StatusCode $response.StatusCode `
                    -StatusDescription $response.StatusDescription `
                    -Status "Success" `
                    -Headers $response.Headers `
                    -Content $formattedOutput
                Write-Trace `
                    -Buffer $sb.ToString()
            }
        }

        # Output
        if ($OutputResponse)
        {
            return $response
        }
        elseif (-not [String]::IsNullOrEmpty($responseBody))
        {
            if ($OutputRaw)
            {
                return $responseBody
            }
            elseif ($response.ContentType -match "/json;?")
            {
                try {return $responseBody | ConvertFrom-Json} catch {return $responseBody}
            }
            elseif ($response.ContentType -match "/.*?xml;?")
            {
                try {return [xml]$responseBody} catch {return $responseBody}
            }
            else
            {
                return $responseBody
            }
        }
    }
    catch
    {
        if (-not $Quiet -and $_.Exception.InnerException -ne $null -and $_.Exception.InnerException.GetType().FullName -eq "System.Net.WebException" -and $_.Exception.InnerException.Response -ne $null)
        {
            $errorResponse = $_.Exception.InnerException.Response
            $errorResponseBody = Read-ResponseBody -Response $errorResponse
            $errorFormattedOutput = Format-Output -Content $errorResponseBody -ContentType $errorResponse.ContentType

            if ($ErrorOnly)
            {
                Write-Trace `
                    -Buffer $errorFormattedOutput `
                    -WriteToConsole `
                    -ForegroundColor Yellow
            }
            else
            {
                $sb = New-Object -TypeName System.Text.StringBuilder
                if (-not $verboseOutput)
                {
                    Add-Trace `
                        -Buffer $sb `
                        -Method $errorResponse.Method `
                        -Uri $errorResponse.ResponseUri
                }
                Add-Trace `
                    -Buffer $sb `
                    -StatusCode $errorResponse.StatusCode `
                    -StatusDescription $errorResponse.StatusDescription `
                    -Status $_.Exception.InnerException.Status `
                    -Headers $errorResponse.Headers `
                    -Content $errorFormattedOutput
                Write-Trace `
                    -Buffer $sb.ToString().TrimEnd("`r`n") `
                    -WriteToConsole `
                    -ForegroundColor Yellow
            }
        }

        throw $_
    }
    finally
    {
        if (-not $OutputResponse -and $response -ne $null)
        {
            $response.Close()
        }
    }
}

function Test-AbsoluteUri
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string] $Url
    )

    if ([String]::IsNullOrEmpty($Url))
    {
        return $false
    }

    try
    {
        $uri = New-Object -TypeName System.Uri($Url, [System.UriKind]::RelativeOrAbsolute)
        return $uri.IsAbsoluteUri
    }
    catch
    {
        return $false
    }
}

function Get-UriPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [string] $Path,

        [Parameter(Mandatory = $false)]
        [string] $Site,

        [Parameter(Mandatory = $false)]
        [string] $ApiPath
    )

    if ($Path -ne $null)
    {
        $Path = $Path.Trim("/")
    }
    if ($Site -ne $null)
    {
        $Site = $Site.Trim("/")
    }

    if ($Path -notlike "_*" -and $Path -notlike "*/_*")
    {
        $Path = "$ApiPath/$Path".Trim("/")
    }

    return "/" + "$Site/$Path".Trim("/")
}

function Out-Command
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [hashtable] $Parameters
    )

    if ($Parameters -eq $null -or $Parameters.Count -eq 0)
    {
        return
    }

    $sb = New-Object -TypeName System.Text.StringBuilder

    foreach ($paramName in [System.Enum]::GetNames([RequestParameter]))
    {
        $value = $Parameters[$paramName]

        if (-not $Parameters.ContainsKey($paramName) -or
            $paramName -eq [RequestParameter]::Headers -or
            $paramName -eq [RequestParameter]::Echo -or
            $value -eq (Get-RequestParameterDefault -Parameter $paramName -Function Send_HttpRequest -ValueOnly))
        {
            continue
        }

        if ($paramName -eq [RequestParameter]::Method)
        {
            if (-not $MyInvocation.MyCommand.Module.ExportedCommands.ContainsKey($value))
            {
                $null = $sb.Append('Send-HttpRequest ')
            }
            $null = $sb.Append($value)
        }
        elseif ($paramName -in ([RequestParameter]::Path, [RequestParameter]::Query, [RequestParameter]::Fragment))
        {
            if ($paramName -eq [RequestParameter]::Path)
            {
                $null = $sb.AppendFormat(' "{0}"', $value)
            }
            else
            {
                $null = $sb.AppendFormat(' -{0} "{1}"', $paramName, $value)
            }
        }
        elseif ($value -is [int])
        {
            $null = $sb.AppendFormat(' -{0} {1}', $paramName, $value)
        }
        elseif ($value -is [switch])
        {
            if ($value -eq $true)
            {
                $null = $sb.AppendFormat(' -{0}', $paramName)
            }
            else
            {
                $null = $sb.AppendFormat(' -{0}:${1}', $paramName, $value)
            }
        }
        else
        {
            $null = $sb.AppendFormat(' -{0} "{1}"', $paramName, $(if (Test-PlainText -Text $value) {$value} else {}))
        }
    }

    $null = $sb.Replace('`', '``')
    $null = $sb.Replace('$', '`$')

    Write-Host -ForegroundColor DarkGray $sb.ToString()
}

Set-Alias -Scope Global -Name Escape-String -Value Get-EscapedString
function Get-EscapedString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [string] $Text,

        [Parameter(Mandatory = $false)]
        [char[]] $Exclude,

        [Parameter(Mandatory = $false)]
        [switch] $Json
    )

    Process
    {
        if ([String]::IsNullOrEmpty($Text))
        {
            return
        }

        $sb = New-Object -TypeName System.Text.StringBuilder($Text)
        '#$&+,;=@'.ToCharArray() | Where-Object {$_ -notin $Exclude} | ForEach-Object {$null = $sb.Replace("$_", [System.Uri]::HexEscape($_))}

        if ("'" -notin $Exclude)
        {
            if ($Json)
            {
                $null = $sb.Replace("'", [System.Uri]::HexEscape("\") + [System.Uri]::HexEscape("'"))
            }
            else
            {
                $null = $sb.Replace("'", "''")
            }
        }

        return $sb.ToString()
    }
}

function Add-Trace
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Text.StringBuilder] $Buffer,

        [Parameter(Mandatory = $true, ParameterSetName = "Request")]
        [string] $Method,

        [Parameter(Mandatory = $true, ParameterSetName = "Request")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $true, ParameterSetName = "Response")]
        [System.Net.HttpStatusCode] $StatusCode,

        [Parameter(Mandatory = $true, ParameterSetName = "Response")]
        [string] $StatusDescription,

        [Parameter(Mandatory = $true, ParameterSetName = "Response")]
        [string] $Status,

        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.NameValueCollection] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        "Request"
        {
            $null = $Buffer.AppendLine(('{0:o}    REQUEST: {1} {2}' -f [DateTime]::Now, $Method, $Uri.AbsoluteUri))
            break
        }

        "Response"
        {
            $null = $Buffer.AppendLine(('{0:o}    RESPONSE: ({1}) {2} [{3}]' -f [DateTime]::Now, $StatusCode.value__, $StatusDescription, $Status))
            break
        }
    }

    $contentLength = if ($Content -eq $null) {0} else {$Content.Length}

    if ($Headers -ne $null -and $Headers.Count -gt 0)
    {
        $null = $Buffer.AppendLine("{")
        $Headers.AllKeys | Sort-Object | ForEach-Object {$null = $Buffer.AppendLine(("    `"{0}`" : {1}" -f $_, $Headers.Get($_)))}
        $null = $Buffer.AppendLine(("    Content-Length : {0}" -f $ContentLength))
        $null = $Buffer.AppendLine("}")
    }

    if ($contentLength -gt 0 -and (Test-PlainText -Text $content))
    {
        $null = $Buffer.AppendLine("[")
        $null = $Buffer.AppendLine($Content)
        $null = $Buffer.AppendLine("]")
    }

    if ($PassThru)
    {
        return $Buffer
    }
}

function Write-Trace
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNull()]
        [string[]] $Buffer = @(),

        [Parameter(Mandatory = $false, ParameterSetName = "ConsoleOutput")]
        [switch] $WriteToConsole,

        [Parameter(Mandatory = $false, ParameterSetName = "ConsoleOutput")]
        [System.ConsoleColor] $ForegroundColor = [System.ConsoleColor]::Yellow
    )

    if ($WriteToConsole)
    {
        $Buffer | Write-Host -ForegroundColor $ForegroundColor
    }
    else
    {
        $Buffer | Write-Verbose -Verbose
    }
}
#endregion Http Request


#region Form Digest
function Test-FormDigestHeader
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false)]
        [hashtable] $Headers
    )

    return $Headers -ne $null -and $Headers.ContainsKey("X-RequestDigest")
}

function Get-FormDigestHeader
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $true, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        "UriComponents"
        {
            $PSBoundParameters["Path"] = "contextinfo"
            break
        }

        "Uri"
        {
            if (($index = $Uri.AbsolutePath.IndexOf("/_")) -gt -1)
            {
                $Site = $Uri.AbsolutePath.Substring(0, $index)
            }
            else
            {
                $Site = $null
            }

            $ub = New-Object -TypeName System.UriBuilder($Uri.Scheme, $Uri.Host, $Uri.Port, (Get-UriPath -Path "contextinfo" -Site $Site))
            $PSBoundParameters["Uri"] = $ub.Uri
            break
        }
    }

    $ctx = Send-HttpRequest @PSBoundParameters `
        -Method "POST" `
        -Accept "application/json" `
        -Headers @{"X-RequestDigest" = $null} `
        -ODataVerbose:$false `
        -AcceptXml:$false `
        -OutputRaw:$false `
        -OutputResponse:$false `
        -Echo:$false

    if ($ctx -ne $null -and ($ctx | Get-Member -Name FormDigestValue) -ne $null)
    {
        $digest = $ctx.FormDigestValue
    }
    else
    {
        $digest = $null
    }

    return @{"X-RequestDigest" = $digest}
}

function Get-FormDigestHeaderParameterNames
{
    [CmdletBinding()]
    param()

    return @(
        "Site"
        "HostName"
        "Scheme"
        "Port"
        "Uri"
        "AuthCookie"
        "Credentials"
        "UseDefaultCredentials"
        "ErrorOnly"
        "Quiet"
    )
}
#endregion


#region List Functions
function Get-List
{
    [CmdletBinding(DefaultParameterSetName="Name")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "Name")]
        [string[]] $Name,

        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Id")]
        [ValidateScript({$_ -ne $null -and $_ -ne [guid]::Empty})]
        [guid] $Id,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select,

        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [switch] $Exact
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        switch ($PSCmdlet.ParameterSetName)
        {
            "Name"
            {
                $filter = "`$filter="
                $filter += ($Name | Where-Object {-not [String]::IsNullOrEmpty($_)} | Get-EscapedString | ForEach-Object {if ($Exact) {"Title eq '${_}'"} else {"startswith(Title,'${_}')"}}) -join " or "

                return GET "Lists" -Query "${filter}&${queryClause}" -Echo:$echo | ForEach-Object {if ((Get-Member -InputObject $_ -Name value) -ne $null) {$_.value} else {$_}}
            }

            "Id"
            {
                return GET "Lists/GetById(@id)" -Query "@id=guid'${Id}'&${queryClause}" -Echo:$echo
            }
        }
    }
}

function Add-List
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        # ListTemplateTypeKind value from Get-ListTemplates
        # E.g.: DocumentLibrary = 101, Calendar = 106
        [Parameter(Mandatory = $false, Position = 1)]
        [int] $TemplateType = 101,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        $Name = Get-EscapedString -Text $Name -Json

        return POST "Lists/Add(parameters=@parameters)" -Query "@parameters={'Title':'${Name}','TemplateType':${TemplateType}}&${queryClause}" -Echo:$echo
    }
}

function Remove-List
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [guid] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        DELETE "Lists/GetById(@id)" -Query "@id=guid'${Id}'" -Echo:$echo
    }
}

function Get-ListTemplates
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string[]] $Name,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select,

        [Parameter(Mandatory = $false)]
        [switch] $Exact
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        $filter = "`$filter="
        $filter += ($Name | Where-Object {-not [String]::IsNullOrEmpty($_)} | Get-EscapedString | ForEach-Object {if ($Exact) {"Name eq '${_}'"} else {"startswith(Name,'${_}')"}}) -join " or "

        return GET "Web/ListTemplates" -Query "${filter}&${queryClause}" -Echo:$echo | ForEach-Object {if ((Get-Member -InputObject $_ -Name value) -ne $null) {$_.value} else {$_}}
    }
}

function Get-ListSyncPolicy
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [guid] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        return GET "SPFileSync/Sync/${Id}/Policy" -Accept Application/Web3s+xml -Raw -Echo:$echo
    }
}
#endregion


#region Folder Functions
function Get-Folder
{
    [CmdletBinding(DefaultParameterSetName="Name")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "Name")]
        [string[]] $Name,

        # Parent Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Name")]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $ParentFolderIdOrUrl,

        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Id")]
        [ValidateScript({$_ -ne $null -and $_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $false, ParameterSetName = "ServerRelativeUrl")]
        [string] $ServerRelativeUrl,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select,

        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [switch] $Exact
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        switch ($PSCmdlet.ParameterSetName)
        {
            "Name"
            {
                $filter = "`$filter="
                $filter += ($Name | Where-Object {-not [String]::IsNullOrEmpty($_)} | Get-EscapedString | ForEach-Object {if ($Exact) {"Name eq '${_}'"} else {"startswith(Name,'${_}')"}}) -join " or "

                if (($ParentFolderIdOrUrl -as [guid]) -ne $null)
                {
                    $parentPath = "Web/GetFolderById(@parentId)"
                    $parentQuery = "@parentId=guid'$(${ParentFolderIdOrUrl} -as [guid])'"
                }
                else
                {
                    $parentPath = "Web/GetFolderByServerRelativePath(decodedUrl=@parentDecodedUrl)"
                    $parentQuery = "@parentDecodedUrl='$(Get-EscapedString -Text ${ParentFolderIdOrUrl})'"
                }

                return GET "${parentPath}/Folders" -Query "${parentQuery}&${filter}&${queryClause}" -Echo:$echo | ForEach-Object {if ((Get-Member -InputObject $_ -Name value) -ne $null) {$_.value} else {$_}}
            }

            "Id"
            {
                return GET "Web/GetFolderById(@id)" -Query "@id=guid'${Id}'&${queryClause}" -Echo:$echo
            }

            "ServerRelativeUrl"
            {
                $ServerRelativeUrl = Get-EscapedString -Text $ServerRelativeUrl

                return GET "Web/GetFolderByServerRelativePath(decodedUrl=@decodedUrl)" -Query "@decodedUrl='${ServerRelativeUrl}'&${queryClause}" -Echo:$echo
            }
        }
    }
}

function Add-Folder
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        # Parent Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $ParentFolderIdOrUrl,

        [Parameter(Mandatory = $false)]
        [switch] $Overwrite,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        $Name = Get-EscapedString -Text $Name

        if (($ParentFolderIdOrUrl -as [guid]) -ne $null)
        {
            $parentPath = "Web/GetFolderById(@parentId)"
            $parentQuery = "@parentId=guid'$(${ParentFolderIdOrUrl} -as [guid])'"
        }
        else
        {
            $parentPath = "Web/GetFolderByServerRelativePath(decodedUrl=@parentDecodedUrl)"
            $parentQuery = "@parentDecodedUrl='$(Get-EscapedString -Text ${ParentFolderIdOrUrl})'"
        }

        return POST "${parentPath}/Folders/AddUsingPath(decodedUrl=@decodedUrl,overwrite=@overwrite)" -Query "${parentQuery}&@decodedUrl='${Name}'&@overwrite=$(${Overwrite}.ToString().ToLower())&${queryClause}" -Echo:$echo
    }
}

function Move-Folder
{
    [CmdletBinding(DefaultParameterSetName="Folder")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        # Destination Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Folder")]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $DestinationFolderIdOrUrl,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "FullPath")]
        [string] $DestinationServerRelativeUrl
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            "Folder"
            {
                $sourceFolderName = Get-Folder -Id $Id | Select-Object -ExpandProperty Name

                if (($DestinationFolderIdOrUrl -as [guid]) -ne $null)
                {
                    $destinationFolderUrl = Get-Folder -Id $DestinationFolderIdOrUrl -Select ServerRelativeUrl | Select-Object -ExpandProperty ServerRelativeUrl
                }
                else
                {
                    $destinationFolderUrl = $DestinationFolderIdOrUrl
                }

                $DestinationServerRelativeUrl = Get-EscapedString -Text "${destinationFolderUrl}/${sourceFolderName}"
                break
            }

            "FullPath"
            {
                $DestinationServerRelativeUrl = Get-EscapedString -Text $DestinationServerRelativeUrl
                break
            }
        }

        POST "Web/GetFolderById(@id)/MoveToUsingPath(decodedUrl=@newPath)" -Query "@id=guid'${Id}'&@newPath='${DestinationServerRelativeUrl}'" -Echo:$echo | Out-Null
    }
}

function Rename-Folder
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $NewName
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $parentFolderUrl = Get-Folder -Id $Id -Expand ParentFolder -Select ParentFolder/ServerRelativeUrl | Select-Object -ExpandProperty ParentFolder | Select-Object -ExpandProperty ServerRelativeUrl
        $destinationServerRelativeUrl = Get-EscapedString -Text "${parentFolderUrl}/${NewName}"

        POST "Web/GetFolderById(@id)/MoveToUsingPath(decodedUrl=@newPath)" -Query "@id=guid'${Id}'&@newPath='${destinationServerRelativeUrl}'" -Echo:$echo | Out-Null
    }
}

function Remove-Folder
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        DELETE "Web/GetFolderById(@id)" -Query "@id=guid'${Id}'" -Echo:$echo
    }
}

function Get-FolderSyncProperties
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateScript({$_ -ne $null -and $_ -ne [guid]::Empty})]
        [guid] $ListId
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        if ($ListId -eq $null)
        {
            $ListId = Get-Folder -Id $Id -Expand Properties -Select Properties/vti_x005f_listname |
                Select-Object -ExpandProperty Properties |
                Where-Object {(Get-Member -InputObject $_ -Name vti_x005f_listname) -ne $null} |
                Select-Object -ExpandProperty vti_x005f_listname
        }

        if ($ListId -ne $null)
        {
            return GET "SPFileSync/Sync/${ListId}/Items/${Id}" -Accept Application/Web3s+xml -Raw -Echo:$echo
        }
    }
}
#endregion


#region File Functions
function Get-File
{
    [CmdletBinding(DefaultParameterSetName="Name")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "Name")]
        [string[]] $Name,

        # Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Name")]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $ParentFolderIdOrUrl,

        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Id")]
        [ValidateScript({$_ -ne $null -and $_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $false, ParameterSetName = "ServerRelativeUrl")]
        [string] $ServerRelativeUrl,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select,

        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [switch] $Exact
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        switch ($PSCmdlet.ParameterSetName)
        {
            "Name"
            {
                $filter = "`$filter="
                $filter += ($Name | Where-Object {-not [String]::IsNullOrEmpty($_)} | Get-EscapedString | ForEach-Object {if ($Exact) {"Name eq '${_}'"} else {"startswith(Name,'${_}')"}}) -join " or "

                if (($ParentFolderIdOrUrl -as [guid]) -ne $null)
                {
                    $folderPath = "Web/GetFolderById(@folderId)"
                    $folderQuery = "@folderId=guid'$(${ParentFolderIdOrUrl} -as [guid])'"
                }
                else
                {
                    $folderPath = "Web/GetFolderByServerRelativePath(decodedUrl=@folderDecodedUrl)"
                    $folderQuery = "@folderDecodedUrl='$(Get-EscapedString -Text ${ParentFolderIdOrUrl})'"
                }

                return GET "${folderPath}/Files" -Query "${folderQuery}&${filter}&${queryClause}" -Echo:$echo | ForEach-Object {if ((Get-Member -InputObject $_ -Name value) -ne $null) {$_.value} else {$_}}
            }

            "Id"
            {
                return GET "Web/GetFileById(@id)" -Query "@id=guid'${Id}'&${queryClause}" -Echo:$echo
            }

            "ServerRelativeUrl"
            {
                $ServerRelativeUrl = Get-EscapedString -Text $ServerRelativeUrl

                return GET "Web/GetFileByServerRelativePath(decodedUrl=@decodedUrl)" -Query "@decodedUrl='${ServerRelativeUrl}'&${queryClause}" -Echo:$echo
            }
        }
    }
}

function Add-File
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        # Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $ParentFolderIdOrUrl,

        [Parameter(Mandatory = $false, Position = 2)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [switch] $Overwrite,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        $Name = Get-EscapedString -Text $Name

        if (($ParentFolderIdOrUrl -as [guid]) -ne $null)
        {
            $folderPath = "Web/GetFolderById(@folderId)"
            $folderQuery = "@folderId=guid'$(${ParentFolderIdOrUrl} -as [guid])'"
        }
        else
        {
            $folderPath = "Web/GetFolderByServerRelativePath(decodedUrl=@folderDecodedUrl)"
            $folderQuery = "@folderDecodedUrl='$(Get-EscapedString -Text ${ParentFolderIdOrUrl})'"
        }

        return POST "${folderPath}/Files/AddUsingPath(decodedUrl=@decodedUrl,overwrite=@overwrite)" -Query "${folderQuery}&@decodedUrl='${Name}'&@overwrite=$(${Overwrite}.ToString().ToLower())&${queryClause}" -Content $Content -Echo:$echo
    }
}

function Update-File
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Content
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        POST "Web/GetFileById(@id)/SaveBinaryStream" -Query "@id=guid'${Id}'" -Content $Content -Echo:$echo | Out-Null
    }
}

function Move-File
{
    [CmdletBinding(DefaultParameterSetName="Folder")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        # Destination Folder UniqueId or ServerRelativeUrl
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "Folder")]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {$true}})]
        [object] $DestinationFolderIdOrUrl,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = "FullPath")]
        [string] $DestinationServerRelativeUrl,

        [Parameter(Mandatory = $false)]
        [switch] $Overwrite
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            "Folder"
            {
                $sourceFileName = Get-File -Id $Id | Select-Object -ExpandProperty Name

                if (($DestinationFolderIdOrUrl -as [guid]) -ne $null)
                {
                    $destinationFolderUrl = Get-Folder -Id $DestinationFolderIdOrUrl -Select ServerRelativeUrl | Select-Object -ExpandProperty ServerRelativeUrl
                }
                else
                {
                    $destinationFolderUrl = $DestinationFolderIdOrUrl
                }

                $DestinationServerRelativeUrl = Get-EscapedString -Text "${destinationFolderUrl}/${sourceFileName}"
                break
            }

            "FullPath"
            {
                $DestinationServerRelativeUrl = Get-EscapedString -Text $DestinationServerRelativeUrl
                break
            }
        }

        POST "Web/GetFileById(@id)/MoveToUsingPath(decodedUrl=@newPath,moveOperations=@moveOperations)" -Query "@id=guid'${Id}'&@newPath='${DestinationServerRelativeUrl}'&@moveOperations=$([int][bool]${Overwrite})" -Echo:$echo | Out-Null
    }
}

function Rename-File
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $NewName,

        [Parameter(Mandatory = $false)]
        [switch] $Overwrite
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $parentFolderUrl = Get-Folder -Id $Id -Expand ParentFolder -Select ParentFolder/ServerRelativeUrl | Select-Object -ExpandProperty ParentFolder | Select-Object -ExpandProperty ServerRelativeUrl
        $destinationServerRelativeUrl = Get-EscapedString -Text "${parentFolderUrl}/${NewName}"

        POST "Web/GetFileById(@id)/MoveToUsingPath(decodedUrl=@newPath,moveOperations=@moveOperations)" -Query "@id=guid'${Id}'&@newPath='${destinationServerRelativeUrl}'&@moveOperations=$([int][bool]${Overwrite})" -Echo:$echo | Out-Null
    }
}

function Remove-File
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        DELETE "Web/GetFileById(@id)" -Query "@id=guid'${Id}'" -Echo:$echo
    }
}

Set-Alias -Scope Global -Name Download-File -Value Receive-File
function Receive-File
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        return GET "_layouts/15/download.aspx" -Query "UniqueId={${Id}}" -Echo:$echo
    }
}

function Get-FileSyncProperties
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({$_ -ne [guid]::Empty})]
        [Alias("UniqueId")]
        [guid] $Id,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateScript({$_ -ne $null -and $_ -ne [guid]::Empty})]
        [guid] $ListId
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        if ($ListId -eq $null)
        {
            $parentId = Get-File -Id $Id -Expand Properties -Select Properties/vti_x005f_parentid |
                Select-Object -ExpandProperty Properties |
                Select-Object -ExpandProperty vti_x005f_parentid

            $ListId = Get-Folder -Id $parentId -Expand Properties -Select Properties/vti_x005f_listname |
                Select-Object -ExpandProperty Properties |
                Where-Object {(Get-Member -InputObject $_ -Name vti_x005f_listname) -ne $null} |
                Select-Object -ExpandProperty vti_x005f_listname
        }

        if ($ListId -ne $null)
        {
            return GET "SPFileSync/Sync/${ListId}/Items/${Id}" -Accept Application/Web3s+xml -Raw -Echo:$echo
        }
    }
}
#endregion


#region ListItem Functions
function Get-ListItem
{
    [CmdletBinding(DefaultParameterSetName="Name")]
    param
    (
        # List Id or Title
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {-not [String]::IsNullOrEmpty($_)}})]
        [object] $ListIdOrName,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = "Name")]
        [string[]] $Name,

        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Id")]
        [int] $Id,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select,

        [Parameter(Mandatory = $false, ParameterSetName = "Name")]
        [switch] $Exact
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        if (($ListIdOrName -as [guid]) -ne $null)
        {
            $listPath = "Lists/GetById(@listId)"
            $listQuery = "@listId=guid'$(${ListIdOrName} -as [guid])'"
        }
        else
        {
            $listPath = "Lists/GetByTitle(@listName)"
            $listQuery = "@listName='$(Get-EscapedString -Text ${ListIdOrName})'"
        }

        switch ($PSCmdlet.ParameterSetName)
        {
            "Name"
            {
                $filter = "`$filter="
                $filter += ($Name | Where-Object {-not [String]::IsNullOrEmpty($_)} | Get-EscapedString | ForEach-Object {if ($Exact) {"Title eq '${_}'"} else {"startswith(Title,'${_}')"}}) -join " or "

                $li = GET "${listPath}/Items" -Query "${listQuery}&${filter}&${queryClause}" -Echo:$echo

                # Workaround the duplicate property names in ListItem object (Id and ID) by removing the the ID property from the raw string.
                # Duplicate property names causes ConvertFrom-Json to fail.
                if ($li -is [string])
                {
                    try {$li = $li -creplace '\"ID\"\s*:\s*\d+,', '' | ConvertFrom-Json} catch {}
                }

                return $li | ForEach-Object {if ((Get-Member -InputObject $_ -Name value) -ne $null) {$_.value} else {$_}}
            }

            "Id"
            {
                $li = GET "${listPath}/Items/GetById(@id)" -Query "${listQuery}&@id=${Id}&${queryClause}" -Echo:$echo

                # Workaround the duplicate property names in ListItem object (Id and ID) by removing the the ID property from the raw string.
                # Duplicate property names causes ConvertFrom-Json to fail.
                if ($li -is [string])
                {
                    try {$li = $li -creplace '\"ID\"\s*:\s*\d+,', '' | ConvertFrom-Json} catch {}
                }

                return $li
            }
        }
    }
}

function Add-ListItem
{
    [CmdletBinding()]
    param
    (
        # List Id or Title
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {-not [String]::IsNullOrEmpty($_)}})]
        [object] $ListIdOrName,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string[]] $Expand,

        [Parameter(Mandatory = $false)]
        [string[]] $Select
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        $queryClause = "`$expand={0}&`$select={1}" -f ($Expand -join ','), ($Select -join ',')

        if (($ListIdOrName -as [guid]) -ne $null)
        {
            $listPath = "Lists/GetById(@listId)"
            $listQuery = "@listId=guid'$(${ListIdOrName} -as [guid])'"
        }
        else
        {
            $listPath = "Lists/GetByTitle(@listName)"
            $listQuery = "@listName='$(Get-EscapedString -Text ${ListIdOrName})'"
        }

        $Name = Get-EscapedString -Text $Name -Json

        $li = POST "${listPath}/Items" -Query "${listQuery}&${queryClause}" -Content "{'Title':'${Name}'}" -Echo:$echo

        # Workaround the duplicate property names in ListItem object (Id and ID) by removing the the ID property from the raw string.
        # Duplicate property names causes ConvertFrom-Json to fail.
        if ($li -is [string])
        {
            try {$li = $li -creplace '\"ID\"\s*:\s*\d+,', '' | ConvertFrom-Json} catch {}
        }

        return $li
    }
}

function Remove-ListItem
{
    [CmdletBinding()]
    param
    (
        # List Id or Title
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({if (($_ -as [guid]) -ne $null) {($_ -as [guid]) -ne [guid]::Empty} else {-not [String]::IsNullOrEmpty($_)}})]
        [object] $ListIdOrName,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int] $Id
    )

    Begin
    {
        $echo = Get-RequestParameterDefaultValue -Parameter Echo -ValueToReturnIfNotFound $true
    }

    Process
    {
        if (($ListIdOrName -as [guid]) -ne $null)
        {
            $listPath = "Lists/GetById(@listId)"
            $listQuery = "@listId=guid'$(${ListIdOrName} -as [guid])'"
        }
        else
        {
            $listPath = "Lists/GetByTitle(@listName)"
            $listQuery = "@listName='$(Get-EscapedString -Text ${ListIdOrName})'"
        }

        DELETE "${listPath}/Items/GetById(@id)" -Query "${listQuery}&@id=${Id}" -Echo:$echo
    }
}
#endregion


#region Http Methods
function GET
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "UriComponents")]
        [ValidateNotNullOrEmpty()]
        [string] $Path = "web",

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        "UriComponents"
        {
            if (-not $PSBoundParameters.ContainsKey("Path"))
            {
                $PSBoundParameters["Path"] = $Path
            }
            break
        }
    }

    Send-HttpRequest -Method "GET" @PSBoundParameters
}

function POST
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "UriComponents")]
        [ValidateNotNullOrEmpty()]
        [string] $Path = "contextinfo",

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [string] $ContentType,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($PSBoundParameters["Headers"] -eq $null -or -not (Test-FormDigestHeader -Headers $PSBoundParameters["Headers"]))
    {
        $params = @{}
        Get-FormDigestHeaderParameterNames | Where-Object {$PSBoundParameters.ContainsKey($_)} | ForEach-Object {$params[$_] = $PSBoundParameters[$_]}
        $PSBoundParameters["Headers"] += Get-FormDigestHeader @params -Verbose:$false
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        "UriComponents"
        {
            if (-not $PSBoundParameters.ContainsKey("Path"))
            {
                $PSBoundParameters["Path"] = $Path
            }
            break
        }
    }

    Send-HttpRequest -Method "POST" @PSBoundParameters
}

function PATCH
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "UriComponents")]
        [string] $Path,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [string] $ContentType,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($PSBoundParameters["Headers"] -eq $null -or -not (Test-FormDigestHeader -Headers $PSBoundParameters["Headers"]))
    {
        $params = @{}
        Get-FormDigestHeaderParameterNames | Where-Object {$PSBoundParameters.ContainsKey($_)} | ForEach-Object {$params[$_] = $PSBoundParameters[$_]}
        $PSBoundParameters["Headers"] += Get-FormDigestHeader @params -Verbose:$false
    }
    if ($PSBoundParameters["Headers"] -eq $null -or -not $PSBoundParameters["Headers"].ContainsKey("If-Match"))
    {
        $PSBoundParameters["Headers"] += @{"If-Match" = "*"}
    }

    Send-HttpRequest -Method "PATCH" @PSBoundParameters
}

function PUT
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "UriComponents")]
        [string] $Path,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [string] $ContentType,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($PSBoundParameters["Headers"] -eq $null -or -not (Test-FormDigestHeader -Headers $PSBoundParameters["Headers"]))
    {
        $params = @{}
        Get-FormDigestHeaderParameterNames | Where-Object {$PSBoundParameters.ContainsKey($_)} | ForEach-Object {$params[$_] = $PSBoundParameters[$_]}
        $PSBoundParameters["Headers"] += Get-FormDigestHeader @params -Verbose:$false
    }
    if ($PSBoundParameters["Headers"] -eq $null -or -not $PSBoundParameters["Headers"].ContainsKey("If-Match"))
    {
        $PSBoundParameters["Headers"] += @{"If-Match" = "*"}
    }

    Send-HttpRequest -Method "PUT" @PSBoundParameters
}

function BITS_POST
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "UriComponents")]
        [string] $Path,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Content,

        [Parameter(Mandatory = $false)]
        [string] $ContentType,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($PSBoundParameters["Headers"] -eq $null -or -not (Test-FormDigestHeader -Headers $PSBoundParameters["Headers"]))
    {
        $params = @{}
        Get-FormDigestHeaderParameterNames | Where-Object {$PSBoundParameters.ContainsKey($_)} | ForEach-Object {$params[$_] = $PSBoundParameters[$_]}
        $PSBoundParameters["Headers"] += Get-FormDigestHeader @params -Verbose:$false
    }
    if ($PSBoundParameters["Headers"] -eq $null -or -not $PSBoundParameters["Headers"].ContainsKey("BITS-Supported-Protocols"))
    {
        $PSBoundParameters["Headers"] += @{"BITS-Supported-Protocols" = ([System.Guid]::NewGuid().ToString())}
    }

    Send-HttpRequest -Method "BITS_POST" @PSBoundParameters
}

function DELETE
{
    [CmdletBinding(DefaultParameterSetName="UriComponents")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "UriComponents")]
        [string] $Path,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Site,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $ApiPath,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Query,

        [Parameter(Mandatory = $false, ParameterSetName = "UriComponents")]
        [string] $Fragment,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Uri")]
        [System.Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [string] $Accept,

        [Parameter(Mandatory = $false)]
        [hashtable] $Headers,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false)]
        [switch] $UseDefaultCredentials,

        [Parameter(Mandatory = $false)]
        [switch] $ODataVerbose,

        [Parameter(Mandatory = $false)]
        [Alias("Xml")]
        [switch] $AcceptXml,

        [Parameter(Mandatory = $false)]
        [Alias("Raw")]
        [switch] $OutputRaw,

        [Parameter(Mandatory = $false)]
        [Alias("Response")]
        [switch] $OutputResponse,

        [Parameter(Mandatory = $false)]
        [switch] $ErrorOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Quiet,

        [Parameter(Mandatory = $false)]
        [switch] $Echo
    )

    if ($PSBoundParameters["Headers"] -eq $null -or -not (Test-FormDigestHeader -Headers $PSBoundParameters["Headers"]))
    {
        $params = @{}
        Get-FormDigestHeaderParameterNames | Where-Object {$PSBoundParameters.ContainsKey($_)} | ForEach-Object {$params[$_] = $PSBoundParameters[$_]}
        $PSBoundParameters["Headers"] += Get-FormDigestHeader @params -Verbose:$false
    }
    if ($PSBoundParameters["Headers"] -eq $null -or -not $PSBoundParameters["Headers"].ContainsKey("If-Match"))
    {
        $PSBoundParameters["Headers"] += @{"If-Match" = "*"}
    }

    Send-HttpRequest -Method "DELETE" @PSBoundParameters
}
#endregion Http Methods


#region Environment Configuration
function Initialize-Environment
{
    [CmdletBinding(DefaultParameterSetName="AutoDetect")]
    param
    (
        [Parameter(Mandatory = $false, ParameterSetName = "AutoDetect")]
        [switch] $Refresh,

        [Parameter(Mandatory = $true, ParameterSetName = "OnPrem")]
        [switch] $OnPrem,

        [Parameter(Mandatory = $true, ParameterSetName = "SPO")]
        [switch] $SPO,

        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "OnPrem")]
        [Parameter(Mandatory = $false, Position = 0, ParameterSetName = "SPO")]
        [string] $HostName,

        [Parameter(Mandatory = $false, ParameterSetName = "OnPrem")]
        [Parameter(Mandatory = $false, ParameterSetName = "SPO")]
        [string] $Scheme,

        [Parameter(Mandatory = $false, ParameterSetName = "OnPrem")]
        [Parameter(Mandatory = $false, ParameterSetName = "SPO")]
        [int] $Port,

        [Parameter(Mandatory = $false, ParameterSetName = "OnPrem")]
        [string] $UserName,

        [Parameter(Mandatory = $false, ParameterSetName = "OnPrem")]
        [System.Net.ICredentials] $Credentials,

        [Parameter(Mandatory = $false, ParameterSetName = "SPO")]
        [string] $AuthCookie
    )

    $environmentType = $PSCmdlet.ParameterSetName

    if ($environmentType -eq "AutoDetect")
    {
        if ($Refresh)
        {
            Get-RequestParameterDefaults -Global | ForEach-Object {$PSDefaultParameterValues[$_.Key] = $_.Value}
        }
        else
        {
            if ((Get-HostsEntries | Where-Object HostName -eq "prepspo.spgrid.com") -ne $null)
            {
                $environmentType = "SPO"
            }
            else
            {
                $environmentType = "OnPrem"
            }
        }
    }

    if ($environmentType -eq "OnPrem")
    {
        if ([String]::IsNullOrEmpty($HostName)) {$HostName = "$env:COMPUTERNAME"}
        if ([String]::IsNullOrEmpty($Scheme)) {$Scheme = [System.Uri]::UriSchemeHttp}
        if ($Port -le 0) {$Port = 80}

        if ($Credentials -eq $null -and -not [String]::IsNullOrEmpty($UserName))
        {
            $Credentials = Get-Credential -UserName $UserName -Message "Enter your credentials."
        }

        Clear-RequestParameterDefaults
        Set-RequestParameterDefault -Parameter HostName                 -Value $HostName
        Set-RequestParameterDefault -Parameter Scheme                   -Value $Scheme
        Set-RequestParameterDefault -Parameter Port                     -Value $Port
        Set-RequestParameterDefault -Parameter UseDefaultCredentials    -Value ($Credentials -eq $null)
        if ($Credentials -ne $null)
        {
            Set-RequestParameterDefault -Parameter Credentials -Value $Credentials
        }
    }
    elseif ($environmentType -eq "SPO")
    {
        if ([String]::IsNullOrEmpty($HostName)) {$HostName = "prepspo.spgrid.com"}
        if ([String]::IsNullOrEmpty($Scheme)) {$Scheme = [System.Uri]::UriSchemeHttps}
        if ($Port -le 0) {$Port = 443}

        if ([String]::IsNullOrEmpty($AuthCookie))
        {
            $AuthCookie = Get-AuthCookie -Url ${Scheme}://${HostName}:${Port}
        }

        Clear-RequestParameterDefaults
        Set-RequestParameterDefault -Parameter HostName     -Value $HostName
        Set-RequestParameterDefault -Parameter Scheme       -Value $Scheme
        Set-RequestParameterDefault -Parameter Port         -Value $Port
        Set-RequestParameterDefault -Parameter AuthCookie   -Value $AuthCookie
    }
}

function Initialize-EnvironmentOnPrem
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $HostName,

        [Parameter(Mandatory = $false)]
        [string] $Scheme,

        [Parameter(Mandatory = $false)]
        [int] $Port,

        [Parameter(Mandatory = $false)]
        [string] $UserName,

        [Parameter(Mandatory = $false)]
        [System.Net.ICredentials] $Credentials
    )

    Initialize-Environment -OnPrem @PSBoundParameters
}

function Initialize-EnvironmentSPO
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $HostName,

        [Parameter(Mandatory = $false)]
        [string] $Scheme,

        [Parameter(Mandatory = $false)]
        [int] $Port,

        [Parameter(Mandatory = $false)]
        [string] $AuthCookie
    )

    Initialize-Environment -SPO @PSBoundParameters
}

function Test-EnvironmentInitialized
{
    [CmdletBinding()]
    param()

    return `
        (Get-RequestParameterDefault -Parameter UseDefaultCredentials -Function Send_HttpRequest -ValueOnly) -eq $true -or
        (Get-RequestParameterDefault -Parameter Credentials -Function Send_HttpRequest -ValueOnly) -ne $null -or
        -not [String]::IsNullOrEmpty((Get-RequestParameterDefault -Parameter AuthCookie -Function Send_HttpRequest -ValueOnly))
}

function Get-EnvironmentType
{
    [CmdletBinding()]
    param()

    if (Test-EnvironmentInitialized)
    {
        if ((Get-RequestParameterDefault -Parameter AuthCookie) -ne $null)
        {
            return "SPO"
        }
        else
        {
            return "OnPrem"
        }
    }
}

function Get-AuthCookie
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Url
    )

    return [ClaimsAuth.ClaimsCookie]::GetAuthCookie($Url)
}

function Get-HostsEntries
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $HostsFile = (Get-HostsFile)
    )

    Get-Content -Path $HostsFile |
        Where-Object {-not [String]::IsNullOrWhiteSpace($_) -and -not $_.TrimStart().StartsWith("#")} |
        ForEach-Object `
            -Begin {$entries = @()} `
            -Process {
                $entry = [pscustomobject]@{
                    HostsFile = $HostsFile
                    IPAddress = $null
                    HostName = $null
                    Comment = $null
                }

                if (($index = $_.IndexOf("#")) -gt -1)
                {
                    $entry.Comment = $_.Substring($index).TrimEnd()
                    $_ = $_.Substring(0, $index)
                }

                if ((-split $_).Count -eq 2)
                {
                    $entry.IPAddress = (-split $_)[0]
                    $entry.HostName = (-split $_)[1]

                    $entries += $entry
                }
            } `
            -End {$entries}
}

function Get-HostsFile
{
    [CmdletBinding()]
    param()

    return "$env:SystemRoot\System32\Drivers\etc\hosts"
}
#endregion

#region Parameter Enums

$httpRequestEnumDef = @'
    public enum RequestFunction
    {
        Send_HttpRequest,
    }

    public enum RequestParameter
    {
        Method,
        Path,
        Site,
        ApiPath,
        HostName,
        Scheme,
        Port,
        Query,
        Fragment,
        Uri,
        Content,
        ContentType,
        Accept,
        Headers,
        AuthCookie,
        Credentials,
        UseDefaultCredentials,
        ODataVerbose,
        AcceptXml,
        OutputRaw,
        OutputResponse,
        ErrorOnly,
        Quiet,
        Echo,
        Verbose,
    }
'@

Add-Type -TypeDefinition $httpRequestEnumDef -IgnoreWarnings

#endregion

#region Parameter Defaults
function Get-RequestParameterDefaults
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.Nullable[RequestFunction]] $Function,

        [Parameter(Mandatory = $false)]
        [switch] $Global
    )

    return [System.Enum]::GetNames([RequestParameter]) | ForEach-Object {Get-RequestParameterDefault -Parameter $_ -Function $Function -Global:$Global} | Sort-Object -Property Key
}

function Clear-RequestParameterDefaults
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [System.Nullable[RequestFunction]] $Function
    )

    [System.Enum]::GetNames([RequestParameter]) | ForEach-Object {Clear-RequestParameterDefault -Parameter $_ -Function $Function}
}

function Get-RequestParameterDefault
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [RequestParameter] $Parameter,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Nullable[RequestFunction]] $Function,

        [Parameter(Mandatory = $false)]
        [switch] $ValueOnly,

        [Parameter(Mandatory = $false)]
        [switch] $Global
    )

    $var = if ($Global) {$global:PSDefaultParameterValues} else {$PSDefaultParameterValues}

    $parameterKeys = @(Get-RequestParameterKey -Parameter $Parameter -Function $Function)

    return $var.GetEnumerator() | Where-Object Key -in $parameterKeys | Sort-Object -Property Key | ForEach-Object {if ($ValueOnly) {$_.Value} else {$_}}
}

function Get-RequestParameterDefaultValue
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [RequestParameter] $Parameter,

        [Parameter(Mandatory = $false, Position = 1)]
        [object] $ValueToReturnIfNotFound,

        [Parameter(Mandatory = $false)]
        [System.Nullable[RequestFunction]] $Function = [RequestFunction]::Send_HttpRequest
    )

    $value = Get-RequestParameterDefault -Parameter $Parameter -Function $Function -ValueOnly
    if ($value -eq $null)
    {
        return $ValueToReturnIfNotFound
    }
    else
    {
        return $value
    }
}

function Set-RequestParameterDefault
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [RequestParameter] $Parameter,

        [Parameter(Mandatory = $false, Position = 1)]
        [object] $Value,

        [Parameter(Mandatory = $false)]
        [System.Nullable[RequestFunction]] $Function
    )

    # Need to set in global scope as well, so calling Send-HttpRequest directly will get the defaults.
    Get-RequestParameterKey -Parameter $Parameter -Function $Function | ForEach-Object {$PSDefaultParameterValues[$_] = $Value; $global:PSDefaultParameterValues[$_] = $Value}
}

function Clear-RequestParameterDefault
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [RequestParameter] $Parameter,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Nullable[RequestFunction]] $Function
    )

    Get-RequestParameterKey -Parameter $Parameter -Function $Function | ForEach-Object {$PSDefaultParameterValues.Remove($_); $global:PSDefaultParameterValues.Remove($_)}
}

function Get-RequestParameterKey
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [RequestParameter] $Parameter,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Nullable[RequestFunction]] $Function
    )

    if ($Function -ne $null)
    {
        $functionNames = @([System.Enum]::GetName([RequestFunction], $Function))
    }
    else
    {
        $functionNames = @([System.Enum]::GetNames([RequestFunction]))
    }

    return $functionNames | ForEach-Object {if ($_ -ceq $_.ToUpper()) {$_} else {$_.Replace('_', '-')}} | ForEach-Object {"${_}:${Parameter}"}
}

#endregion

#region Stream reader/writer

function Read-ResponseBody
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.Net.WebResponse] $Response
    )

    $responseStream = $Response.GetResponseStream()

    if (-not [String]::IsNullOrEmpty($Response.CharacterSet))
    {
        $encoding = [System.Text.Encoding]::GetEncoding($Response.CharacterSet)
    }
    else
    {
        $encoding = [System.Text.Encoding]::Default
    }

    return Read-Stream -Stream $responseStream -Encoding $encoding
}

function Read-Stream
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.IO.Stream] $Stream,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Text.Encoding] $Encoding = [System.Text.Encoding]::Default,

        [Parameter(Mandatory = $false)]
        [switch] $CloseStream
    )

    if (-not $Stream.CanRead)
    {
        Write-Warning "ReadFrom-Stream: Cannot read from the input stream."
        return
    }

    $sr = $null
    try
    {
        if ($Stream.CanSeek -and $Stream.Position -ne 0)
        {
            $null = $Stream.Seek(0, [System.IO.SeekOrigin]::Begin)
        }
        $sr = New-Object -TypeName System.IO.StreamReader($Stream, $Encoding)
        $content = $sr.ReadToEnd()

        return $content
    }
    finally
    {
        if ($sr -ne $null)
        {
            if ($CloseStream)
            {
                $sr.Close()
            }
            elseif ($sr.BaseStream.CanSeek -and $sr.BaseStream.Position -ne 0)
            {
                $null = $sr.BaseStream.Seek(0, [System.IO.SeekOrigin]::Begin)
            }
        }
    }
}

function Write-Stream
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Content,

        [Parameter(Mandatory = $true, Position = 1)]
        [System.IO.Stream] $Stream,

        [Parameter(Mandatory = $false)]
        [System.Text.Encoding] $Encoding = [System.Text.Encoding]::Default,

        [Parameter(Mandatory = $false)]
        [switch] $CloseStream,

        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    if (-not $Stream.CanWrite)
    {
        Write-Warning "WriteTo-Stream: Cannot write to the input stream."
        return
    }

    $sw = $null
    try
    {
        $sw = New-Object -TypeName System.IO.StreamWriter($Stream, $Encoding)
        $sw.Write($Content)
    }
    finally
    {
        if ($sw -ne $null)
        {
            if ($CloseStream)
            {
                $sw.Close()
            }
            else
            {
                $sw.Flush()
            }
        }
    }

    if ($PassThru)
    {
        return $Stream
    }
}

function Test-PlainText
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [string] $Text
    )

    Begin
    {
        # `t = ASCII(9)
        # `n = ASCII(10)
        # `r = ASCII(13)
        # ASCII range: 32 thru 126
        $plainTextRange = 9,10,13+32..126
    }

    Process
    {
        if (-not $PSBoundParameters.ContainsKey("Text"))
        {
            return
        }

        if ([String]::IsNullOrEmpty($Text))
        {
            return $true
        }

        $ms = $null
        $sr = $null
        try
        {
            $ms = New-Object -TypeName System.IO.MemoryStream(,[System.Text.Encoding]::ASCII.GetBytes($Text))
            $sr = New-Object -TypeName System.IO.StreamReader($ms)

            while ($sr.Peek() -ge 0)
            {
                if ([int]$sr.Read() -notin $plainTextRange)
                {
                    return $false
                }
            }
        }
        finally
        {
            if ($ms -ne $null)
            {
                $ms.Close()
            }
            if ($sr -ne $null)
            {
                $sr.Close()
            }
        }

        return $true
    }
}

#endregion

#region Output Formatting

function Format-Output
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [string] $Content,

        [Parameter(Mandatory = $false, Position = 1)]
        [string] $ContentType
    )

    if ([String]::IsNullOrEmpty($Content))
    {
        return
    }
    elseif ($ContentType -match "/json;?")
    {
        return Format-Json -Text $Content
    }
    elseif ($ContentType -match "/.*?xml;?")
    {
        return Format-Xml -Text $Content
    }
    else
    {
        return $Content
    }
}

Set-Alias -Scope Global -Name fj -Value Format-Json

function Format-Json
{
    [CmdletBinding(DefaultParameterSetName="Text")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "Text")]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "Object")]
        [ValidateNotNull()]
        [System.Object] $Object
    )

    Process
    {
        try
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                "Text"
                {
                    $Object = $Text | ConvertFrom-Json
                    break
                }
            }

            $jsonText = $Object | ConvertTo-Json

            # Replace UTF-16 encoded characters with their ASCII equivalent.
            # Replace \r\n and \n literal characters with newline characters.
            return `
                -join (
                    $jsonText -split "(\\u[0-9a-f]{4})" |
                        ForEach-Object {
                            if ($_ -match "\\u[0-9a-f]{4}")
                            {
                                [char][int]$_.Replace("\u", "0x")
                            }
                            else
                            {
                                $_
                            }
                        }
                ) `
                -replace "\\r\\n", "`r`n" `
                -replace "\\n", "`r`n"
        }
        catch
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                "Text"
                {
                    return $Text
                }

                "Object"
                {
                    return $Object
                }
            }
        }
    }
}

Set-Alias -Scope Global -Name fx -Value Format-Xml

function Format-Xml
{
    [CmdletBinding(DefaultParameterSetName="Text")]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "Text")]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = "Xml")]
        [ValidateNotNull()]
        [xml] $Xml
    )

    Process
    {
        $xw = $null
        try
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                "Text"
                {
                    $Xml = [xml]$Text
                    break
                }
            }

            $sb = New-Object -TypeName System.Text.StringBuilder

            $xws = New-Object -TypeName System.Xml.XmlWriterSettings
            $xws.OmitXmlDeclaration = $true
            $xws.Indent = $true

            $xw = [System.Xml.XmlWriter]::Create($sb, $xws)
            $Xml.Save($xw)

            return $sb.ToString()
        }
        catch
        {
            switch ($PSCmdlet.ParameterSetName)
            {
                "Text"
                {
                    return $Text
                }

                "Xml"
                {
                    return $Xml
                }
            }
        }
        finally
        {
            if ($xw -ne $null)
            {
                $xw.Close()
            }
        }
    }
}

#endregion

#region Name Generation

function Get-ItemName
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Prefix,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(0, [System.Int32]::MaxValue)]
        [int] $Length,

        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [string] $Extension = [String]::Empty,

        [Parameter(Mandatory = $false)]
        [ValidateNotNull()]
        [string] $Separator = [String]::Empty,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $FillerPattern = "1234567890",

        [Parameter(Mandatory = $false)]
        [switch] $NoParentheses
    )

    if ($NoParentheses)
    {
        $openParenthesis = [String]::Empty
        $closeParenthesis = [String]::Empty
    }
    else
    {
        $openParenthesis = "("
        $closeParenthesis = ")"
    }

    $minLength = $Prefix.Length + $Separator.Length + $openParenthesis.Length + "$Length".Length + $closeParenthesis.Length + $Separator.Length + $Extension.Length
    if ($Length -ge $minLength)
    {
        $fillerText = Get-FillerText -Length ($Length - $minLength) -Pattern $FillerPattern

        return "${Prefix}${Separator}${openParenthesis}${Length}${closeParenthesis}${Separator}${fillerText}${Extension}"
    }
    else
    {
        Write-Warning -Message "Get-ItemName: Minimum required length ($minLength) of '${Prefix}${Separator}${openParenthesis}${Length}${closeParenthesis}${Separator}${Extension}' is less than the requested length ($Length). Specify a length >= $minLength."
    }
}

function Get-FillerText
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateRange(0, [System.Int32]::MaxValue)]
        [int] $Length,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern = "1234567890"
    )

    $r = $Length % $Pattern.Length
    $q = ($Length - $r) / $Pattern.Length

    $t = [String]::Empty
    for ($i = 0; $i -lt $q; $i++)
    {
        $t += $Pattern
    }
    $t += $Pattern.Substring(0, $r)

    return $t
}

#endregion

#region ClaimsAuth C# code, 这里还是起一个浏览器，让用户登录，拿FedAuth Cookie

# 使用方法
# Import-Module .\HttpRequest.psm1
# $FedAuthCookie = Get-AuthCookie -Url $WebUrl

$claimsAuthDef = @'
using System;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace ClaimsAuth
{
    public class ClaimsCookie
    {
        public static string GetAuthCookie(Uri targetUri)
        {
            using (ClaimsWebAuth webAuth = new ClaimsWebAuth(targetUri))
            {
                return webAuth.GetAuthCookie();
            }
        }
    }

    public class ClaimsWebAuth : IDisposable
    {
        private WebBrowser webBrowser;
        private Form loginForm;
        private string authCookie;

        public const int DefaultWidth = 925;
        public const int DefaultHeight = 625;

        public Uri TargetUri { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }

        public Uri BaseUri { get; private set; }
        public Uri LoginUri { get; private set; }
        public Uri ReturnUri { get; private set; }

        public ClaimsWebAuth(Uri targetUri)
        {
            this.TargetUri = targetUri;
            this.Width = DefaultWidth;
            this.Height = DefaultHeight;
        }

        public bool Initialize()
        {
            if (this.TargetUri == null)
            {
                return false;
            }

            Uri loginUri, returnUri;
            InitializeAuthUris(this.TargetUri, out loginUri, out returnUri);
            if (loginUri == null || returnUri == null)
            {
                return false;
            }

            this.LoginUri = loginUri;
            this.ReturnUri = returnUri;
            this.BaseUri = new Uri(this.LoginUri, "/");

            return true;
        }

        public string GetAuthCookie()
        {
            if (!this.Initialize())
            {
                return null;
            }

            this.webBrowser = new WebBrowser();
            this.webBrowser.Dock = DockStyle.Fill;
            this.webBrowser.ScriptErrorsSuppressed = true;
            this.webBrowser.Navigated += new WebBrowserNavigatedEventHandler(ClaimsWebBrowser_Navigated);
            this.webBrowser.Navigate(this.LoginUri);

            this.loginForm = new Form();
            this.loginForm.Width = this.Width;
            this.loginForm.Height = this.Height;
            this.loginForm.Text = this.TargetUri.ToString();
            this.loginForm.Controls.Add(this.webBrowser);

            Application.Run(this.loginForm);

            return this.authCookie;
        }

        private void ClaimsWebBrowser_Navigated(object sender, WebBrowserNavigatedEventArgs e)
        {
            if (e.Url == this.ReturnUri)
            {
                string cookie = Win32Utils.GetCookie(this.BaseUri.ToString());
                if (!String.IsNullOrEmpty(cookie))
                {
                    this.authCookie = ExtractAuthCookie(this.BaseUri, cookie);
                    this.loginForm.Close();
                }
            }
        }

        public void Dispose()
        {
            if (this.webBrowser != null)
            {
                ((IDisposable)this.webBrowser).Dispose();
            }
            if (this.loginForm != null)
            {
                ((IDisposable)this.loginForm).Dispose();
            }

            this.webBrowser = null;
            this.loginForm = null;
        }

        public static void InitializeAuthUris(Uri targetUri, out Uri loginUri, out Uri returnUri)
        {
            loginUri = returnUri = null;

            if (targetUri == null)
            {
                return;
            }

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(targetUri);
            request.Method = "OPTIONS";

            WebResponse response = null;
            try
            {
                response = request.GetResponse();
                ExtractAuthUris(response, out loginUri, out returnUri);
            }
            catch (WebException webEx)
            {
                ExtractAuthUris(webEx.Response, out loginUri, out returnUri);
            }
            finally
            {
                if (response != null)
                {
                    response.Close();
                }
            }
        }

        public static void ExtractAuthUris(WebResponse response, out Uri loginUri, out Uri returnUri)
        {
            loginUri = returnUri = null;

            if (response != null)
            {
                string loginUrl = response.Headers["X-Forms_Based_Auth_Required"];
                string returnUrl = response.Headers["X-Forms_Based_Auth_Return_Url"];

                if (!String.IsNullOrEmpty(loginUrl))
                {
                    loginUri = new Uri(loginUrl);
                }

                if (!String.IsNullOrEmpty(returnUrl))
                {
                    returnUri = new Uri(returnUrl);
                }
            }
        }

        public static string ExtractAuthCookie(Uri baseUri, string cookieHeader)
        {
            CookieCollection cookies;

            if (baseUri == null || String.IsNullOrEmpty(cookieHeader))
            {
                return null;
            }

            CookieContainer cc = new CookieContainer();
            cc.SetCookies(baseUri, cookieHeader.Replace("; ", ",").Replace(";", ","));
            cookies = cc.GetCookies(baseUri);

            if (cookies["FedAuth"] != null && cookies["rtFa"] != null)
            {
                return String.Join("; ", cookies["FedAuth"], cookies["rtFa"]);
            }

            return null;
        }
    }

    public static class Win32Utils
    {
        [DllImport("Kernel32.dll")]
        public static extern uint GetLastError();

        private const uint INTERNET_COOKIE_HTTPONLY = 0x00002000;

        [DllImport("wininet.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool InternetGetCookieEx(
            string url,
            string cookieName,
            StringBuilder cookieData,
            ref uint size,
            uint flags,
            IntPtr pReserved);

        public static string GetCookie(string url)
        {
            uint size = 2048;
            StringBuilder sb = new StringBuilder((int)size);

            if (!InternetGetCookieEx(url, null, sb, ref size, INTERNET_COOKIE_HTTPONLY, IntPtr.Zero))
            {
                if (size == 0)
                {
                    return null;
                }

                sb = new StringBuilder((int)size);
                if (!InternetGetCookieEx(url, null, sb, ref size, INTERNET_COOKIE_HTTPONLY, IntPtr.Zero))
                {
                    return null;
                }
            }

            return sb.ToString();
        }
    }
}
'@

Add-Type -TypeDefinition $claimsAuthDef -ReferencedAssemblies "System.Windows.Forms.dll" -IgnoreWarnings

#endregion ClaimsAuth C# code

Initialize-Environment -Refresh