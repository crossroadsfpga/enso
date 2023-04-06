# Ensō Python Frontend

## Install

To install the frontend run in the current directory (`frontend`):
```bash
python3 -m pip install -e .
```
To run the EnsōGen packet generator you also need to have the `capinfos` command installed in the machine you want to use to generate packets.

On Ubuntu (or other Debian-based system) run:
```bash
sudo apt install tshark
```

For other distributions refer to the [wireshark docs](https://tshark.dev/setup/install/#installing-tshark-only) to find the correct package name (either `tshark` or `wireshark-cli`).

## Running

For usage information run:
```bash
enso --help
```

## Enable autocompletion (optional)

#### For Bash
Run this:
```bash
_ENSO_COMPLETE=bash_source enso > ~/.enso-complete.bash
```

Then add the following to your `.bashrc`:
```bash
. ~/.enso-complete.bash
```

#### For Zsh
Run this:
```zsh
_ENSO_COMPLETE=zsh_source enso > ~/.enso-complete.zsh
```

Then add the following to your `.zshrc`:
```zsh
. ~/.enso-complete.zsh
```

#### For Fish
Save the script to `~/.config/fish/completions/enso.fish`:
```fish
_ENSO_COMPLETE=fish_source enso > ~/.config/fish/completions/enso.fish
```
