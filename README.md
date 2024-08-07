# IPv4 Configuration

A simple IPv4 configuration script for Windows (CLI + GUI).

> [!Warning]
> Before running the program, please make sure you understand what it does, as I take no responsibility for any harm caused to your system.
> Use the program at your own risk.
> The program was tested on Windows 11.

> [!Note]
> The provided warnings are for legal reasons. Configuring your IP settings improperly can create network issues.

# Features

- Open the desired adapter/connection in the Control Panel (ncpa.cpl; navigation using [WScript.Shell](https://ss64.com/vb/sendkeys.html))
- Use a GUI to configure the settings (using .NET)
- Alternatively, you can configure the IPv4 settings via the CLI

# Usage

> [!Caution]
> The program will simulate user input when running it with the `--open_config` flag.
> If you do not follow the instructions, it could lead to problems.
> Make sure that the key presses will lead to the desired result before running the program.

To open the Control Panel, use the `--open_config` flag:

```
.\ipv4_configuration.ps1 --open_config
```
> [!Caution]
> The program might not set the settings you provide as expected.
> This may be due to invalid input or implementation issues.
> Check the configuration after usage to ensure the program worked as expected.

To use the GUI, use the `--use_gui` flag:

```
.\ipv4_configuration.ps1 --use_gui
```

To use the CLI, just run it without flags:

```
.\ipv4_configuration.ps1
```
