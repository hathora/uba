# rm hathora-uba.tar.gz
# tar -czvf hathora-uba.tar.gz Dockerfile startup.sh uba-wine64.sh HordeAgent

# If HordeAgent doesn't exist, exit with an error
if (-Not (Test-Path "HordeAgent")) {
  Write-Host "HordeAgent directory does not exist; you need to copy this directory from the `Staging` directory of UE."
  exit 1
}

# Remove the existing tarball if it exists (powershell equivalent)
if (Test-Path "hathora-uba.tar.gz") {
  Remove-Item "hathora-uba.tar.gz"
}

# Create a new tarball with the specified files
tar -czvf hathora-uba.tar.gz Dockerfile startup.sh uba-wine64.sh HordeAgent