# Norman Python Frontend

## Install

To install the frontend run in the current directory (`frontend`):
```bash
pip3 install -e .
```
To run Norman pktgen you also need to have the `capinfos` command installed in the machine you want to use to generate packets.

On Ubuntu (or other Debian-based system) run:
```bash
sudo apt install tshark
```

For other distributions refer to the [wireshark docs](https://tshark.dev/setup/install/#installing-tshark-only) to find the correct package name (either `tshark` or `wireshark-cli`).

## Running

For usage information run:
```bash
norman --help
```

## Enable autocompletion (optional)

#### For Bash
Run this:
```bash
_NORMAN_COMPLETE=bash_source norman > ~/.norman-complete.bash
```

Then add the following to your `.bashrc`:
```bash
. ~/.norman-complete.bash
```

#### For Zsh
Run this:
```zsh
_NORMAN_COMPLETE=zsh_source norman > ~/.norman-complete.zsh
```

Then add the following to your `.zshrc`:
```zsh
. ~/.norman-complete.zsh
```

#### For Fish
Save the script to `~/.config/fish/completions/norman.fish`:
```fish
_NORMAN_COMPLETE=fish_source norman > ~/.config/fish/completions/norman.fish
```
