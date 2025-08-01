# UBA on Hathora

This repository is everything you need to get started using UBA on Hathora.

## Common Terms

**Horde:** Horde is a framework included in Unreal Engine that handles CI as well as UBA coordination.
**UBA:** Unreal Build Accelerator is a program part of Horde that enables distributed compute tasks (similar to Incredibuild and FASTBuild).

## Prerequisites

To use UBA on Hathora, you need the following:
- Using Unreal Engine 5.5.0 or greater
- A Horde Server instance (you do not need to be using the CI/Automation Jobs in Horde to use UBA on Hathora)
> [!NOTE]
> Your Horde Server needs to be publicly accessible; please reach out to the Hathora team if your Horde Server is behind a VPN

## Setup

### Engine Modifications

Several Unreal Engine modifications are necessary to support UBA on Hathora. You can find a detailed instructions and explanations in [./engine-modifications/README.md](./engine-modifications/README.md).

### Creating the image to upload to Hathora

To leverage UBA on Hathora, [Wine](https://www.winehq.org/) is needed to run the Horde Agent (and UBA) on Hathora's Linux containers. We've prepared a `Dockerfile` and supporting scripts to facilitate this; follow the instructions at [./hathora-build/README.md](./hathora-build/README.md).

### Hathora Application

UBA on Hathora needs its own Hathora Application. Once following all of the steps above, you should have a tarball that you can upload to Hathora.

1. [Create a separate application](https://hathora.dev/docs/guides/deploy-hathora#create-an-application); the name doesn't matter
1. Using the tarball generated in the prior section (e.g. `hathora-uba.tar.gz`), start following the steps to [deploy a server build](https://hathora.dev/docs/guides/deploy-hathora#deploy-a-server-build).
1. When you get to the CPU/Memory profile, use at least 8 vCPU / 16 GB RAM, but 16 vCPU is the recommended minimum Process Size. If you need 1:4 CPU/RAM ratio or more vCPU than is available in the dashboard, please reach out to the Hathora team for support.
    - By default, you will be limited to 4 vCPU; please reach out ot the Hathora team to have this limit increased
    - The Hathora team may need to increase your app's maximum memory per process limit (32GB by default)
    - After that, you can run a POST request for the [`CreateDeployment`](https://hathora.dev/api#tag/DeploymentsV3/operation/CreateDeployment) API call to manually set the proper ratio. Normally we would create a deployment with the default ratio, then use the `GetDeployments` call to get the build ID to then run `CreateDeployment` with just the `requestedMemoryMB` field increased.
1. Keep the Number of Rooms Per Process set to `1`.
1. When you get to the Transport config, you need to set up these ports. You can use other port numbers (except `7000-7010`) if you need, but make sure you update the environment variables in the next step accordingly:
    - Port: `6000`, Transport Type: `TCP`, Name: `default`
    - Port: `6001`, Transport Type: `TCP`, Name: `uba`
    - Port: `6002`, Transport Type: `TCP`, Name: `proxy`
1. When you get to the Environment Variables config, you need to set these up:
    - Name: `HORDE_COMPUTE_LISTEN_PORT`, Value: `6000`
    - Name: `HORDE_UBA_LISTEN_PORT`, Value: `6001`
    - Name: `HORDE_UBA_PROXY_LISTEN_PORT`, Value: `6002`
    - Name: `HORDE_POOL_NAME`, Value: `Hathora`
    - Name: `HORDE_SERVER_URL`, Value: URL to your Horde Dashboard (e.g. `https://horde.yourdomain.com`)
    - Name: `HORDE_SERVER_TOKEN`, Value: Retrieve this value by navigating your browser to `horde.yourdomain.com/api/v1/admin/registrationtoken` with an admin user
> [!TIP]
> If you have bare metal on Hathora or have [autoscaling](#horde-autoscaling) set up, you can disable the Idle Timeout field to prevent agents from continuously restarting every 5 minutes.

### Horde Pool and UBA Permissions

You need to add a node pool in Horde for the Hathora agents to associate with. This is done by modifying your Horde Server's `globals.json`

- **Windows location:** `C:\ProgramData\Epic\Horde\Server\globals.json`
- **Linux/macOS location:** In the `Data` folder under the application directory
- **Docker location:** `/app/Data/globals.json` (you likely have a volume set up that maps `/app/Data` to a local directory outside of Docker)

We also need to enable permissions to run UBA tasks from a development machine (Horde CI jobs don't need  this, but we recommend adding it anyway).

In total, here are the changes you need to `globals.json`; make sure you merge them appropriately with existing content:

``` json
{
  "plugins": {
    "compute": {
      "clusters": [
        {
          "id": "uba",
          "namespaceId": "horde.compute",
          "Condition": "pool == 'hathora'",
          "acl": {
            "entries": [
              {
                "claim": {
                  "type": "http://epicgames.com/ue/horde/group",
                  "value": "UBA"
                },
                "actions": ["AddComputeTasks"]
              }
            ]
          }
        }
      ],
      "pools": [
        {
          "id": "hathora",
          "name": "Hathora",
          "properties": {
            "Color": "470"
          },
          "color": "Default",
          "enableAutoscaling": false,
          "conformInterval": "00:01:00",
          "condition": "HordePoolName == 'Hathora'"
        }
      ]
    }
  },

  "acl": {
    "entries": [
      {
        "claim": {
          "type": "http://epicgames.com/ue/horde/group",
          "value": "UBA"
        },
        "profiles": [
          "run-uba"
        ]
      }
    ],
    "profiles": [
      {
        "id": "run-uba"
      }
    ]
  }
}
```

> [!NOTE]
> You can change the `id`, `name`, and `Color` fields above, but the `condition` field's `'Hathora'` should not be changed as it needs to match the `HORDE_POOL_NAME` environment variable we set to `Hathora` above.

The above changes add a new claim for a group named `UBA`, which an admin can assign the group to the user to give them permission to use the UBA pool from their development machine:
1. Go to **Server > User Accounts** (or `horde.yourdomain.com/accounts`)
1. Press the pencil edit icon next to the user
1. In the **Edit Account** modal, find **Groups** add `UBA`
1. Click **Save**

The user should log out and log back in to the Horde dashboard before getting their auth token in the below [authentication section](#authentication).

#### Extending User Token Expiry

If users need to use UBA from their dev machine, the authentication tokens they use expire in 8 hours by default with no logic built in for refreshing the token. This can be cumbersome for devs to get a new auth token and set it in their `BuildConfiguration.xml` every day. Please consider the security implications when extending this value.

You can extend this expiry with the `jwtExpiryTimeHours` variable in `server.json`:

``` jsonc
{
  "Horde": {
    "jwtExpiryTimeHours": 168 // for 7 days, or 720 for 30 days
  }
}
```

### Unreal Project Configuration

Your Unreal project needs to be configured to use the Horde server and UBA pool for distributing C++ and shader compilation tasks. This should be done in `Config/DefaultEngine.ini`:

``` ini
[Horde]
ServerUrl=https://horde.yourdomain.com
; UbaPool should match the `id` field in your `globals.json`
UbaPool=hathora
UbaCluster=uba
; UbaEnabled can also be set to BuildMachineOnly, which will only be enabled if the
; `IsBuildMachine` environment variable is set to `1`. This is useful if you want to
; only have UBA run for your CI/CD machines; you'll need to configure those jobs to set
; the environment variable.
UbaEnabled=True

[UbaController]
; UbaEnabled can also be set to BuildMachineOnly, which will only be enabled if the
; `IsBuildMachine` environment variable is set to `1`. This is useful if you want to
; only have UBA run for your CI/CD machines; you'll need to configure those jobs to set
; the environment variable.
Enabled=True
; optionally add `MaxCores` to the Horde object below (defaults to 500); see `horde.yourdomain.com/docs/Tutorials/RemoteShaderCompilation.md` for details
; Pool below should match the `id` field in your `globals.json`
Horde=(Pool=hathora)
; Do not set the Host/Port settings in UbaController; these enable a different mode
```

You also need to enable the UBA Executor. This can be done by supplying the `-UBA` CLI flag in CI jobs or by adding the config variable in your `Engine/Saved/UnrealBuildTool/BuildConfiguration.xml` or `%APPDATA%/Unreal Engine/UnrealBuildTool/BuildConfiguration.xml` file:

``` xml
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
  <BuildConfiguration>
    <bAllowUBAExecutor>true</bAllowUBAExecutor>
  </BuildConfiguration>
</Configuration>
```

#### Authentication

If you're using something other than Horde for your CI/CD, your jobs should pass the `-Unattended` flag to UAT and set the `UE_HORDE_TOKEN` environment variable to the token received at `horde.yourdomain.com/api/v1/admin/token`.

If you're manually running Unreal on your dev machine, Unreal might automatically open the browser authenticate you, but we've had issues with this in the past. You can set the token retrieved at the above URL in your `Engine/Saved/UnrealBuildTool/BuildConfiguration.xml` or `%APPDATA%/Unreal Engine/UnrealBuildTool/BuildConfiguration.xml` file:

``` xml
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">
  <Horde>
    <Token>TOKEN_HERE</Token>
  </Horde>
</Configuration>
```

### Horde Autoscaling

If you're interested in setting up autoscaling to scale up/down your Horde Agents on Hathora based on usage/demand, read the details in [./engine-modifications/autoscaling.md](./engine-modifications/autoscaling.md).
