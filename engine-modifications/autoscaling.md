# Autoscaling Horde Agents on Hathora

There are two different types of autoscaling you can leverage:
- `JobQueue`, the preferred method, proactively examines the queue of pending jobs waiting to run
- `LeaseUtilization` reactively adjusts based on average CPU usage across all agents in the pool, which may result in a slight lag

If you're not using Horde as your CI/CD, the **only** viable option for you is `LeaseUtilization`.

## Additional Engine Modifications

You need to add the `HathoraFleetManager` source to the Horde Server Compute plugin and rebuild the Horde Server.

1. Make the changes by applying the [`autoscaling-modifications.path`](./autoscaling-modifications.patch) patch file
1. Rebuild the Horde Server by following the steps at `https://horde.yourdomain.com/docs/Deployment/Server.md#building-from-source`
1. Install/restart the Horde Server as applicable

## Common config

Both methods are defined in your `globals.json` Horde Server file (see [the root README on how to find that](../README.md#horde-pool)) under the pool definition in `Plugins.Compute.Pools`.

1. Set `EnableAutoscaling` to `true`
1. Add the HathoraFleetManager to the `FleetManagers` array
1. Change `INSERT_HATHORA_APP_ID` to the App ID in the Hathora Console UI
1. Change `INSERT_HATHORA_REGION_SLUG` to the region where your Horde Agents should run (e.g. `Los_Angeles`; you can see the slug names at https://api.hathora.dev/discovery/v2/ping and look at the `"region"` fields)
1. Go to https://console.hathora.dev/tokens and create a new API token with the `Applications` scopes (both `applications:read` and `applications:read-write`)
1. Set the environment variable `HATHORA_TOKEN` to the value of the new API token (usually in your CI/CD configuration)
1. TODO: add docs about setting the static process allocation settings in the app settings

``` json
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
							"Config": "{ \"AppId\": \"INSERT_HATHORA_APP_ID\", \"Region\": \"INSERT_HATHORA_REGION_SLUG\" }"
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

You can find the available settings to put into `JobQueueSettings` at `https://horde.yourdomain.com/docs/Config/Schema/Globals.md#jobqueuesettings`.

The built-in `JobQueue` size strategy doesn't allow you to reference another pool's size, but a simple modification already included in the prior step introduces a new optional setting `OtherPoolId` we added to enable this. Set this to the `id` of the pool that you want to sample. Without this addition, `JobQueue` cannot be used to autoscale the Hathora agents.

``` json
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
							"Config": "{ \"AppId\": \"INSERT_HATHORA_APP_ID\", \"Region\": \"INSERT_HATHORA_REGION_SLUG\" }"
						}
					],
					"SizeStrategy": "JobQueue",
					"LeaseUtilizationSettings": {
						// insert your settings here
						"OtherPoolId": "build-pool-id"
					}
				}
			]
		}
	}
}
```

## `LeaseUtilization`

`LeaseUtilization` samples the average CPU load across agents and scales accordingly. You can find the available settings at to put in `LeaseUtilizationSettings` at `https://horde.yourdomain.com/docs/Config/Schema/Globals.md#leaseutilizationsettings`. Using `LeaseUtilization` is an option, but it's less accurate as you don't know how many pending jobs there are and whether or not agents need to be warm.

``` json
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
							"Config": "{ \"AppId\": \"INSERT_HATHORA_APP_ID\", \"Region\": \"INSERT_HATHORA_REGION_SLUG\" }"
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