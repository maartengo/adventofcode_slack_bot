﻿param(
    [string]$year = $ENV:AOC_YEAR,
    [string]$session = $ENV:AOC_SESSION_COOKIE,
    [string]$leaderboard = $ENV:AOC_LEADERBOARD_ID,
    [string]$live_refresh = $ENV:AOC_REFRESH_DATA, # default false
    [string]$timeout_seconds = $ENV:AOC_REFRESH_RATE_SECONDS,
    [string]$webhook = $ENV:SLACK_WEBHOOK,
    [string]$send_slack_message = $ENV:SLACK_SEND_MESSAGE, # default false
    [string]$debug = $ENV:SCRIPT_DEBUG # default false
)
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "Logging.psm1") -Force

#region Parameter validation
if ([string]::IsNullOrEmpty($live_refresh)) {
    $live_refresh = "false"
}

if ([string]::IsNullOrEmpty($timeout_seconds)) {
    $timeout_seconds = "900" # 15 minutes, the minimum refresh rate
}

if ([string]::IsNullOrEmpty($debug)) {
    [bool]$debug = $true
}
else {
    [bool]$debug = [bool]::Parse($debug)
}

if ([string]::IsNullOrEmpty($send_slack_message)) {
    [bool]$send_slack_message = $false
}
else {
    [bool]$send_slack_message = [bool]::Parse($send_slack_message)
}

if ($debug) {
    Write-Info ""
    Write-Info "session: $session"
    Write-Info "webhook: $webhook"
    Write-Info "leaderboard: $leaderboard"
    Write-Info "year: $year"
    Write-Info "live_refresh: $live_refresh"
    Write-Info "timeout_seconds: $timeout_seconds"
    Write-Info "send_slack_message: $send_slack_message"
    Write-Info ""
}

#endregion

#region Functions
function Add-Property($Object, $Name, $Value) {
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}
function Get-ObjectKeys($Object) {
    return $Object.PSObject.Properties.name
}
function Get-ObjectValues($Object) {
    return $Object.PSObject.Properties.value
}
function Get-PaddedLength($Values) {
    return $Values | ForEach-Object { "$_".Length } | Sort-Object -Descending | Select-Object -First 1
}
function Get-Participant($Participants, $Id) {
    return $Participants | Where-Object { $_.id -eq $Id } | Select-Object -First 1
}

function Get-Leaderboard($CallApi, $Year, $Session, $LeaderboardId) {
    if ($CallApi) {
        Write-Info "Refreshing data..."
        $url = "https://adventofcode.com/$Year/leaderboard/private/view/$LeaderboardId.json"
        $response = Invoke-WebRequest -Method Get -Uri $url -UserAgent "PowerShell Slack-Integration (<your-email>) - homebrew script" -Headers @{ "Cookie" = "session=$Session" }
        Set-Content -Value $response.Content -Path .\result.json -Encoding utf8BOM
    }
    else {
        Write-Info "Using cached data..."
    }
    return Get-Content .\result.json -Encoding utf8BOM | ConvertFrom-Json
}
function Get-ScoreBoard() {
    $scoreboardMessage = "Current Scores:`n```````n"
    foreach ($participant in $participants) {      
        $index = $participant.position  
        $paddedIndex = "$index".PadRight($indexPadding)
        $paddedName = $participant.name.PadRight($namePadding)
        $paddedScore = "$($participant.local_score)".PadRight($scorePadding)

        if ($null -ne $specialScores."$index") {
            $paddedIndex = $specialScores."$index".PadRight($indexPadding)
        }
    
        $scoreboardMessage += "$paddedIndex) $paddedName $paddedScore ⭐ x $($participant.stars)`n"
    }

    $scoreboardMessage += "``````"
    return $scoreboardMessage
}
function Send-SlackMessage($message) {
    Write-Info "Sending slack message:"
    Write-Info $message
    if ($send_slack_message) {
        $body = @{ "text" = $message } | ConvertTo-Json
        $response = Invoke-WebRequest -Method Post -Uri $webhook -ContentType "application/json; charset=UTF-8" -Body $body
        if ($response.StatusCode -ne 200) {
            Write-Error "Failed to send slack message:"
            $response
        }
    }
}
#endregion


$codeblock = "``````"
$live = [bool]::Parse($live_refresh)
$timeout = [int]::Parse($timeout_seconds)
$timeout = [math]::max(900, $timeout) # 15 minutes, the minimum refresh rate
$leaderboardTime = '5:00'

[datetime]$epoch = '1970-01-01 00:00:00'
$specialScores = @{
    "1"     = "🥇"
    "2"     = "🥈"
    "3"     = "🥉"
    "_last" = "💐"
}

$init = $true
while ($true) {
    $previous = @{
        content      = $content
        participants = $participants
        members      = $members
        date         = $content.date
    }

    $content = Get-Leaderboard -CallApi ($live ) -Year $year -Session $session -LeaderboardId $leaderboard

    $members = Get-ObjectValues $content.members | Sort-Object -Descending -Property local_score
    $participants = $members  | Where-Object { $_.local_score -gt 0 } 
    
    $indexPadding = [math]::max(2, "$($participants.Length)".Length)
    $namePadding = Get-PaddedLength $participants.name
    $scorePadding = Get-PaddedLength $participants.local_score
    
    $i = 1
    foreach ($member in $members) {
        Add-Property -Object $member -Name "position" -Value $i
        $i++
    }

    Add-Property -Object $content -Name "date" -Value (Get-Date)
    Set-Content -Value ($content | ConvertTo-Json -Depth 20) -Path .\result.json  -Encoding utf8BOM

    if ($init) {
        $init = $false
        $previous = @{
            content      = $content
            participants = $participants
            members      = $members
            date         = $content.date
        }
    }

    $now = Get-Date
    $leaderBoardRefresh = [datetime]::parse($leaderboardTime).ToLocalTime()
    if($now -lt $leaderBoardRefresh -and ($now.AddSeconds($timeout) -gt $leaderBoardRefresh)) {
        Send-SlackMessage Get-ScoreBoard
    }

    # $gainedStars = @(@{ name = "", day = 1, part = 1, time = 10:32 })
    $gainedStars = @()

    if ($debug) {
        $previous.participants = $null
    }

    foreach ($participant in $participants) {
        $previousParticipant = Get-Participant -Participants ($previous.participants) -Id $participant.id

        if ($null -ne $previousParticipant -and ($participant.stars - $previousParticipant.stars) -eq 0) {
            continue;
        }
    
        foreach ($day in (Get-ObjectKeys $participant.completion_day_level)) {
            $previousDay = $null
            if ($null -ne $previousParticipant) {
                $previousDay = $previousParticipant.completion_day_level.$day
            }
    
            foreach ($part in (Get-ObjectKeys $participant.completion_day_level.$day)) {
                if ($null -eq $previousDay -or $null -eq $previousDay.$part) {
                    $gainedStars += @{
                        name = $participant.name
                        day  = $day
                        part = $part
                        time = $participant.completion_day_level.$day.$part.get_star_ts
                    }
                }
            }
        }
    }

    if ($gainedStars.Length -gt 0) {
        $message = @()
        $gainedStars | Sort-Object -Property time | ForEach-Object {
            $gained = $_
            $paddedName = $gained.name.PadRight($namePadding)
            $paddedDay = "$($gained.day)".PadRight(2)
            $paddedPart = $gained.part -eq "1" ? "1️⃣" : "2️⃣"
            $paddedTime = "{0:HH:mm:ss}" -f $epoch.AddSeconds($gained.time).ToLocalTime()
            $message += "$paddedName won a ⭐ for day $paddedDay part $paddedPart at $paddedTime 🎉"
        }
        # Messages can only be 55 lines long
        for ($i = 0; $i * 50 -lt $message.Length; $i++) {
            $text = $message | Select-Object -Skip ($i * 50) -First 50
            $text = $text -join "`n"
            $text = "$codeblock`n$text`n$codeblock"
            Send-SlackMessage $text
        }
    }

    [System.gc]::Collect()
    Write-Info "Sleeping for $timeout seconds... next check at $("{0:yyyy/MM/dd} {0:HH:mm:ss}" -f (Get-Date).AddSeconds($timeout).ToLocalTime())"
    Start-Sleep -Seconds $timeout
}
