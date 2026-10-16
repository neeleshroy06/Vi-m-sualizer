# Vim command visualizer

Shows remote Vim commands in a window on your computer. No X11 or remote
Python is needed.

## 1. Install locally

On your own computer, clone the project:

```bash
git clone <REPOSITORY-URL> ~/vimshow
```

You need Python 3 with Tk. Check it with:

```bash
python3 -m tkinter
```

On Windows, use `python` instead of `python3` and clone wherever you prefer.

## 2. Install on the remote server

SSH to the server and clone the same project:

```bash
git clone <REPOSITORY-URL> ~/vimshow
```

Create or edit your remote Vim config:

```bash
nano ~/.vimrc
```

Add these lines:

```vim
let g:vs_transport = 'tcp'
let g:vs_port = 8765
execute 'source ' . fnameescape(expand('~/vimshow/vimshow.vim'))
```

Save with `Ctrl+O`, Enter, then `Ctrl+X`.

Check that remote Vim supports channels:

```bash
vim --version | grep channel
```

It must show `+channel`.

## 3. Use it

Open **two local terminals**.

In terminal 1, start the visualizer:

```bash
cd ~/vimshow
python3 visualizer.py --listen 8765
```

In terminal 2, connect to the remote server:

```bash
ssh -o ExitOnForwardFailure=yes -R 127.0.0.1:8765:127.0.0.1:8765 username@server
```

Then run Vim on the remote server:

```bash
vim
```

Press `j` or `dd`. The local visualizer should update.

## Optional shortcut: keep the normal SSH command

On your **local** computer, add this to `~/.ssh/config` (create the file if
needed):

```sshconfig
Host ieng6.ucsd.edu
    RemoteForward 127.0.0.1:8765 127.0.0.1:8765
    ExitOnForwardFailure yes
```

Now students can use their usual command:

```bash
ssh username@ieng6.ucsd.edu
```

They still start the visualizer in the first local terminal.

## Optional shortcut: Bash aliases

Use this instead of the SSH-config shortcut above.

On macOS, Linux, or WSL, add these aliases to the **local** `~/.bashrc`:

```bash
alias vimshow='python3 ~/vimshow/visualizer.py --listen 8765'
alias ieng6='ssh -o ExitOnForwardFailure=yes -R 127.0.0.1:8765:127.0.0.1:8765 username@ieng6.ucsd.edu'
```

Reload Bash:

```bash
source ~/.bashrc
```

Then use `vimshow` in terminal 1 and `ieng6` in terminal 2. Replace
`username` with your username. Windows PowerShell does not use `.bashrc`; use
the SSH-config option above instead.
