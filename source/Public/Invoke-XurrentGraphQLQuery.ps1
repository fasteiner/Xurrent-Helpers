function Invoke-XurrentGraphQLQuery
{
    <#
        .SYNOPSIS
        Executes a GraphQL query or mutation against the Xurrent GraphQL API.

        .DESCRIPTION
        Posts a GraphQL query to the Xurrent GraphQL endpoint and returns the data property.
        Handles rate limiting by retrying after the indicated delay. Requires an active session.

        .PARAMETER Query
        The GraphQL query or mutation string.

        .PARAMETER Variables
        An optional hashtable of variables to pass with the query.

        .EXAMPLE
        Invoke-XurrentGraphQLQuery -Query 'query { me { id name } }'

        .EXAMPLE
        Invoke-XurrentGraphQLQuery -Query 'query GetPerson($id: ID!) { person(id: $id) { name } }' -Variables @{ id = '123' }
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Query,

        [Parameter()]
        [hashtable]
        $Variables
    )

    process
    {
        Assert-XurrentConnection

        $body = @{ query = $Query }
        if ($Variables) { $body['variables'] = $Variables }

        $uri = $script:XurrentSession.GraphQLUrl

        :loop while ($true)
        {
            $response = Invoke-XurrentAPIRequest -Uri $uri -Method POST -Body $body

            if ($null -eq $response) { return $null }

            if ($response.errors)
            {
                $firstError = $response.errors[0]
                $retryAfter = $null
                if ($firstError.extensions -and $firstError.extensions.retryAfter)
                {
                    $retryAfter = $firstError.extensions.retryAfter
                }
                elseif ($firstError.message -match 'rate.?limit' -and $firstError.extensions -and $firstError.extensions.code -eq 'RATE_LIMITED')
                {
                    $retryAfter = 30
                }

                if ($null -ne $retryAfter)
                {
                    Write-Verbose "GraphQL rate limited. Retrying after $retryAfter seconds."
                    Start-Sleep -Seconds $retryAfter
                    continue loop
                }

                $messages = ($response.errors | ForEach-Object { $_.message }) -join '; '
                throw "GraphQL errors: $messages"
            }

            return $response.data
        }
    }
}
