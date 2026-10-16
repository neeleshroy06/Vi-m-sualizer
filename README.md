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

## SSH

The current SSH setup runs Vim and the visualizer on the remote server, then
forwards the visualizer window to your computer:

```bash
ssh -X username@server
cd ~/vimshow
python3 visualizer.py &
vim
```

`echo $DISPLAY` must print a value. macOS needs XQuartz; Windows needs an X11
client. If Tk is missing on a Debian/Ubuntu server, install `python3-tk`.
