# Base engine modifications

You'll need to make some engine modifications (even if you're using one of our [prebuilt horde agent images](../hathora-build/overview.md#using-prebuilt-images)) to use UBA on Hathora.

## Why are modifications necessary?

Horde and UBA were originally designed to work with fixed port assumptions in AWS. Hathora, on the other hand, randomly assigns exposed ports to containerized workloads. This mismatch causes Horde/UBA communication to fail unless we introduce changes.

To resolve this, we've already implemented and validated a set of engine modifications. We go into further details of each in the [appendix](#appendix).

- Support for [**custom exposed vs. listen ports**](#1-supporting-differing-exposed-and-listen-ports)
- [**Workarounds**](#3-preventing-false-positive-connections-due-to-hathoras-tcp-proxies) for false-positive TCP connections via Hathora's proxying
- Support for [**containerized CPU and memory overrides**](#4-allow-overriding-the-hordeagents-perceived-logical-cores-and-ram)
- Fixes for [**non-AWS cloud environments**](#5-stack-buffer-overrun-for-gcp-hosts-for-the-worker-agent) (e.g., buffer overrun in GCP)

## Applying the modifications

We have provided a [git diff patch file](./base-modifications.patch) based on UE 5.5.4 code. To apply the code, copy the patch file into the root of your UE source and run the associated command from the root of the UE source:

```
patch -p1 < base-modifications.patch
```

## Updating UBA Binaries

`UbaAgent` and `UbaHost` binaries need to be regenerated with the modified code. These are populated from Epic's CDN after running `Setup.bat` for UE source builds, and they are typically committed to version control.

You can see the outputs in `Engine/Binaries/Win64/UnrealBuildAccelerator/x64`; we're interested in `UbaAgent.exe`, `UbaHost.*`.

You can build these yourself, but we have also provided prebuilt binaries you can replace yours with. If you're using UE from the Epic Games Launcher rather than a source build, you can simply paste these into those directories, but note they will be overwritten on updates and need to be replaced again.

### Using our Prebuilt UBA Binaries

1. Go to the [latest release](https://github.com/hathora/uba/releases/latest) and find the corresponding `UbaHathoraBinaries-Version.zip`.
1. Download and extract the files
1. Copy the extracted files and replace the ones in `Engine/Binaries/Win64/UnrealBuildAccelerator/x64`
1. If you're distributing your engine to your team, check these version control; otherwise these steps need to be repeated for all build machines

> [!TIP]
> We will provide a 5.6 image once 5.6.0 is fully released.

### Building UBA Binaries Manually

You can build these binaries yourself with the below commands:

```
Engine\Build\BatchFiles\Build.bat UbaHost Win64 Development
```

```
Engine\Build\BatchFiles\Build.bat UbaAgent Win64 Development
```

## Appendix

### Changes needed to the Engine and why

#### (1) Supporting differing exposed and listen ports

Changes must be made to support additional opt-in Horde Agent Properties that specify the exposed ports, which are managed/provided within the Hathora Process startup sequent:

- `ExposedComputePort`
- `ExposedUbaPort`
- `ExposedUbaProxyPort`

In addition, a fourth Property is required because the internal listen ports for UBA and the UBA Proxy are hardcoded to `7001` and `7002` in multiple locations of the engine; ports `7000-7003` are reserved in Hathora so we also introduced the opt-in Horde Agent Properties `UbaPort` and `UbaProxyPort` to specify different listen ports.

#### (2) Preventing false-positive connections due to Hathora’s TCP proxies

Each exposed port in Hathora has its own UDP/TCP proxy, which is running even if the internal service isn’t running. This means that connections to the exposed port will be successful even if immediately closed due to the internal service isn’t running. We needed to make a modification to replace a `TODO` in the engine to properly wait for the worker Horde Agent to report it has started listening on the UBA port before attempting to connect to it. Otherwise the code would prematurely connect, thinking it had a valid connection when it really didn’t.

#### (3) Allow overriding the HordeAgent’s perceived logical cores and RAM

The `HordeAgent` program will look at `/proc/cpuinfo` and `/proc/meminfo` on the system to determine the available resources. In Hathora’s containerized environment, these files store the entire node’s available resources not the container’s available resources. Modifications were made to support override properties that can be configured at startup and used instead of the default logic of reading `/proc/*`.

#### (4) Stack buffer overrun for GCP hosts for the worker agent

When hosting the worker agent on GCP, UBA by default will call an AWS SDK `GetAvailabilityZone()` function which returns a larger string than normally with AWS machines. Epic has a bug where the serialized info provided from the worker agent can be larger than what the expected deserialization method expects. The deserialization function ignores the capacity of a string buffer and copies past the capacity even if the data is longer than it, causing a stack buffer overrun/corruption. One option is to change the hardcoded `#define UBA_USE_AWS !PLATFORM_MAC` (and likely still needed), but for now we opted for a safer option which extends the deserialized string buffer to be larger than the max size the worker agent sends.

### Engine Modifications

Below you can find which modules/files were changed and for which reasons:

#### UbaCoordinatorHorde

Located at `Engine/Source/Developer/UbaCoordinatorHorde`

This module is used for UBA compute for cooking; it’s loaded via `UnrealEditor.exe`.

Modified files:

- `Private/UbaHordeAgent.cpp` (to support reasons: 2)
- `Private/UbaHordeAgent.h` (to support reasons: 2)
- `Private/UbaHordeAgentManager.cpp` (to support reasons: 1, 2)
- `Private/UbaHordeMetaClient.h` (to support reasons 1)
- `Private/UbaHordeMetaClient.cpp` (to support reasons 1)

#### HordeAgent

Located at `Engine/Source/Programs/Horde/HordeAgent`

This program is used to instantiate the worker Horde Agent hosted by Hathora. These modifications are only necessary if you want to manage the build you upload to Hathora to support this, but we’ll provide this build at first.

Modified files:

- `Services/CapabilitiesService.cs` (to support reasons: 3)

#### Shared/EpicGames.Horde

Located at `Engine/Source/Programs/Shared/EpicGames.Horde`

This module has common logic that’s used by other modules in `Engine/Source/Programs` (primarily `Horde` and `UnrealBuildAcclerator`).

Modified files:

- `Compute/Clients/ServerComputClient.cs` (to support reason 1, used in the `UbaHost.dll` executable by the initiator agent to connect to the correct port)

#### UnrealBuildAccelerator

Located at `Engine/Source/Programs/UnrealBuildAccelerator`

This module contains code for both the initiator agent (via `UbaHost.dll`) and the worker agent (via `UbaAgent.exe` which needs to be located on the initiator agent’s machine as it’s uploaded to the worker agent at runtime).

Modified files:

- `Common/Private/UbaSessionServer.cpp` (to support reasons: 4)

#### UnrealBuildTool

Located at `Engine/Source/Programs/UnrealBuildTool`

This executable is used for building Unreal, including how UBA C++ compilation distribution works.

Modified files:

- `Executors/UnrealBuildAccelerator/UBAAgentCoordinatorHorde.cs` (to support reason 1)