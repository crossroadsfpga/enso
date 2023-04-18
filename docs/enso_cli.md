# Ensō CLI Tool

To be able to run an application using Ensō, you need to first load the hardware design to the FPGA and configure it accordingly. Ensō provides a CLI tool that makes this process easier. Here we describe how to install it.

## Installing the Ensō CLI Tool

If you haven't already, clone the enso repository to the machine you want to install the tool on:
```bash
git clone https://github.com/crossroadsfpga/enso
```

To install the Ensō CLI Tool run:
```bash
cd <root of enso repository>
python3 -m pip install -e frontend  # Make sure this python is version >=3.9.
```

This will install the `enso` command. In [Running](running.md), we will describe how to use this command to load the hardware design and configure the NIC but you can also use the command itself to obtain usage information:
```bash
enso --help
```

If, after installing the tool, you still get an error saying that the `enso` command is not found, you may need to add the `bin` directory of the python installation to your `PATH`. Refer to [this stackoverflow answer](https://stackoverflow.com/a/62151306/2027390) for more information on how to do this.


## Running the Ensō CLI Tool in a different machine

You do not need to run the `enso` command in the same machine as the one you will run an Ensō-based application. You may also choose to run it from your laptop, for example. This machine can even have a different operating system, e.g., macOS.

We refer to the machine that you plan to run the `enso` command as *client* and to the machine you will run the Ensō-based application (the one with the FPGA) as *server*.

The `enso` command provides the `--host <host name>` option that lets you specify a different server machine. But there are a few extra configuration steps that you need in order to use this option. First, you need to make sure that you have ssh access using a password-less key (e.g., using ssh-copy-id) from the client to the server machine. The client should also have an `~/.ssh/config` configuration file set with configuration to access the server machine.

If you don't yet have an `~/.ssh/config` file, you can create one and add the following lines, replacing everything between `<>` with the correct values:
```bash
Host <server_machine_name>
  HostName <server_machine_address>
  IdentityFile <private_key_path>
  User <user_name>
```

`server_machine_name` is a nickname to the server machine. This is the name you specify when running the `enso` command with the `--host` option.


## Enable autocompletion

### For Bash
Run this:
```bash
_ENSO_COMPLETE=bash_source enso > ~/.enso-complete.bash
```

Then add the following to your `.bashrc`:
```bash
. ~/.enso-complete.bash
```

### For Zsh
Run this:
```zsh
_ENSO_COMPLETE=zsh_source enso > ~/.enso-complete.zsh
```

Then add the following to your `.zshrc`:
```zsh
. ~/.enso-complete.zsh
```

### For Fish
Save the script to `~/.config/fish/completions/enso.fish`:
```fish
_ENSO_COMPLETE=fish_source enso > ~/.config/fish/completions/enso.fish
```
