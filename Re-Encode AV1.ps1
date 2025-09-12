# PowerShell 7+ Script: Re-Encode AV1.ps1
# ----- Config stuff, change only these if you don't know FFMPEG or the script as  whole. Otherwise fill in the blanks otherwise this won't work. -------

# ----FFMPEG pathings----
# Set this to the pathway where these files are stored. --REQUIRED--
# e.g: 'C:\Re-encode AV1\ffmpeg.exe'
$ffmpegPath            = 'ffmpeg.exe'
$ffprobePath           = 'ffprobe.exe'

# ----Text File names and pathings----
# Set these to pathways where your okay with .txt files being made that you once in a while view. --REQUIRED--
# e.g: 'C:\Re-encode AV1\logs\Queue.txt'
$queuebackupFile       = 'Queue backup.txt'
$queueFile             = 'Queue.txt'
# This text file will store all files that have been detected as being AV1 already, it will only be added to not compared against as it's just a log.
$alreadyAv1Log         = 'Already AV1.txt'
$errorLog              = 'Error Log.txt'
# This changes what text will be added to the end of re-encoded files
$global:outName        = 're-encoded'

# ----Debug mode----- Not much extra is revealed due to this
$global:debugmode      = $false

# -----Comparsion/auto deletion stuff-----
$compare               = $false
# If set to true will auto delete re-encoded files that are bigger than the source file.
$compareDel            = $false
# This text file is where any file that has had an re-encoded version end up bigger than itself will be logged.
# e.g: 'C:\Re-encode AV1\logs\Better Source.txt'
$bettersourceLog       = 'Better Source.txt'

# --WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING--

# Only set this to true if you are okay with source files being deleted, this does not move files to recycle bin it straight up deletes them. 
# You cannot recover the deleted files. If you accept this risk and have compare set to $true then change the following to $true and for the next entry remove: '' #
$sourceDel             = $false
$DeleteSourceLog       = '' #'Deleted Sources Log.txt'

# --WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING--

# --Video extensions recognized--
$videoExts             = @('.mp4', '.mkv', '.webm', '.mov', '.avi', '.flv', '.wmv', '.m4v', '.ts', '.mts', '.m2ts', '.mpeg', '.mpg', '.3gp', '.3g2')

# ----Batch defaults----
# So if you want to change the default settings of batch encoding then change these otherwise skip this section.

# --CRF--
# The higher the number the worse quality the re-encoded video becomes, however the size decreases even more and processing speed is increased.
# Due to AV1 recommended is 30 as highest value to keep good quality with great size reduction, x265 is still best for size reduction.

$global:batchCRF       = 30

# --Auto scaling--
# Copy and paste any of these into batchScale, use the end number of each one for monitor except last one due to auto-scaling. Only use the "" if you don't want any de-scaling to occur AND set monitor to something like 10000
# "scale='min(3840,iw)':2160"
# "scale='min(2560,iw)':1440"
# "scale='min(1920,iw)':1080"
# "scale='min(1280,iw)':720"
# ""

$global:batchScale     = ""
$global:monitor        = 2160
# This will overide batchScale BUT only if batchScale is left empty and video height is more than monitor is set to. This is also used outside of batch mode.
$global:monitorScale   = "scale='min(3840,iw)':2160"

# This one is specifically when your turning an VR video into 2D one, do not leave it empty. (2D section is very uncooked and needs work that I currently can't give it yet)
# "w=3840:h=2160" 
# "w=2560:h=1440" 
# "w=1920:h=1080" 
# "w=1280:h=720" 

$global:monitorScaleVR = "w=3840:h=2160" 

# --Presets--
# Don't set VR preset to less than 8 otherwise encoding WILL FAIL!!! FFMPEG can't do it currently.

$global:batchPreset    = 6
$global:batchVRPreset  = 8

# ----CPU usage/masking----
# Set this to 0 if you want to allow FFMPEG to use all CPU, only change if you know how to set an processor affinity mask hex (google it).
$global:affinityMask   = 0

# Replace what's inside the brackets with one of these to set tell your computer if it can divert resources away going from "divert next to everything" to "divert nothing", do not leave it empty.
# Idle is recommended for background encoding so you can use your computer.
# Idle, BelowNormal, Normal, AboveNormal, High, RealTime.
$global:prioritylevel  = "Idle"


# --------------- End of config stuff ---------------

# Abort flags --- Do Not Change ---
$global:abortNow          = $false   # kill current ffmpeg and stop
$global:abortAfterCurrent = $false # finish current ffmpeg, then stop


# --------------- Graceful FFmpeg cancellation on Ctrl-C or exit ---------------
# This will capture Ctrl-C or script termination and kill the running ffmpeg.
$global:currentFFmpeg = $null

# Register handler for Ctrl-C / console close
Register-EngineEvent -SourceIdentifier ConsoleCancelEvent -Action {
    if ($global:currentFFmpeg -and -not $global:currentFFmpeg.HasExited) {
        Write-Host "`nCaught Ctrl‑C or exit—stopping ffmpeg..." -ForegroundColor Yellow
        try { $global:currentFFmpeg.Kill() } catch {}
    }
} | Out-Null



function ChoicePrompt($prompt, $choices, $default) {
    $choiceKeys = $choices -join '/'
    $defaultKey = $default.ToUpper()
    $msg = "$prompt [$choiceKeys] (default: $defaultKey): "
    Write-Host $msg -NoNewline

    while ($true) {
        $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $key = [string]$keyInfo.Character

        # Handle Enter key (no character)
        if ($keyInfo.VirtualKeyCode -eq 13) {
            Write-Host $defaultKey
            return $defaultKey
        }

        $key = $key.ToUpper()
        Write-Host $key

        if ($choices -contains $key) {
            return $key
        }
    }
}



function Read-Host-Default($prompt, $default) {
    $msg = if ($default) { "$prompt [$default]" } else { $prompt }
    $resp = Read-Host $msg
    if ([string]::IsNullOrWhiteSpace($resp)) { return $default } else { return $resp }
}

function Get-VideoFiles($paths) {
    $all = @()
    foreach ($p in $paths) {
        $p = $p.ToString()
        if (Test-Path -LiteralPath $p -PathType Container) {
            $scanSubs = ChoicePrompt "Scan subfolders in '${p}' too?" @('Y','N') 'Y'
            if ($scanSubs -eq 'Y') {
                $files = Get-ChildItem -LiteralPath $p -Recurse -File
            } else {
                $files = Get-ChildItem -LiteralPath $p -File
            }
            $all += $files | Where-Object { $videoExts -contains $_.Extension.ToLower() } | Select-Object -ExpandProperty FullName
        } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            if ($videoExts -contains ([System.IO.Path]::GetExtension($p).ToLower())) { $all += $p }
        }
    }
    return $all
}

function ffprobe-codec($file) {
    & $ffprobePath -v error -select_streams v:0 -show_entries stream=codec_name -of default=nokey=1:noprint_wrappers=1 -- "$file" 2>$null
}

function ffprobe-height($file) {
    [int](& $ffprobePath -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 -- "$file" 2>$null)
}

function ffprobe-duration($file) {
    [double](& $ffprobePath -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 -- "$file" 2>$null)
}

function Queue-Add([string]$ffmpegPath, [string]$ffmpegArgs, [string]$file) {
    Add-Content -LiteralPath $queueFile "$ffmpegPath|$ffmpegArgs"
    Write-Host "[QUEUED] $file" -ForegroundColor Cyan
}

function Confirm-Continue($settings) {
    Write-Host '------------------------------'
    foreach ($line in $settings) { Write-Host $line }
    Write-Host '------------------------------'
    $resp = ChoicePrompt 'Proceed with these settings?' @('Y','N') 'Y'
    return ($resp -eq 'Y')
}

# ==== Show FFMPEG Progress ====

function Show-FFmpeg-Progress($ffmpegPath, $ffmpegArgs, $inputFile) {
    $durationSec = ffprobe-duration $inputFile

    Write-Host "Please allow 30 seconds for the process to fully start up." -ForegroundColor Yellow
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName        = $ffmpegPath
    $psi.Arguments       = $ffmpegArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError  = $true
    $psi.RedirectStandardOutput = $false
    $psi.CreateNoWindow  = $true
    $elapsedSec  = 0
    $startupLoop = 0

    $proc = [System.Diagnostics.Process]::Start($psi)

    $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]$global:priorityLevel
    if ($global:affinityMask -ne 0) {
        $proc.ProcessorAffinity = [intptr]$global:affinityMask
    }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()

    if($global:debugmode -eq $true){
        Write-Host "[DEBUG MODE IS ON] While loop for progress tracking and exit key begining" -ForegroundColor Blue
    }                
    while ($proc -and (-not $proc.HasExited -or -not $proc.StandardError.EndOfStream)) {
        if($global:debugmode -eq $true -and $startupLoop -lt 1){
            Write-Host "[DEBUG MODE IS ON] While loop started. " -ForegroundColor Blue
        }
        # Non-blocking read from FFmpeg stderr
        if ($proc.StandardError.Peek() -ne -1) {
            $line = $proc.StandardError.ReadLine()
            if($global:debugmode -eq $true -and $startupLoop -lt 100){
                Write-Host "[DEBUG MODE IS ON] line variable is: $line. " -ForegroundColor Yellow
            }
            if ($line) {
                # Duration getting
                if (-not $durationSec -and $line -match "Duration:\s+(\d+):(\d+):(\d+).(\d+)") {
                    # Parse total duration
                    $h = [int]$matches[1]; $m = [int]$matches[2]; $s = [int]$matches[3]
                    $durationSec = ($h * 3600) + ($m * 60) + $s
                    if($global:debugmode -eq $true){
                        Write-Host "[DEBUG MODE IS ON] Fall back triggered and detected duration: $h :$m :$s or a total of $durationSec seconds. " -ForegroundColor Blue
                    }
                }

                if ($line -match "time=(\d+):(\d+):(\d+).(\d+)") {
                    $h = [int]$matches[1]; $m = [int]$matches[2]; $s = [int]$matches[3]
                    $elapsedSec = ($h * 3600) + ($m * 60) + $s

                }

                    # Calculate % if we know duration
                if ($durationSec -gt 0 -and $elapsedSec -gt 0) {
                    $pct = [math]::Round(($elapsedSec / $durationSec) * 100, 1)
                    $etaSec = [math]::Max($durationSec - $elapsedSec, 0)
                    $eta = [TimeSpan]::FromSeconds($etaSec).ToString("hh\:mm\:ss")

                    Write-Host ("`rProgress: {0}% | ETA: {1}   " -f $pct, $eta) -NoNewline -ForegroundColor Green
                    [System.Console]::Out.Flush()
                    if($startupLoop -lt 100){
                        $startupLoop = 100
                    }
                }
              }
            }
        
        # Check for Q key press without blocking
        if ([Console]::KeyAvailable) {
            if($global:debugmode -eq $true){
                Write-Host "[DEBUG MODE IS ON] Entered Q key check." -ForegroundColor Blue
            }
                $keyInfo = [Console]::ReadKey($true)  # true = do not echo
                if ($keyInfo.KeyChar -eq 'q' -or $keyInfo.KeyChar -eq 'Q') {
                    if($global:debugmode -eq $true){
                        Write-Host "[DEBUG MODE IS ON] Q check ran and returned $keyInfo" -ForegroundColor Blue
                    }
                    $abortChoice = ChoicePrompt "`nAbort now or after current job? N=Now, A=After" @('N','A') 'A'
                    if ($abortChoice -eq 'N') {
                        Write-Host "`n[ABORT NOW] Stopping current encoding..."
                        try { $proc.Kill() } catch {}
                        $bn  = [IO.Path]::GetFileNameWithoutExtension($inputFile)
                        $dir = Split-Path $inputFile -Parent
                        $outputFile = Join-Path $dir "$bn $global:outName.mkv"
                        Start-Sleep -Milliseconds 5000
                        Remove-Item -LiteralPath $outputFile -Force 
                        $global:abortNow  = $true
                        if($global:debugmode -eq $true){
                            Write-Host "[DEBUG MODE IS ON] Abort after current triggered and variable is set to: $global:abortNow" -ForegroundColor Blue
                        }
                        return
                    } elseif ($abortChoice -eq 'A') {
                        Write-Host "`n[ABORT AFTER] Will stop after this job."
                        $global:abortAfterCurrent = $true
                        if($global:debugmode -eq $true){
                            Write-Host "[DEBUG MODE IS ON] Abort after current triggered and variable is set to: $global:abortAfterCurrent" -ForegroundColor Blue
                        }
                    }
                }
            
        }
        if($startupLoop -lt 100){
            $startupLoop++
            if($global:debugmode -eq $true){
                Write-Host "[DEBUG MODE IS ON] Fast Sleep code block (active until progress bar appears) - startupLoop variable is: $startupLoop. " -NoNewline -ForegroundColor Blue
            }
            Start-Sleep -Milliseconds 50  # To get progress bar going.
        }
        else{
            Start-Sleep -Milliseconds 1000  # keep loop responsive, avoid CPU hogging occuring
        }
    }

    


    $proc.WaitForExit()
    $global:LASTEXITCODE = $proc.ExitCode
    $stopwatch.Stop()

    if ($proc.HasExited -and $proc.ExitCode -eq 0 -and -not $global:abortNow) {
        $timeTaken = $stopwatch.Elapsed.ToString("hh\:mm\:ss")
        Write-Host ("`rProgress: 100% | Time Taken: {0}    [DONE]" -f $timeTaken) -ForegroundColor Green
        Write-Host ("Pausing for 30 seconds to allow everything to fully finish") -ForegroundColor Blue
        Start-Sleep -Milliseconds 30000  # To allow Computer respite of 30 seconds and to finish up FFMPEG process

        if($compare -eq $true){
            if($global:debugmode -eq $true){
                Write-Host "[DEBUG MODE IS ON] Comparision started" -ForegroundColor Yellow
            }
            if (Test-Path -LiteralPath $inputFile) {
                # Derive expected output path from input file name
                $bn  = [IO.Path]::GetFileNameWithoutExtension($inputFile)
                $dir = Split-Path $inputFile -Parent
                $outputFile = Join-Path $dir "$bn $global:outName.mkv"
                if($global:debugmode -eq $true){
                    Write-Host "[DEBUG MODE IS ON] inputFile returned $inputFile so now outputFile is $outputFile  ...." -ForegroundColor Blue
                }
            }
            else{
                if (Test-Path -LiteralPath $infile) {
                    # Derive expected output path from input file name
                    $bn  = [IO.Path]::GetFileNameWithoutExtension($infile)
                    $dir = Split-Path $infile -Parent
                    $outputFile = Join-Path $dir "$bn $global:outName.mkv"
                    $inputFile = $infile
                    if($global:debugmode -eq $true){
                        Write-Host "[DEBUG MODE IS ON] infile returned $inputFile so now outputFile is $outputFile  ...." -ForegroundColor Blue
                    }
                }
                else{
                    Write-Host "Error with getting input file path for comparision, Enable Debug mode for more details and rerun." -ForegroundColor Red
                    if($global:debugmode -eq $true){
                        Write-Host "[DEBUG MODE IS ON] inputFile returned $inputFile and infile returned $infile while outputfile returned $outputFile  ...." -ForegroundColor Red
                    }
                }
            }
            # Compare sizes if output exists
            if (Test-Path -LiteralPath $outputFile) {
                if($global:debugmode -eq $true){
                    Write-Host "[DEBUG MODE IS ON] Passed Test-Path if() ...." -ForegroundColor Blue
                }
                $NewFileSize = (Get-Item -LiteralPath $outputFile).Length
                $OldFileSize = (Get-Item -LiteralPath $inputFile).Length
                $percentDiff = [math]::Round((($NewFileSize - $OldFileSize) / $OldFileSize) * 100, 2)

                    if($NewFileSize -lt $OldFileSize){
                        if($global:debugmode -eq $true){
                            Write-Host "[DEBUG MODE IS ON] sourceDel returns $sourceDel" -ForegroundColor Blue
                        }
                        if($sourceDel -eq $true -and -not [string]::IsNullOrWhiteSpace($DeleteSourceLog)){
                            Write-Host "[AUTO SOURCE DELETE IS ON] New file is smaller by roughly $(-$percentDiff)%. Source file has been deleted." -ForegroundColor Yellow
                            Add-Content -literalPath $DeleteSourceLog -Value "$outputFile was smaller by $percentDiff% and Auto source delete was on so $inputFile was deleted"
                            Remove-Item -LiteralPath $inputfile -Force                          
                        }
                        else{
                            Write-Host "New file is smaller by roughly $(-$percentDiff)%." -ForegroundColor Green
                        }
                    }
                    else{
                        if($global:debugmode -eq $true){
                            Write-Host "[DEBUG MODE IS ON] compareDel returns $compareDel" -ForegroundColor Blue
                            $global:bigSourceCount++
                        }                        
                        if($compareDel -eq $true){
                            Write-Host "New file is bigger by roughly $percentDiff%. Auto-deleting new file and logging..." -ForegroundColor Red
                            Add-Content -literalPath $bettersourceLog -Value "$inputFile was smaller by $percentDiff%"
                            Remove-Item -LiteralPath $outputFile -Force 
                            $global:bigSourceCount++               
                        }
                        else{
                            Write-Host "New file is bigger by roughly $percentDiff%. Auto-delete is disabled so file is preserved and logging..." -ForegroundColor Red
                            Add-Content -literalPath $bettersourceLog -Value "$inputFile was smaller by $percentDiff%"
                            $global:bigSourceCount++
                        }
                    }
            }
            else{
                Write-Host "Error with getting output file path for comparision, got: $outputFile" -ForegroundColor Red
            }
        }

    } elseif ($global:abortNow) {
        Write-Host "`r[ABORTED]" -ForegroundColor Red
    } else {
        # Convert to unsigned 32-bit hex so we can see the NTSTATUS/Windows error code
        $hexCode = "{0:X}" -f ($proc.ExitCode -band 0xFFFFFFFF)
        Write-Host "`r[ERROR] (Exit $($proc.ExitCode) / 0x$hexCode) Logged into ErrorLog file." -ForegroundColor Red
        Add-Content -literalPath $errorLog -Value "$inputFile couldn't complete encode error code:(Exit $($proc.ExitCode) / 0x$hexCode)"
    }
}




# ==== Main Logic ====
$cliArgs = @($args)
if ($cliArgs.Count -eq 0) {
    Write-Host "Drop files or folders onto the .bat launcher, or run and enter paths manually." -ForegroundColor Blue
    $inp = Read-Host "> "
    $items = $inp -split '\s+'
} else {
    $items = $cliArgs
}

# If queue file is passed as first argument, run queue mode
$queueMode = $false
if ($items.Count -eq 1 -and (Split-Path -Path $items[0] -Leaf).ToLower() -eq (Split-Path -Path $queueFile -Leaf).ToLower()) {
    if($global:debugmode -eq $true){
        Write-Host "[DEBUG MODE IS ON] Detected queue file as argument: $($items[0]) - Starting Batch Mode." -ForegroundColor Blue
    }
    else{
        Write-Host "Detected queue file....starting batch mode."
    }
    $queueFile = $items[0]  # Override path if user dropped a queue
    $queueMode = $true
}


if (-not $queueMode) {
        $videoFiles = Get-VideoFiles $items | Get-Unique
        if (-not $videoFiles) {
            Write-Host "No video files found."; exit -ForegroundColor Red
        }


    Write-Host "[INFO] Files queued for checks and prompts:"
    $videoFiles | ForEach-Object { Write-Host "  $_" }

    $bulk = ChoicePrompt "Apply defaults to all $($videoFiles.Count) files?" @('Y','N') 'N'
    
    if ($bulk -eq 'Y') {

        $bulkVR = ChoicePrompt "Is this an VR queue?" @('Y','N') 'N'

        foreach ($in in $videoFiles) {
            $scale = ""
            $codec = ffprobe-codec $in
            if ($codec -eq 'av1') {
                Add-Content -LiteralPath $alreadyAv1Log $in
                $reAV1 = ChoicePrompt "File is AV1: $in`nRe-encode this AV1 file anyway?" @('Y','N') 'N'
                if ($reAV1 -ne 'Y') {
                    Write-Host "[SKIP] $in (already AV1)" -ForegroundColor DarkYellow
                    continue
                }
            }

            $height = ffprobe-height $in
            if ($bulkVR -eq 'N' -and $global.batchScale -eq ""){
                if($global:debugmode -eq $true){
                    Write-Host "[DEBUG MODE IS ON] " -ForegroundColor Blue
                    Write-Host "Batch Downscale correction triggered, bulkVR: $bulkVR, Set monitor: $global:monitor, Set batchScale: $global:batchScale, File is: $in" -ForegroundColor Yellow
                }
                $scale = $global.batchScale
            }
            elseif($bulkVR -eq 'N' -and $height -gt $global:monitor -and $global:batchScale -eq ""){
                if($global:debugmode -eq $true){
                    Write-Host "[DEBUG MODE IS ON] " -ForegroundColor Blue
                    Write-Host "Monitor Downscale correction triggered, bulkVR: $bulkVR, Detected height: $height, Set monitor: $global:monitor, Set batchScale: $global:batchScale, File is: $in" -ForegroundColor Yellow
                }  
                $scale  = $global:monitorScale     
            }

            if ($bulkVR -eq 'Y') {

                $bn  = [IO.Path]::GetFileNameWithoutExtension($in)
                $out = Join-Path (Split-Path $in -Parent) "$bn $global:outName.mkv"

                $args = "-i `"$in`" -map 0 -map_metadata:g 0 -map_metadata:s -1 -metadata:s:v:0 stereo_mode=mono -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf $global:batchCRF -preset $global:batchVRPreset -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy `"$out`""
                Queue-Add $ffmpegPath $args $in

            }
            else{
                $bn  = [IO.Path]::GetFileNameWithoutExtension($in)
                $out = Join-Path (Split-Path $in -Parent) "$bn $global:outName.mkv"

                $flt = if ($scale -ne "") { "-filter_complex [0:v]$scale[vf] -map [vf]" } else { '-map 0:v' }
                $args = "-i `"$in`" $flt -map 0:a? -map 0:s? -map_metadata:g 0 -map_metadata:s -1 -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf $global:batchCRF -preset $global:batchPreset -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy `"$out`""
                Queue-Add $ffmpegPath $args $in
            }
        }

        Write-Host 'All files queued with defaults.'
    }
    if ($bulk -eq 'N') {
    foreach ($input in $videoFiles) {
            $basename = [System.IO.Path]::GetFileNameWithoutExtension($input)
            Write-Host "`n[PROCESSING] $input"
            $alreadyAV1 = $false
            $codec = ffprobe-codec $input
            if ($codec -eq 'av1') {
                $alreadyAV1 = $true
                Add-Content -LiteralPath $alreadyAv1Log $input
                $reAV1 = ChoicePrompt "File is AV1: $basename`nRe-encode this AV1 file anyway?" @('Y','N') 'N'
                if ($reAV1 -ne 'Y') { Write-Host "[SKIP] $basename"; continue }
            }

            while ($true) {
                Write-Host "[SETTINGS FOR] $input"
                $crf = Read-Host-Default 'Change CRF?' '30'
                $newname = Read-Host-Default 'Change filename? (blank = same)' $basename
                $isVR = ChoicePrompt 'Is this a VR/360 video?' @('Y','N') 'N'
                if ($isVR -eq 'Y') {
                    $vr2d = ChoicePrompt 'Convert VR video to 2D?' @('Y','N') 'N'
                    if ($vr2d -eq 'Y') {
                        $isFish = ChoicePrompt 'Is this an Fisheye VR video?' @('Y','N') 'N'
                        if($isFish -eq 'Y'){
                            $fishFov = Read-Host-Default 'What is the Fisheye FOV? (default 125)' '125'
                        }
                        $fov = Read-Host-Default 'Change CRF? (default 125)' '125'
                        $pitch = Read-Host-Default 'Change Pitch? (default -25)' '-25'
                        $height = ffprobe-height $input
                        if (-not $height) {
                            $height = '?'
                        }
                        $downopt = ChoicePrompt "Do you want to draft encode to check Pitch & FOV settings?" @('Y','N') 'N'
                        switch ($downopt) {
                            'Y' { 
                            $preset = 13
                            $crf = 51
                            $outpath = Join-Path (Split-Path $input -Parent) "$newname 2D-ed DRAFT $fov $pitch.mkv"
                            }
                            'N' { 
                            $preset = 6
                            $outpath = Join-Path (Split-Path $input -Parent) "$newname 2D-ed.mkv"
                            }
                        }
                        $draftopt = ChoicePrompt "What resolution do you want the video to be? 1=2160, 2=1440p, 3=1080p, 4=720p, M=Monitor" @('1','2','3','4','M') 'M'
                        switch ($draftopt) {
                            '1' { $scale = "w=3840:h=2160" }
                            '2' { $scale = "w=2560:h=1440" }
                            '3' { $scale = "w=1920:h=1080" }
                            '4' { $scale = "w=1280:h=720" }
                            'M' { $scale = $global:monitorScaleVR }
                        }
                        if($isFish -eq 'Y'){
                            $ffmpegArgs = '-i "'+$input+'" -filter:v "v360=input=fisheye:ih_fov='+$FishFov+':iv_fov='+$FishFov+'":output=flat:in_stereo=sbs:out_stereo=2d:d_fov='+$fov+':'+$scale+':pitch='+$pitch+'" -map 0 -map_metadata:g 0 -map_metadata:s -1 -metadata:s:v:0 stereo_mode=mono -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf '+$crf+' -preset '+$preset+' -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy "'+$outpath+'"'
                            $settings = @(
                            "File:        $input",
                            "Output:      $outpath",
                            "CRF:         $crf",
                            "FishFov:     $FishFov",
                            "Fov:         $fov",
                            "Pitch:       $pitch",
                            "Draft?:      $downopt",
                            "Resolution:  $scale",
                            "VR:          Y (2D conversion)"
                            )
                        }
                        else{
                            $ffmpegArgs = '-i "'+$input+'" -filter:v "v360=input=hequirect:output=flat:in_stereo=sbs:out_stereo=2d:d_fov='+$fov+':'+$scale+':pitch='+$pitch+'" -map 0 -map_metadata:g 0 -map_metadata:s -1 -metadata:s:v:0 stereo_mode=mono -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf '+$crf+' -preset '+$preset+' -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy "'+$outpath+'"'
                            $settings = @(
                            "File:        $input",
                            "Output:      $outpath",
                            "CRF:         $crf",
                            "Fov:         $fov",
                            "Pitch:       $pitch",
                            "Draft?:      $downopt",
                            "Resolution:  $scale",
                            "VR:          Y (2D conversion)"
                            )
                        }
                        if (Confirm-Continue $settings) {
                            Queue-Add $ffmpegPath $ffmpegArgs $input
                            break
                        } 
                        else {
                            continue
                        }
                    }
                    else{
                        $outpath = Join-Path (Split-Path $input -Parent) "$newname $global:outName.mkv"
                        $ffmpegArgs = '-i "'+$input+'" -map 0 -map_metadata:g 0 -map_metadata:s -1 -metadata:s:v:0 stereo_mode=mono -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf '+$crf+' -preset 8 -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy "'+$outpath+'"'
                        $settings = @(
                            "File:      $input",
                            "Output:    $outpath",
                            "CRF:       $crf",
                            "VR:        $isVR"
                        )
                        if (Confirm-Continue $settings) {
                            Queue-Add $ffmpegPath $ffmpegArgs $input
                            break
                        }
                        else {
                        continue                         
                        }                    
                    }
                }
                $height = ffprobe-height $input
                if (-not $height) {
                    $height = '?'
                }
                $downopt = ChoicePrompt "Downscale video? (Current height: $height) 1=1440p, 2=1080p, 3=720p, N=none" @('1','2','3','N') 'N'
                switch ($downopt) {
                    '1' { $scale = "scale='min(2560,iw)':1440" }
                    '2' { $scale = "scale='min(1920,iw)':1080" }
                    '3' { $scale = "scale='min(1280,iw)':720" }
                    'N' { $scale = '' }
                }
                if ($isVR -eq 'N' -and $downopt -eq 'N' -and $height -gt $global:monitor){
                    $scale = $global:monitorScale
                }
                if ($isVR -eq 'Y') {
                    $preset = ChoicePrompt "Is the video ($height) higher than 4k (3000)?" @('6','8') '6'
                }
                else{
                    $preset = '6'
                }
                $downscaleDesc = if ($scale) { "Downscale: $scale" } else { "Downscale: none" }
                $settings = @(
                    "File:      $input",
                    "Output:    $newname $global:outName.mkv",
                    "CRF:       $crf",
                    "VR:        $isVR",
                    $downscaleDesc,
                    "Preset:    $preset"
                )
                if (Confirm-Continue $settings) {
                    $filter = if ($scale) { '-filter_complex [0:v]'+$scale+'[vf] -map [vf]' } else { '' }
                    $sourceFolder = Split-Path $input -Parent
                    $outpath = Join-Path $sourceFolder "$newname $global:outName.mkv"
                    $ffmpegArgs = '-i "'+$input+'" '+$filter+' -map 0 -map_metadata:g 0 -map_metadata:s -1 -c:v libsvtav1 -pix_fmt yuv420p10le -fps_mode passthrough -crf '+$crf+' -preset '+$preset+' -svtav1-params fast-decode=1:enable-qm=1:enable-overlays=1:enable-tf=0:scd=0 -c:a copy -c:s copy "'+$outpath+'"'
                    Queue-Add $ffmpegPath $ffmpegArgs $input
                    break
                } 
                else {
                    continue 
                }
            }
        }
    }
}

if ($queueMode -eq $false){
    Write-Host "`nQueue saved to $queueFile."
}
if ((ChoicePrompt 'Start encoding now?' @('Y','N') 'N') -eq 'Y') {
    # Read all queued lines
    $lines = Get-Content -LiteralPath $queueFile
    Set-Content -LiteralPath $queuebackupFile $lines
    $remaining = [System.Collections.Generic.List[string]]::new([string[]]$lines)
    $totalJobs = ($lines | Where-Object { $_.Trim() }).Count
    $currentJob = 0
    $failJobs = 0
    $global:bigSourceCount = 0

    foreach ($line in $lines) {
        if (-not $line.Trim()) {
            continue
        }

        $currentJob++

        # Split out ffmpeg path and args
        $parts      = $line -split '\|',2
        $ffmpegPath = $parts[0].Trim('"')
        $ffmpegArgs = $parts[1].Trim()

        # Try to extract input file for progress
        if ($ffmpegArgs -match '-i\s+"([^"]+)"') {
            $infile = $matches[1]
        } 
        else {
            Write-Host "WARNING: could not extract input from args; skipping progress display"
            $infile = $null
        }

        # Show where we are in the queue
        $bn = if ($infile) { [IO.Path]::GetFileNameWithoutExtension($infile) } else { "<unknown>" }
        if($global:debugmode -eq $true){
            Write-Host -NoNewline "[DEBUG MODE IS ON] Starting to encode: " -ForegroundColor Blue
            Write-Host -NoNewline "$ffmpegPath $ffmpegArgs (Job "
            Write-Host -NoNewline "$currentJob" -ForegroundColor Green
            Write-Host -NoNewline "/"
            Write-Host -NoNewline "$totalJobs" -ForegroundColor Blue
            Write-Host -NoNewline ", "
            Write-Host -NoNewline "$failJobs " -ForegroundColor Red
            Write-Host -NoNewline "Jobs failed, "
            Write-Host -NoNewline "$global:bigSourceCount " -ForegroundColor Yellow
            Write-Host "total bigger files)"
        }
        else{
            Write-Host -NoNewline "Starting to encode: "
            Write-Host -NoNewline "$bn (Job "
            Write-Host -NoNewline "$currentJob" -ForegroundColor Green
            Write-Host -NoNewline "/"
            Write-Host -NoNewline "$totalJobs" -ForegroundColor Blue
            Write-Host -NoNewline ", "
            Write-Host -NoNewline "$failJobs " -ForegroundColor Red
            Write-Host -NoNewline "Jobs failed, "
            Write-Host -NoNewline "$global:bigSourceCount " -ForegroundColor Yellow
            Write-Host "total bigger files)"
        }

        # Run and show progress
        Show-FFmpeg-Progress $ffmpegPath $ffmpegArgs $infile

        if ($global:abortNow) {
            if($global:debugmode -eq $true){
                Write-Host "[DEBUG MODE ON] Aborting queue immediately triggered — current and remaining encodes will be preserved." -ForegroundColor Yellow
            }
            break
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]   Removed from queue:" $bn -ForegroundColor Green
            if ($global:debugmode -eq $true) {
                Write-Host "[DEBUG MODE IS ON] line variable is currently: $line" -ForegroundColor Blue
            } 
            [void]$remaining.Remove($line)   # success → drop from queue
        } 
        else {
            Write-Host "[FAIL] Kept in queue for retry:" $bn -ForegroundColor Red
            $failJobs++
            # leave in $remaining
        }

        if ($global:abortAfterCurrent) {
            if($global:debugmode -eq $true){
                Write-Host "[DEBUG MODE ON] Aborting after current job is triggered - no new encodes will be started." -ForegroundColor Yellow
            }
            break
        }

        # Persist updated queue after each job
        Set-Content -LiteralPath $queueFile -Value $remaining
    }

    # Final write to ensure queue is saved even if loop exits early
    Set-Content -LiteralPath $queueFile -Value $remaining

    Write-Host "`nFinished processing queue."
    $successJobs = $totalJobs - $remaining.Count
    if ($remaining.Count -gt 0) {
        if ($global:debugmode -eq $true) {
            Write-Host "[DEBUG MODE IS ON] Detected Jobs still in queue, now will print out remaining jobs... (`"$queueFile`"):" -ForegroundColor Blue
            $remaining | ForEach-Object { Write-Host "  $_" }
            Write-Host -NoNewline "End Of Queue Summary: "
            Write-Host -NoNewline "$totalJobs " -ForegroundColor Blue
            Write-Host -NoNewline "total jobs, "
            Write-Host -NoNewline "$successJobs " -ForegroundColor Green
            Write-Host -NoNewline "completed jobs, "
            Write-Host -NoNewline "$global:bigSourceCount " -ForegroundColor Yellow
            Write-Host -NoNewline "total bigger files, "
            Write-Host -NoNewline "$failJobs " -ForegroundColor Red
            Write-Host -NoNewline "jobs failed, "
            Write-Host -NoNewline "$($remaining.Count) " -ForegroundColor Yellow
            Write-Host "jobs remaining in queue."
        } 
        else {
            Write-Host -NoNewline "End Of Queue Summary: "
            Write-Host -NoNewline "$totalJobs " -ForegroundColor Blue
            Write-Host -NoNewline "total jobs, "
            Write-Host -NoNewline "$successJobs " -ForegroundColor Green
            Write-Host -NoNewline "completed jobs, "
            Write-Host -NoNewline "$global:bigSourceCount " -ForegroundColor Yellow
            Write-Host -NoNewline "total bigger files, "
            Write-Host -NoNewline "$failJobs " -ForegroundColor Red
            Write-Host -NoNewline "jobs failed, "
            Write-Host -NoNewline "$($remaining.Count) " -ForegroundColor Yellow
            Write-Host "jobs remaining in queue."
        }        
    }
    else{
        Write-Host -NoNewline "End Of Queue Summary: "
        Write-Host -NoNewline "$totalJobs " -ForegroundColor Blue
            Write-Host -NoNewline "total jobs, "
        Write-Host -NoNewline "$successJobs " -ForegroundColor Green
            Write-Host -NoNewline "completed jobs, "
        Write-Host -NoNewline "$global:bigSourceCount " -ForegroundColor Yellow
            Write-Host -NoNewline "total bigger files, "
        Write-Host -NoNewline "$failJobs " -ForegroundColor Red

            Write-Host -NoNewline "jobs failed."    
    } 
}
else {
    Write-Host "You can resume later by running the script and loading $queueFile."
}

