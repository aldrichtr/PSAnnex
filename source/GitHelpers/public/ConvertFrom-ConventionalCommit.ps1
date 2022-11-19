
function ConvertFrom-ConventionalCommit {
    [CmdletBinding()]
    param(
        # The commit message to parse
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [string]$Message
    )
    begin {
        Write-Debug "`n$('-' * 80)`n-- Begin $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
        enum Section {
            NONE = 0
            HEAD = 1
            BODY = 2
            FOOT = 3
        }
    }
    process {
        # This will restart for each message on the pipeline
        # Messages (at least the ones from PowerGit objects) are multiline strings
        $section = [Section]::NONE
        $title = $type = $scope = ''
        $body = [System.Collections.ArrayList]@()
        $footers = @{}
        $breaking_change = $false
        $conforming = $false
        $line_num = 1
        foreach ($line in ($Message -split '\n')) {
            Write-Debug "Parsing line #$line_num`n  '$line'"
            switch -Regex ($line) {
                '^#+' {
                    Write-Debug ' - Comment line'
                    continue
                }
                #! This may match the head, but also may match a specific kind of footer
                #! too.  So we check the line number and go from there
                '^(?<t>\w+)(\((?<s>\w+)\))?(?<b>!)?:\s+(?<d>.+)$' {
                    Write-Debug '  - Head line'
                    # only parse this if we are on line one!
                    if ($line_num -eq 1) {
                        $title = $line
                        $type = $Matches.t
                        $scope = $Matches.s ?? ''
                        $desc = $Matches.d
                        $section = [Section]::HEAD
                        $breaking_change = ($Matches.b -eq '!')
                        $conforming = $true
                    } else {
                        Write-Debug '  - Footer'
                        $footers[$Matches.t] = $Matches.d
                        $section = [Section]::FOOT
                    }
                    continue
                }
                '^\s*(?<t>[a-zA-Z0-8-]+)\s+(?<v>#.*)$' {
                    Write-Debug '  - Footer'
                    $footers[$Matches.t] = $Matches.v
                    $section = [Section]::FOOT
                    continue
                }
                '^\s*(?<t>BREAKING[- ]CHANGE):\s+(?<v>.*)$' {
                    Write-Debug '  - Breaking change footer'
                    $footers[$Matches.t] = $Matches.v
                    $breaking_change = $true
                }
                '^\s*$' {
                    # might be the end of a section, or it might be in the middle of the body
                    if ($section -eq [Section]::HEAD) {
                        # this is our "one blank line convention"
                        # so the next line should be the start of the body
                        $section = [Section]::BODY
                    }
                    continue
                }
                Default {
                    #! if the first line is not in the proper format, it will
                    #! end up here:  We can add it as the title, but none of
                    #! the conventional commit specs will be filled
                    if ($line_num -eq 1) {
                        Write-Verbose "  '$line' does not seem to be a conventional commit"
                        $title = $line
                        $desc = $line
                        $conforming = $false
                    } else {
                        # if it matched nothing else, it should be in the body
                        Write-Debug '  - Default match, adding to the body text'
                        $body += $line
                    }
                    continue
                }
            }
            $line_num++
        }

        [PSCustomObject]@{
            PSTypeName       = 'Git.ConventionalCommitInfo'
            IsConventional   = $conforming
            IsBreakingChange = $breaking_change
            Title            = $title
            Type             = $type
            Scope            = $scope
            Description      = $desc
            Body             = $body
            Footers          = $footers
        } | Write-Output
    }
    end {
        Write-Debug "`n$('-' * 80)`n-- End $($MyInvocation.MyCommand.Name)`n$('-' * 80)"
    }
}
