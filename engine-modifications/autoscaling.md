# Autoscaling Horde Agents on Hathora

There are two different types of autoscaling you can leverage:
- `JobQueue`, the preferred method, proactively examines the queue of pending jobs waiting to run
- `LeaseUtilization` reactively adjusts based on average CPU usage across all agents in the pool, which may result in a slight lag

If you're not using Horde as your CI/CD, the **only** viable option for you is `LeaseUtilization`.

## Additional Engine Modifications

You need to add the `HathoraFleetManager` source to the Horde Server Compute plugin and rebuild the Horde Server.

1. Make the changes by applying the [`autoscaling-modifications.patch`](./autoscaling-modifications.patch) patch file based on UE 5.5.4 code (which also works for 5.6.0). To apply the code, copy the patch file into the root of your UE source and run the associated command from the root of the UE source:

    ```
    patch -p1 < autoscaling-modifications.patch
    ```

1. Rebuild the Horde Server by following the steps at `https://<horde-server-url>/docs/Deployment/Server.md#building-from-source`
1. Install/restart the Horde Server as applicable

## Common config

Both methods are defined in your `globals.json` Horde Server file (see [the root README on how to find that](../README.md#horde-pool)) under the pool definition in `Plugins.Compute.Pools`.

1. Set `EnableAutoscaling` to `true`
1. Add the HathoraFleetManager to the `FleetManagers` array
1. Change `INSERT_HATHORA_APP_ID` to the App ID in the Hathora Console UI
1. Change `INSERT_HATHORA_REGION_SLUG` to the region where your Horde Agents should run (e.g. `Los_Angeles`; you can see the slug names at https://api.hathora.dev/discovery/v2/ping and look at the `"region"` fields)
1. Go to https://console.hathora.dev/tokens and create a new API token with the `Applications` scopes (both `applications:read` and `applications:read-write`)
1. Set the environment variable `HATHORA_TOKEN` to the value of the new API token (usually in your CI/CD configuration)
1. Go to your Hathora Application Settings page, scroll to the bottom to find Static Process Allocation, click Expand
1. For the region(s) you'd like to support, set the Min/Max processes. You can leave Target processes at 0

``` jsonc
{
	"Plugins": {
		"Compute": {
			"Pools": [
				{
					"Id": "hathora",
					"Name": "Hathora",
					"Properties": {
						"Color": "470"
					},
					"Color": "Default",
					"EnableAutoscaling": true,
					"ConformInterval": "00:01:00",
					"Condition": "HordePoolName == 'Hathora'",
					"FleetManagers": [
						{
							"Type": "Hathora",
							"Config": {
								"AppId": "INSERT_HATHORA_APP_ID",
								"Region": "INSERT_HATHORA_REGION_SLUG",
								// Either provide an environment variable name of the Hathora API token
								// (defaults to HATHORA_TOKEN) or provide the token directly (which takes
								// precedence)
								// "ApiTokenEnvVar": "HATHORA_TOKEN",
								// "ApiToken": ""
							}
						}
					]
				}
			]
		}
	}
}
```

## `JobQueue`

`JobQueue` scales based on the number of jobs a pool has. This is only applicable if you're using Horde as your CI/CD, but it makes the most sense. You could scale the UBA/Hathora pool based on the number of jobs your build pool is executing. For example, you may want 8 UBA agents for each running build job.

You can find the available settings to put into `JobQueueSettings` at `https://<horde-server-url>/docs/Config/Schema/Globals.md#jobqueuesettings`.

Epic's built-in `JobQueue` size strategy doesn't allow you to reference another pool's size, so we provided a simple modification that you applied in the previous step that introduces a new optional setting `PoolIdToMonitorQueue`. Set this to the `Id` of the pool that you want to sample. Without this addition, `JobQueue` cannot be used to autoscale the Hathora agents.

Some things you should consider:
- `JobQueue` doesn't consider active/running job batches, only those that are Ready and waiting to start. The purpose of this pool size strategy is to speed up current jobs to have higher throughput to. If you set your Target processes to 0 in the Static Process Allocation settings and you don't see Horde starting Hathora UBA agents when a job is running (but no pending), you may need to set the pool's `MinAgents` and/or `NumReserveAgents` in the pool config (see `https://<horde-server-url>/docs/Config/Schema/Globals.md#poolconfig`) to ensure there's a baseline
- Horde Agents/nodes can be part of multiple Node Pools, so you can create a pool just for the C++ compilation tasks, another pool for cooking tasks, and third pool for everything else that isn't UBA specific.
- You should only have one UBA pool per Hathora App/Region pairing; the Hathora Fleet Manager will run into conflicts if two different UBA pools are scaling the same Target Hathora Processes
- You can have multiple Hathora Apps share from the same Hathora Fleet and they can share the same Build for the Deployment, so you can hypothetically have a C++ UBA App and a Cooking UBA App that scale differently based on different C++ and Cooking pools
- Both the C++ and Cooking UBA handlers can be configured with a Max Core (`576` and `500` are the Epic-defined defaults, respectively) if you want increase it for heavy workloads or decrease it to ensure the UBA pool is spread over multiple running jobs. See `Engine/Source/Programs/UnrealBuildTool/Executors/UnrealBuildAccelerator/UnrealBuildAcceleratorHordeConfig.cs` and `https://<horde-server-url>/docs/Tutorials/RemoteShaderCompilation.md` respectively for details.

``` jsonc
{
	"Plugins": {
		"Compute": {
			"Pools": [
				{
					"Id": "hathora",
					"Name": "Hathora",
					"Properties": {
						"Color": "470"
					},
					"Color": "Default",
					"EnableAutoscaling": true,
					"ConformInterval": "00:01:00",
					"Condition": "HordePoolName == 'Hathora'",
					"FleetManagers": [
						{
							"Type": "Hathora",
							"Config": {
								"AppId": "INSERT_HATHORA_APP_ID",
								"Region": "INSERT_HATHORA_REGION_SLUG",
								// Either provide an environment variable name of the Hathora API token
								// (defaults to HATHORA_TOKEN) or provide the token directly (which takes
								// precedence)
								// "ApiTokenEnvVar": "HATHORA_TOKEN",
								// "ApiToken": ""
							}
						}
					],
					"SizeStrategy": "JobQueue",
					"JobQueueSettings": {
						// insert your settings here
						"PoolIdToMonitorQueue": "build-pool-id"
					}
				}
			]
		}
	}
}
```

## `LeaseUtilization`

`LeaseUtilization` samples the average CPU load across agents and scales accordingly. You can find the available settings at to put in `LeaseUtilizationSettings` at `https://<horde-server-url>/docs/Config/Schema/Globals.md#leaseutilizationsettings`. Using `LeaseUtilization` is an option, but it's less accurate as you don't know how many pending jobs there are and whether or not agents need to be warm.

``` jsonc
{
	"Plugins": {
		"Compute": {
			"Pools": [
				{
					"Id": "hathora",
					"Name": "Hathora",
					"Properties": {
						"Color": "470"
					},
					"Color": "Default",
					"EnableAutoscaling": true,
					"ConformInterval": "00:01:00",
					"Condition": "HordePoolName == 'Hathora'",
					"FleetManagers": [
						{
							"Type": "Hathora",
							"Config": {
								"AppId": "INSERT_HATHORA_APP_ID",
								"Region": "INSERT_HATHORA_REGION_SLUG",
								// Either provide an environment variable name of the Hathora API token
								// (defaults to HATHORA_TOKEN) or provide the token directly (which takes
								// precedence)
								// "ApiTokenEnvVar": "HATHORA_TOKEN",
								// "ApiToken": ""
							}
						}
					],
					"SizeStrategy": "LeaseUtilization",
					"LeaseUtilizationSettings": {
						// insert your settings here
					}
				}
			]
		}
	}
}
```