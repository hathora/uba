# Preparing the Hathora Build Image

You need to build the Horde Agent and make sure it is tagged with the same version that the Horde Server expects the Horde Agent to be.

## Using prebuilt images

If you're using the Epic-provided Horde Server images, you can use one of the images we have built for you.

1. Go to your Horde Dashboard
1. Under the **Help** menu in the top right, click **Version**
1. Take note of the **Agent** version (or **Server** if no **Agent** exists)
1. Go to https://github.com/hathora/uba/pkgs/container/uba/versions
1. Find the corresponding version; if you don't see a matching version here (including the `-suffix` number), you will need to skip to the next section to [build the Hathora Build yourself](#build-the-hordeagent-folder)
1. Go to the [Hathora Console](https://console.hathora.dev/) and select the application you'd like to use (create one if needed)
1. Click **Deploy new version**
1. Select the **External registry** tab
1. Under **Image name**, input `hathora/uba:<version>` replacing `<version>` with the matched image version you found on the GitHub page in the prior step
1. Under **Registry url (Optional)**, input `ghcr.io`
1. Leave **Registry token (Optional)** blank
1. Click **Create build**
1. Continue onto Step 3 in [the main instructions for setting up the Hathora Application](../README.md#hathora-application)

## Build the HordeAgent folder

### If you're rebuilding the Horde Server (autoscaling)

If you're rebuilding the Horde Server (only required for autoscaling support), the Horde Agent is built along that process with the correct version. Copy the `Staging/ServerTools/HordeAgent` directory (**not** the Win64 one) and paste it into this directory.

### If you're not rebuilding the Horde Server

1. Make sure you followed the steps to apply the [base engine modifications](../engine-modifications/README.md)
1. Go to your Horde Server dashboard
1. Under `Help` in the top right, click `Version`
1. Copy the version of the `Agent` (if you don't see it, use the version for `Server`, they should be the same anyway)
1. Open `Engine/Source/Programs/Horde/BuildHorde.xml` and find the **two lines** that say `<Property Name="InformationalVersion" ...`
1. Replace both lines with just one line:
    ```xml
    <Option Name="InformationalVersion" Description="Informational version" DefaultValue="$(Version)-$(Change)"/>
    ```
1. Rebuild the agent with the command replacing `INSERT_VERSION` with the version you copied before:
    ```
    Engine\Build\BatchFiles\RunUAT.bat BuildGraph -script="Engine/Source/Programs/Horde/BuildHorde.xml" -target=HordeInstallerTools -set:InformationalVersion=INSERT_VERSION
    ```
1. Copy the `Staging/ServerTools/HordeAgent` directory (**not** the Win64 one) and paste it into this directory.

## Creating the tarball

Run the below command from this directory in PowerShell:

```
./compress.ps1
```

This should create a `hathora-uba.tar.gz` gzipped tarball which you can upload to Hathora for your build.
