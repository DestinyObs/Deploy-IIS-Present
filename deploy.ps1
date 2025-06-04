# Deploys the SGBookPortal ASP.NET Core application to IIS

# Step 1: Ensure script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

# Step 1.5: Manually add essential tools to PATH
$env:Path += ";C:\Program Files\Git\cmd"
$env:Path += ";C:\Program Files\dotnet"
$env:Path += ";C:\Windows\System32\inetsrv"  # Needed for New-Website and IIS module commands



# Step 2: Install IIS
Write-Host "Installing IIS..."
try {
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools -ErrorAction Stop
} catch {
    Write-Host "Failed to install IIS: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Check for Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is not installed. Install Git from https://git-scm.com/download/win and rerun the script." -ForegroundColor Red
    exit 1
}

# Step 4: Check for .NET SDK
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host ".NET SDK is not installed. Install from https://dotnet.microsoft.com/download and rerun the script." -ForegroundColor Red
    exit 1
}

# Step 5: Define variables
$repoUrl   = "https://github.com/softwaregurukulamdevops/SGbookportal.git"
$clonePath = "C:\SGbookportal"
$sitePath  = "C:\inetpub\wwwroot\sgbookportal"
$siteName  = "SGBookPortal"
$poolName  = "SGBookPortalPool"

# Step 6: Clone the repository if not already present
if (-not (Test-Path $clonePath)) {
    try {
        Write-Host "Cloning repository..."
        git clone $repoUrl $clonePath
    } catch {
        Write-Host "Repository clone failed: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Repository already exists. Skipping clone."
}




# Step 7: Create web root directory
if (-not (Test-Path $sitePath)) {
    try {
        Write-Host "Creating web root directory..."
        New-Item -Path $sitePath -ItemType Directory -Force
    } catch {
        Write-Host "Failed to create web root directory: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 8: Publish the ASP.NET Core project
try {
    Write-Host "Publishing the application..."
    dotnet publish "$clonePath\BookPortel\BookPortel.csproj" -c Release -o $sitePath
} catch {
    Write-Host "Publish failed: $_" -ForegroundColor Red
    exit 1
}

# Step 9: Grant IIS read/execute permissions
try {
    Write-Host "Setting permissions..."
    icacls $sitePath /grant "IIS_IUSRS:(OI)(CI)RX" /T | Out-Null
} catch {
    Write-Host "Failed to set folder permissions: $_" -ForegroundColor Red
    exit 1
}

# Step 10: Check and assign available port (start from 80)
$startingPort = 80
$usedPorts = (Get-NetTCPConnection -State Listen).LocalPort | Sort-Object -Unique
$port = $startingPort
while ($usedPorts -contains $port) {
    $port++
}
Write-Host "Selected port: $port"

# Step 11: Configure IIS - Remove existing site and create app pool
Import-Module WebAdministration

# Remove existing site if it exists
if (Get-Website | Where-Object { $_.Name -eq $siteName }) {
    try {
        Write-Host "Removing existing site '$siteName'..."
        Remove-Website -Name $siteName
    } catch {
        Write-Host "Failed to remove existing IIS site: $_" -ForegroundColor Red
        exit 1
    }
}

# Create App Pool (No Managed Code for .NET Core)
if (-not (Test-Path "IIS:\AppPools\$poolName")) {
    New-WebAppPool -Name $poolName
    Set-ItemProperty "IIS:\AppPools\$poolName" -Name "managedRuntimeVersion" -Value ""
}

# Create new IIS website
try {
    Write-Host "Creating IIS site '$siteName'..."
    New-Website -Name $siteName -Port $port -PhysicalPath $sitePath -ApplicationPool $poolName
} catch {
    Write-Host "Failed to create IIS site: $_" -ForegroundColor Red
    exit 1
}

# Step 12: Start the website
try {
    Start-Website -Name $siteName
    Write-Host "`nDeployment completed successfully."
    Write-Host "You can access the application at: http://localhost:$port/swagger/index.html`n"
} catch {
    Write-Host "Failed to start IIS site: $_" -ForegroundColor Red
    exit 1
}
