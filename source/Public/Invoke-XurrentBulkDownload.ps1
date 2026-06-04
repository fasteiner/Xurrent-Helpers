function Invoke-XurrentBulkDownload
{
    <#
        .SYNOPSIS
        Bulk-exports one or more resource types from Xurrent via the /export endpoint.

        .DESCRIPTION
        Posts an export request to the Xurrent /export endpoint, polls for completion,
        and returns the parsed objects. For a single resource type returns an array;
        for multiple types returns a hashtable keyed by type name. Requires an active session.

        .PARAMETER ResourceType
        One or more Xurrent resource types to export.

        .PARAMETER Delta
        If specified, exports only records changed since FromDate.

        .PARAMETER FromDate
        ISO 8601 UTC date string for the delta export start time (e.g. 2024-01-01T00:00:00Z).

        .PARAMETER SaveAs
        File path to save the raw export to instead of returning parsed objects.

        .EXAMPLE
        Invoke-XurrentBulkDownload -ResourceType people

        .EXAMPLE
        Invoke-XurrentBulkDownload -ResourceType people, organizations -SaveAs C:\export.zip
    #>
    [CmdletBinding(DefaultParameterSetName = 'full')]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'agile_boards', 'broadcasts', 'calendar_hours', 'calendars',
            'changes', 'ci_relations', 'configuration_items', 'contract_customers',
            'contracts', 'custom_collection_elements', 'custom_collections',
            'effort_classes', 'first_lines', 'holidays', 'invoices', 'knowledge_articles',
            'organizations', 'out_of_office_periods', 'people', 'problem_tasks',
            'problems', 'product_backlog', 'products', 'project_categories',
            'project_phases', 'project_risk_levels', 'project_task_assignments',
            'project_task_templates', 'project_tasks', 'project_templates', 'projects',
            'releases', 'request_templates', 'requests', 'risks', 'scrum_workspaces',
            'service_categories', 'service_instances', 'service_level_agreements',
            'service_offerings', 'services', 'shops', 'skill_pools',
            'sla_coverage_groups', 'sprint_backlog_items', 'sprints', 'teams',
            'time_allocations', 'time_entries', 'translations', 'ui_extensions', 'users',
            'webhooks', 'workflows'
        )]
        [string[]]
        $ResourceType,

        [Parameter(ParameterSetName = 'delta')]
        [switch]
        $Delta,

        [Parameter(Mandatory = $true, ParameterSetName = 'delta')]
        [ValidatePattern('^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')]
        [string]
        $FromDate,

        [Parameter()]
        [string]
        $SaveAs
    )

    process
    {
        Assert-XurrentConnection

        $form = @{}
        foreach ($type in $ResourceType)
        {
            $form["type[$($ResourceType.IndexOf($type))]"] = $type
        }
        if ($Delta) { $form['from'] = $FromDate }

        $exportUrl = $script:XurrentSession.BaseUrl + '/export'
        $exportResponse = Invoke-XurrentAPIRequest -Uri $exportUrl -Method POST -Form $form
        if ($null -eq $exportResponse) { return $null }

        $token = $exportResponse.token
        if (-not $token)
        {
            Write-Error 'Bulk export did not return a job token.'
            return $null
        }

        $statusUrl = $script:XurrentSession.BaseUrl + "/export/$token"
        $retries = 0
        $maxRetries = 20
        $status = $null

        do
        {
            Start-Sleep -Seconds 5
            $status = Invoke-XurrentAPIRequest -Uri $statusUrl -Method GET
            $retries++
            Write-Verbose "Bulk export status ($retries/$maxRetries): $($status.state)"
        }
        until ($status.state -in @('done', 'error') -or $retries -ge $maxRetries)

        if ($status.state -ne 'done')
        {
            Write-Error "Bulk export did not complete in time. Last state: $($status.state)"
            return $null
        }

        if (-not $status.url)
        {
            Write-Error 'Bulk export completed but no download URL was returned.'
            return $null
        }

        $tempFile = [System.IO.Path]::GetTempFileName()
        try
        {
            Invoke-XurrentAPIRequest -Uri $status.url -Method GET -OutFile $tempFile | Out-Null

            if ($SaveAs)
            {
                Copy-Item $tempFile -Destination $SaveAs -Force
                return
            }

            if ($ResourceType.Count -eq 1)
            {
                return Import-Csv -Path $tempFile -Encoding UTF8
            }
            else
            {
                $result = @{}
                $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
                try
                {
                    Expand-Archive -Path $tempFile -DestinationPath $extractDir -Force
                    foreach ($type in $ResourceType)
                    {
                        $csvFile = Get-ChildItem $extractDir -Filter "$type.csv" -Recurse | Select-Object -First 1
                        if ($csvFile)
                        {
                            $result[$type] = Import-Csv -Path $csvFile.FullName -Encoding UTF8
                        }
                        else
                        {
                            $result[$type] = @()
                        }
                    }
                }
                finally
                {
                    Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                return $result
            }
        }
        finally
        {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
