# This module uses Write-Host instead of Write-Output, because otherwise the logging is returned within functions. Write-Host only outputs to console, which is what we want
function Write-Log([Parameter(ValueFromPipeline)][string]$Message, [string]$Color = "White") {
    process {
        $timestamp = "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date)
        # $PSStyle contains properties that determine how text is rendered, but is only supported since PowerShell 7+.
        # Uses ASCI escape codes, which are widely supported.
        $startColorCoding = $PSStyle.Foreground."Bright$Color" # Use Bright$Color because it is nicer than the regular colors.
        $endColorCoding = $PSStyle.Reset

        # $host.UI... changes how text is rendered in PowerShell, this is a fallback for PowerShell 5, which doesn't support $psstyle
        $defaultColor = $host.UI.RawUI.ForegroundColor
        $host.UI.RawUI.ForegroundColor = $Color

        Write-Host "${startColorCoding}${timestamp} ${Message}${endColorCoding}"

        $host.UI.RawUI.ForegroundColor = $defaultColor
    }
}

function Write-Info([Parameter(ValueFromPipeline)][string]$Message) {
    process {
        Write-Log -Message "[   info] $message" -Color "Blue"
    }
}

function Write-Success([Parameter(ValueFromPipeline)][string]$Message) {
    process {
        Write-Log -Message "[success] $message" -Color "Green"
    }
}

function Write-Warning([Parameter(ValueFromPipeline)][string]$Message) {
    process {
        Write-Log -Message "[warning] $message" -Color "Yellow"
    }
}

function Write-Error([Parameter(ValueFromPipeline)][string]$Message) {
    process {
        Write-Log -Message "[  error] $message" -Color "Red"
    }
}
