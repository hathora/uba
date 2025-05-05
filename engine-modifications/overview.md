# Base engine modifications

You'll need to make some engine modifications (even if you're using one of our [prebuilt horde agent images](../hathora-build/overview.md#using-prebuilt-images)) to use UBA on Hathora.

## Why are modifications necessary?

Horde and UBA were originally designed to work with fixed port assumptions in AWS. Hathora, on the other hand, randomly assigns exposed ports to containerized workloads. This mismatch causes Horde/UBA communication to fail unless we introduce changes.

To resolve this, we've already implemented and validated a set of engine modifications. We go into further details of each in the [appendix](#appendix).

- Support for [**custom exposed vs. listen ports**](#1-supporting-differing-exposed-and-listen-ports)
- [**Workarounds**](#3-preventing-false-positive-connections-due-to-hathoras-tcp-proxies) for false-positive TCP connections via Hathora's proxying
- Compatibility with [**Hathora’s monitoring tools**](#2-supporting-hathoras-internal-monitoring-tools) (e.g. `/metrics` polling)
- Support for [**containerized CPU and memory overrides**](#4-allow-overriding-the-hordeagents-perceived-logical-cores-and-ram)
- Fixes for [**non-AWS cloud environments**](#5-stack-buffer-overrun-for-gcp-hosts-for-the-worker-agent) (e.g., buffer overrun in GCP)

## Applying the modifications

We have provided a [git diff patch file](./base-modifications.patch) based on UE 5.5.4 code which you can apply with:

**Using Git/GitHub:**

```
git apply base-modifications.patch
```

**Using Perforce:**

```
patch -p1 base-modifications.patch
```

## Appendix

### Changes needed to the Engine and why

#### (1) Supporting differing exposed and listen ports

Changes must be made to support additional opt-in Horde Agent Properties that specify the exposed ports, which are managed/provided within the Hathora Process startup sequent:

- `ExposedComputePort`
- `ExposedUbaPort`
- `ExposedUbaProxyPort`

In addition, a fourth Property is required because the internal listen ports for UBA and the UBA Proxy are hardcoded to `7001` and `7002` in multiple locations of the engine; ports `7000-7003` are reserved in Hathora so we also introduced the opt-in Horde Agent Properties `UbaPort` and `UbaProxyPort` to specify different listen ports.

#### (2) Supporting Hathora’s internal monitoring tools

Hathora has internal monitoring tools that will attempt to gather metrics from exposed TCP ports. Periodically, Hathora will make an `HTTP GET /metrics`  request on each of the ports to support a future endeavor of capturing OpenTelemetry metrics. The Horde Agent and UBA do not anticipate traffic/protocols, and do not completely handle, other than the expected protocol. When Hathora makes these HTTP requests, it can cause the Horde Agent and UBA to have undefined behavior and cause issues. Engine modifications were put in place to detect, ignore, and close these types of connections. In the future, Hathora may look into a future option to opt-out of these HTTP requests for specific ports.

#### (3) Preventing false-positive connections due to Hathora’s TCP proxies

Each exposed port in Hathora has its own UDP/TCP proxy, which is running even if the internal service isn’t running. This means that connections to the exposed port will be successful even if immediately closed due to the internal service isn’t running. We needed to make a modification to replace a `TODO` in the engine to properly wait for the worker Horde Agent to report it has started listening on the UBA port before attempting to connect to it. Otherwise the code would prematurely connect, thinking it had a valid connection when it really didn’t.

#### (4) Allow overriding the HordeAgent’s perceived logical cores and RAM

The `HordeAgent` program will look at `/proc/cpuinfo` and `/proc/meminfo` on the system to determine the available resources. In Hathora’s containerized environment, these files store the entire node’s available resources not the container’s available resources. Modifications were made to support override properties that can be configured at startup and used instead of the default logic of reading `/proc/*`.

#### (5) Stack buffer overrun for GCP hosts for the worker agent

When hosting the worker agent on GCP, UBA by default will call an AWS SDK `GetAvailabilityZone()` function which returns a larger string than normally with AWS machines. Epic has a bug where the serialized info provided from the worker agent can be larger than what the expected deserialization method expects. The deserialization function ignores the capacity of a string buffer and copies past the capacity even if the data is longer than it, causing a stack buffer overrun/corruption. One option is to change the hardcoded `#define UBA_USE_AWS !PLATFORM_MAC` (and likely still needed), but for now we opted for a safer option which extends the deserialized string buffer to be larger than the max size the worker agent sends.

### Engine Modifications

Below you can find which modules/files were changed and for which reasons:

#### UbaCoordinatorHorde

Located at `Engine/Source/Developer/UbaCoordinatorHorde`

This module is used for UBA compute for cooking; it’s loaded via `UnrealEditor.exe`.

Modified files:

- `Private/UbaHordeAgent.cpp` (to support reasons: 3)
- `Private/UbaHordeAgent.h` (to support reasons: 3)
- `Private/UbaHordeAgentManager.cpp` (to support reasons: 1, 3)
- `Private/UbaHordeMetaClient.h` (to support reasons 1)
- `Private/UbaHordeMetaClient.cpp` (to support reasons 1)

#### HordeAgent

Located at `Engine/Source/Programs/Horde/HordeAgent`

This program is used to instantiate the worker Horde Agent hosted by Hathora. These modifications are only necessary if you want to manage the build you upload to Hathora to support this, but we’ll provide this build at first.

Modified files:

- `Services/CapabilitiesService.cs` (to support reasons: 4)
- `Services/ComputeListenerService.cs` (to support reasons: 2)

#### Shared/EpicGames.Horde

Located at `Engine/Source/Programs/Shared/EpicGames.Horde`

This module has common logic that’s used by other modules in `Engine/Source/Programs` (primarily `Horde` and `UnrealBuildAcclerator`).

Modified files:

- `Compute/Clients/ServerComputClient.cs` (to support reason 1, used in the `UbaHost.dll` executable by the initiator agent to connect to the correct port)

#### UnrealBuildAccelerator

Located at `Engine/Source/Programs/UnrealBuildAccelerator`

This module contains code for both the initiator agent (via `UbaHost.dll`) and the worker agent (via `UbaAgent.exe` which needs to be located on the initiator agent’s machine as it’s uploaded to the worker agent at runtime).

Modified files:

- `Common/Private/UbaNetworkClient.cpp` (to support reasons: 2)
- `Common/Private/UbaSessionServer.cpp` (to support reasons: 5)

#### UnrealBuildTool

Located at `Engine/Source/Programs/UnrealBuildTool`

This executable is used for building Unreal, including how UBA C++ compilation distribution works.

Modified files:

- `Executors/UnrealBuildAccelerator/UBAAgentCoordinatorHorde.cs` (to support reason 1)