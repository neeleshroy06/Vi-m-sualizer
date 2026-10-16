# Vim command visualizer

Displays completed Vim normal-mode commands in a small window.

## Setup

You need Vim and Python 3 with Tk support. Test Tk with:

```bash
python3 -m tkinter
```

Clone this project, then add the following to your Vim config. Change the path
to where you cloned it.

```vim
execute 'source ' . fnameescape(expand('~/vimshow/vimshow.vim'))
```

Start the visualizer:

```bash
cd ~/vimshow
python3 visualizer.py
```

On Windows, run `python visualizer.py` and add an absolute `source` path to
`_vimrc`.

## Remote Vim over SSH

Run the visualizer on your local computer:

```bash
python visualizer.py --listen 8765
```

On the remote server, put these lines in `~/.vimrc` **before** the `source`
line:

```vim
let g:vs_transport = 'tcp'
let g:vs_port = 8765
execute 'source ' . fnameescape(expand('~/vimshow/vimshow.vim'))
```

Connect using an SSH reverse tunnel, then use Vim normally:

```bash
ssh -R 127.0.0.1:8765:127.0.0.1:8765 username@server
vim
```

There is no X11, XQuartz, or remote Python requirement. The remote Vim build
must support channels: `vim --version | grep channel` should show `+channel`.
