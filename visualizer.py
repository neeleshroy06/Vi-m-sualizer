import argparse
import os
import socket
import sys
import tempfile
import time
import tkinter as tk
from tkinter import colorchooser

# Must match g:vs_file in vimshow.vim.  VIMSHOW_FILE is useful for custom
# locations (for example, a shared mount).
FILE = os.environ.get("VIMSHOW_FILE")
if not FILE:
  FILE = (
      os.path.join(tempfile.gettempdir(), "vim_cmd.txt")
      if sys.platform == "win32"
      else "/tmp/vim_cmd.txt"
  )
FONT = {"win32": "Consolas", "darwin": "Menlo"}.get(sys.platform, "DejaVu Sans Mono")
POLL_MS = 40
HISTORY = 3             # number of commands shown
REPEAT_WINDOW = 2.0     # seconds: same command within this window -> "xN"
BG, FG, DIM = "#1e1e1e", "#4ec9b0", "#7a8a88"
BAR_BG = "#2a2a2a"


class Overlay:

  def __init__(self, listen_port=None):
    self.listen_port = listen_port
    self.server = None
    self.clients = {}
    self.root = tk.Tk()
    self.root.overrideredirect(True)
    self.root.attributes("-topmost", True)
    self.root.configure(bg=BG)
    self.root.geometry("+100+100")
    self.text_color = FG
    self.background_color = BG
    self.text_size = 16

    # header: drag handle + close button
    self.bar = tk.Frame(self.root, bg=BAR_BG)
    self.bar.pack(fill="x")
    self.title = tk.Label(
        self.bar,
        text=(f"Vi-m-sualizer  ·  port {listen_port}" if listen_port else "Vi-m-sualizer"),
        fg=DIM, bg=BAR_BG,
        font=(FONT, 9), padx=8,
    )
    self.title.pack(side="left")
    self.close_btn = tk.Label(
        self.bar, text="\u2715", fg="#cccccc", bg=BAR_BG, padx=10,
        font=(FONT, 10, "bold"), cursor="hand2",
    )
    self.close_btn.bind("<Button-1>", lambda e: self.close())
    self.close_btn.bind("<Enter>", lambda e: self.close_btn.config(bg="#c42b1c", fg="white"))
    self.close_btn.bind("<Leave>", lambda e: self.close_btn.config(bg=BAR_BG, fg="#cccccc"))
    self.close_btn.pack(side="right")
    self.edit_btn = tk.Label(
        self.bar, text="Edit", fg="#cccccc", bg=BAR_BG, padx=8,
        font=(FONT, 9), cursor="hand2",
    )
    self.edit_btn.bind("<Button-1>", lambda e: self.open_settings())
    self.edit_btn.bind("<Enter>", lambda e: self.edit_btn.config(fg="white"))
    self.edit_btn.bind("<Leave>", lambda e: self.edit_btn.config(fg="#cccccc"))
    self.edit_btn.pack(side="right")

    # commands area
    self.frame = tk.Frame(self.root, bg=BG, padx=15, pady=10)
    self.frame.pack(fill="both")

    self.history = []  # each item: [text, count, last_time]
    self.last_id = None if listen_port else self.read()[0]  # ignore stale file content
    if listen_port:
      self.start_server(listen_port)
    self.render([("Vi-m-sualizer Ready", 1)])

    # drag from anywhere except the close button
    for w in (self.root, self.bar, self.title, self.frame):
      w.bind("<Button-1>", self.start_move)
      w.bind("<B1-Motion>", self.do_move)
    self.root.protocol("WM_DELETE_WINDOW", self.close)

    self.poll()
    self.root.mainloop()

  def close(self):
    if self.server:
      for client in self.clients:
        client.close()
      self.server.close()
    if not self.listen_port:
      try:
        os.remove(FILE)
      except OSError:
        pass
    self.root.destroy()

  def open_settings(self):
    if getattr(self, "settings", None) and self.settings.winfo_exists():
      self.settings.lift()
      return

    self.settings = tk.Toplevel(self.root)
    self.settings.title("Visualizer appearance")
    self.settings.transient(self.root)
    self.settings.resizable(False, False)
    panel = tk.Frame(self.settings, padx=12, pady=12)
    panel.pack(fill="both", expand=True)

    tk.Label(panel, text="Text color").grid(row=0, column=0, sticky="w", pady=4)
    tk.Button(panel, text="Choose…", command=self.choose_text_color).grid(row=0, column=1, padx=8)
    tk.Label(panel, text="Background color").grid(row=1, column=0, sticky="w", pady=4)
    tk.Button(panel, text="Choose…", command=self.choose_background_color).grid(row=1, column=1, padx=8)
    tk.Label(panel, text="Text size").grid(row=2, column=0, sticky="w", pady=4)
    self.size_var = tk.IntVar(value=self.text_size)
    tk.Spinbox(panel, from_=8, to=48, textvariable=self.size_var, width=5).grid(row=2, column=1, sticky="w", padx=8)
    tk.Button(panel, text="Apply", command=self.apply_settings).grid(row=3, column=0, columnspan=2, pady=(10, 0))

  def choose_text_color(self):
    _, color = colorchooser.askcolor(self.text_color, parent=self.settings, title="Text color")
    if color:
      self.text_color = color

  def choose_background_color(self):
    _, color = colorchooser.askcolor(self.background_color, parent=self.settings, title="Background color")
    if color:
      self.background_color = color

  def apply_settings(self):
    self.text_size = max(8, min(48, self.size_var.get()))
    self.root.configure(bg=self.background_color)
    self.frame.configure(bg=self.background_color)
    self.render([(t, c) for t, c, _ in self.history] or [("Vi-m-sualizer Ready", 1)])
    self.settings.destroy()

  def start_server(self, port):
    self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    self.server.bind(("127.0.0.1", port))
    self.server.listen()
    self.server.setblocking(False)

  def poll_server(self):
    while True:
      try:
        client, _ = self.server.accept()
        client.setblocking(False)
        self.clients[client] = b""
      except BlockingIOError:
        break

    for client in list(self.clients):
      try:
        data = client.recv(4096)
      except BlockingIOError:
        continue
      if not data:
        client.close()
        del self.clients[client]
        continue
      self.clients[client] += data
      while b"\n" in self.clients[client]:
        raw, self.clients[client] = self.clients[client].split(b"\n", 1)
        try:
          cmd_id, text = raw.decode("utf-8").split("|", 1)
        except ValueError:
          continue
        self.record(cmd_id, text)

  def start_move(self, e):
    self.dx = e.x_root - self.root.winfo_x()
    self.dy = e.y_root - self.root.winfo_y()

  def do_move(self, e):
    self.root.geometry(f"+{e.x_root - self.dx}+{e.y_root - self.dy}")

  def read(self):
    try:
      with open(FILE, "r", encoding="utf-8") as f:
        line = f.read().strip()
      cmd_id, text = line.split("|", 1)
      return cmd_id, text
    except Exception:
      return None, None

  def render(self, items):
    for w in self.frame.winfo_children():
      w.destroy()
    # newest on top, big; older ones below, dim
    for i, (text, count) in enumerate(reversed(items)):
      label = text + (f"  x{count}" if count > 1 else "")
      is_current = i == 0
      lbl = tk.Label(
          self.frame,
          text=label,
          fg=self.text_color,
          bg=self.background_color,
          font=(FONT, self.text_size + 2 if is_current else self.text_size, "bold" if is_current else "normal"),
          anchor="w",
          justify="left",
      )
      lbl.pack(anchor="w")
      lbl.bind("<Button-1>", self.start_move)
      lbl.bind("<B1-Motion>", self.do_move)

  def record(self, cmd_id, text):
    if not cmd_id or cmd_id == self.last_id:
      return
    self.last_id = cmd_id
    now = time.time()
    if (
        self.history
        and self.history[-1][0] == text
        and now - self.history[-1][2] < REPEAT_WINDOW
    ):
      self.history[-1][1] += 1
      self.history[-1][2] = now
    else:
      self.history.append([text, 1, now])
      self.history = self.history[-HISTORY:]
    self.render([(t, c) for t, c, _ in self.history])

  def poll(self):
    if self.server:
      self.poll_server()
    else:
      cmd_id, text = self.read()
      self.record(cmd_id, text)
    self.root.after(POLL_MS, self.poll)


if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("--listen", type=int, metavar="PORT")
  args = parser.parse_args()
  Overlay(args.listen)
