function Invoke-XurrentBulkUpload
{
    <#
        .SYNOPSIS
        Bulk-imports an array of objects into Xurrent via the /import endpoint.

        .DESCRIPTION
        Serializes objects to a temporary CSV, posts it as a multipart form upload, polls
        the job status, and returns 'done' or 'error'. Auto-chunks when the object count
        exceeds JobLimit. Requires an active session.

        .PARAMETER Object
        The objects to import.

        .PARAMETER ResourceType
        The Xurrent resource type (e.g. 'people', 'knowledge_articles').

        .PARAMETER Simulate
        If specified, skips the upload and returns 'done' without sending data.

        .PARAMETER KeepFile
        If specified, the temporary CSV file is not deleted after upload.

        .PARAMETER JobLimit
        Maximum number of records per import job. Defaults to 2000.

        .EXAMPLE
        $people | Invoke-XurrentBulkUpload -ResourceType people

        .EXAMPLE
        Invoke-XurrentBulkUpload -Object $records -ResourceType knowledge_articles -Simulate
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $Object,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'agile_boards', 'archive', 'broadcasts', 'calendar_hours', 'calendars',
            'changes', 'ci_relations', 'configuration_items', 'contract_customers',
            'contracts', 'custom_collection_elements', 'custom_collections',
            'effort_classes', 'first_lines', 'holidays', 'invoices', 'knowledge_articles',
            'organizations', 'out_of_office_periods', 'people', 'problem_tasks',
            'problems', 'product_backlog', 'product_backlog_estimates',
            'products', 'project_categories', 'project_phases', 'project_risk_levels',
            'project_task_assignments', 'project_task_templates', 'project_tasks',
            'project_templates', 'projects', 'releases', 'request_templates',
            'requests', 'risks', 'scrum_workspaces', 'service_categories',
            'service_instances', 'service_level_agreements', 'service_offerings',
            'services', 'shops', 'skill_pools', 'sla_coverage_groups',
            'sprint_backlog_items', 'sprints', 'teams', 'time_allocations',
            'time_entries', 'translations', 'ui_extensions', 'users',
            'webhook_deliveries', 'webhooks', 'workflows'
        )]
        [string]
        $ResourceType,

        [Parameter()]
        [switch]
        $Simulate,

        [Parameter()]
        [switch]
        $KeepFile,

        [Parameter()]
        [ValidateRange(500, 10000)]
        [int]
        $JobLimit = 2000
    )

    begin
    {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process
    {
        foreach ($item in $Object)
        {
            $collected.Add($item)
        }
    }

    end
    {
        Assert-XurrentConnection

        if ($Simulate)
        {
            Write-Verbose "Simulate: would upload $($collected.Count) $ResourceType records."
            return 'done'
        }

        if ($collected.Count -gt $JobLimit)
        {
            Write-Verbose "Chunking $($collected.Count) records into batches of $JobLimit."
            $result = 'done'
            for ($i = 0; $i -lt $collected.Count; $i += $JobLimit)
            {
                $chunk = $collected.GetRange($i, [System.Math]::Min($JobLimit, $collected.Count - $i))
                $chunkResult = Invoke-XurrentBulkUpload -Object $chunk -ResourceType $ResourceType -JobLimit $JobLimit
                if ($chunkResult -eq 'error') { $result = 'error' }
            }
            return $result
        }

        $tempFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.csv'
        try
        {
            $collected | Export-Csv -Path $tempFile -NoTypeInformation -Encoding UTF8

            $fileSize = (Get-Item $tempFile).Length
            if ($fileSize -gt 5MB)
            {
                throw "CSV file size ($([int]($fileSize / 1MB)) MB) exceeds the 5 MB limit. Reduce JobLimit."
            }

            $form = @{
                type = $ResourceType
                file = Get-Item $tempFile
            }

            $importUrl = $script:XurrentSession.BaseUrl + '/import'
            $uploadResponse = Invoke-XurrentAPIRequest -Uri $importUrl -Method POST -Form $form
            if ($null -eq $uploadResponse) { return 'error' }

            $token = $uploadResponse.token
            if (-not $token)
            {
                Write-Error 'Bulk upload did not return a job token.'
                return 'error'
            }

            $statusUrl = $script:XurrentSession.BaseUrl + "/import/$token"
            $retries = 0
            $maxRetries = 100

            do
            {
                Start-Sleep -Seconds 20
                $status = Invoke-XurrentAPIRequest -Uri $statusUrl -Method GET
                $retries++

                Write-Verbose "Bulk upload status ($retries/$maxRetries): $($status.state)"
            }
            until ($status.state -in @('done', 'error') -or $retries -ge $maxRetries)

            if ($status.results -and $status.results.errors)
            {
                foreach ($err in $status.results.errors)
                {
                    Write-Error "Bulk upload error (line $($err.row)): $($err.message)"
                }
            }

            if ($status.logfile_uri)
            {
                Write-Verbose "Log file available at: $($status.logfile_uri)"
            }

            return $status.state
        }
        finally
        {
            if (-not $KeepFile -and (Test-Path $tempFile))
            {
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
