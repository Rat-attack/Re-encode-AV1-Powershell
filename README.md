# Re-encode-AV1-Powershell
Setup to be an easy to use powershell script that enables anyone to re-encode singular or mass amounts of video files via using FFMPEG and FFProbe. 
Some manual configuration is required to setup file paths. 
This does have limited functionality to convert VR videos to 2D singularlly only. 
All code should be visible with exception to FFMPEG FFProbe files.

This was made with ChatGPT AI help so there is a lot of inconsistansies that are in the code however after using it personally and reinfining it for maybe 2 months after porting the CMD .BAT version to Powershell to have an GUI and overall cleaner look.

In the process of making this I used FFMPEG version 7.01, you need to download FFMPEG and FFProbe from here yourself: https://www.ffmpeg.org/download.html 
I personally used this github page: https://github.com/GyanD/codexffmpeg/releases which you can get to via the Windows download section of FFMPEG.org via gyan.dev which takes you to another site where after scrolling down to "Release Builds" you'll see "mirror @ github" and that link there will take you to the same github page. (specifically the latest build)

--

Setup to do after downloading

If you don't do this setup, nothing will work correctly. Inside the .PS file there should be comments that explain briefly each configurable thing with examples of how to setup incase you skip this.

So first of all is the FFMPEG stuff as without setting this, of course it won't work, best way to do it is to go to the folder that has the two .exe's in it and copy and paste the windows explorer path into the spot (the folder needs to be read-able and not hidden). See an example below:
# ----FFMPEG pathings----
# Set this to the pathway where these files are stored. --REQUIRED--
# e.g: 'C:\Re-encode AV1\ffmpeg.exe'
$ffmpegPath            = 'ffmpeg.exe'
$ffprobePath           = 'ffprobe.exe'

Next up is the text files to log/store all the information so nearly anything that goes wrong with the script can be read afterwards if (somehow as it hasn't happened yet to me) your computer crashes from this or you close the CMD Window. Setting these up are the same as FFMPEG however you just need an empty folder as the script will create all the text files itself, it just needs to know where is okay to do so. 
I do recommend that you have Queue.txt be easy to drag and drop onto "Re-encode AV1 launcher.bat" as that is the launcher for the .PS file which is the script itself. (the .bat file is apparently the best way to get stuff to the script as files can't be dropped straight into an .PS file)
Note: Default errors aren't saved to any files, only stuff I've setup to save to text files will. (I haven't looked up or thought until writing this to look up about doing so)

# ----Text File names and pathings----
# Set these to pathways where your okay with .txt files being made that you once in a while view. --REQUIRED--
# e.g: 'C:\Re-encode AV1\logs\Queue.txt'
$queuebackupFile       = 'Queue backup.txt'
$queueFile             = 'Queue.txt'
# This text file will store all files that have been detected as being AV1 already, it will only be added to not compared against as it's just a log.
$alreadyAv1Log         = 'Already AV1.txt'
$errorLog              = 'Error Log.txt'

This you do not set a path for inside your computer, it is just to make it so when a file is re-encoded via the script it doesn't result in it overwriting the original file. (there's an setting below to make it so that the source file does get deleted if the re-encoded file is smaller than the source file)

# This changes what text will be added to the end of re-encoded files
$global:outName        = 're-encoded'

If you know what debug mode usually means then I don't need to really explain this but this just changes/enables a few more commands to output text to help give you more detail if something has gone wrong and you fancy troubleshooting it yourself. This doesn't as a result prevent default error codes being shown by the script which normally show which line of the script caused the error...also these default errors aren't saved to any files.

# ----Debug mode----- Not much extra is revealed due to this
$global:debugmode      = $false

So I made this to show easily if the re-encoded file just made is bigger or smaller than the source file along with automatice deletion of either file. The re-encoded file is only deleted if it's bigger than the source file and the source file is only deleted if the re-encoded file is smaller than the source file.
I DO NOT RECOMMEND ENABLING SOURCE FILE DELETION. The reason for this is that the command used to delete the file does so in such a way that results in the file not appearing in the Recycling Bin, I believe it's the same as if you use CMD to delete a file. Which is also why I made the process to enable it an 3 step process because your the one making the decision for source files to be deleted BASED SOLELY ON FILE SIZE rather than checking the file yourself (which I recommend doing so since not every re-encode goes correctly)

# -----Comparsion/auto deletion stuff-----
$compare               = $false
# If set to true will auto delete re-encoded files that are bigger than the source file.
$compareDel            = $false
# This text file is where any file that has had an re-encoded version end up bigger than itself will be logged.
# e.g: 'C:\Re-encode AV1\logs\Better Source.txt'
$bettersourceLog       = 'Better Source.txt'

Incase it isn't clear.....this is where you enable source file deletion, this is untested because....I don't personally want my source files deleted. However if you do then you simply change $false to $true for $sourceDel. Then for $DeleteSourceLog you remove the '' # and set the file path as without setting the log text file path, source deletion should not occur, it does not check if the text file exist, only if the path is set.

# --WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING--

# Only set this to true if you are okay with source files being deleted, this does not move files to recycle bin it straight up deletes them. 
# You cannot recover the deleted files. If you accept this risk and have compare set to $true then change the following to $true and for the next entry remove: '' #
$sourceDel             = $false
$DeleteSourceLog       = '' #'Deleted Sources Log.txt'

# --WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING----WARNING--

This is where all the video extensions that FFMPEG recognizes and can deal with are listed, I left this in the config area as an way to in the future more extensions become a thing then they can be added. (presuming the FFMPEG version your using supports it)

# --Video extensions recognized--
$videoExts             = @('.mp4', '.mkv', '.webm', '.mov', '.avi', '.flv', '.wmv', '.m4v', '.ts', '.mts', '.m2ts', '.mpeg', '.mpg', '.3gp', '.3g2')

# ----Batch defaults----
# So if you want to change the default settings of batch encoding then change these otherwise skip this section.

So I feel my comments are pretty accurate as is right now so I'm not going to say anything but read the comment.

# --CRF--
# The higher the number the worse quality the re-encoded video becomes, however the size decreases even more and processing speed is increased.
# Due to AV1 recommended is 30 as highest value to keep good quality with great size reduction, x265 is still best for size reduction.
$global:batchCRF       = 30

Alright auto scaling fun time....

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
