# Ensō Python Frontend

## Install

To install the frontend run in the current directory (`frontend`):
```bash
python3 -m pip install -e .
```

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
