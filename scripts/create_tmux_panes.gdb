python
import gdb, os, shlex, subprocess

def _tmux(args):
    subprocess.check_call(["tmux"] + shlex.split(args))

def _tmux_out(args):
    return subprocess.check_output(["tmux"] + shlex.split(args), text=True).strip()

class GdbMux(gdb.Command):
    """tmx
Split the *current tmux window* into panes and wire gdb-dashboard:
  - left-top : GDB CLI (current pane)
  - right-top: dashboard source
  - right-bot: dashboard assembly
  - left-bot : dashboard registers
"""

    def __init__(self):
        super(GdbMux, self).__init__("tmx", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        if not os.environ.get("TMUX"):
            gdb.write("[tmx] Not inside tmux. Start tmux first.\n", gdb.STDERR)
            return

        # id (%N) of the current pane (this stays as the GDB CLI)
        base = _tmux_out("display-message -p '#{pane_id}'")

        # 1) make a right column (40% width)
        _tmux(f"split-window -h -p 30 -t {base}")
        right = _tmux_out("display-message -p '#{pane_id}'")  # new right pane selected by default

        # 2) split left column: add a bottom-left pane (25% height)
        _tmux(f"select-pane -t {base}")
        _tmux("split-window -bv -p 80")   # now current is the new bottom-left
        top = _tmux_out("display-message -p '#{pane_id}'")

        # # 3) split right column into top/bottom (50/50)
        # _tmux(f"select-pane -t {right}")
        # _tmux("split-window -v -p 50")
        # right_bot = _tmux_out("display-message -p '#{pane_id}'")  # current = new bottom-right
        # _tmux("select-pane -U")                                   # move to top-right
        # right_top = _tmux_out("display-message -p '#{pane_id}'")


        # wire dashboard modules to those three panes
        try:
            gdb.execute(f"target extended-remote :3333")
            gdb.execute(f"dashboard memory -style full True")
            gdb.execute(f"dashboard breakpoints")
            gdb.execute(f"dashboard history")
            gdb.execute(f"dashboard threads")
            gdb.execute(f"dashboard stack")
            gdb.execute(f"dashboard source -style height 40")
            gdb.execute(f"dashboard -output {_tmux_out(f'display-message -p -t {right} #{{pane_tty}}')}")
            gdb.execute(f"dashboard source -output {_tmux_out(f'display-message -p -t {top}  #{{pane_tty}}')}")
        except gdb.error:
            gdb.write("[tmx] gdb-dashboard not loaded. `source ~/.gdb-dashboard.py` first.\n", gdb.STDERR)
            return

        # return focus to the GDB CLI (left-top)
        _tmux(f"select-pane -t {base}")

GdbMux()
class TmxClean(gdb.Command):
    """tcln
Kill all tmux panes in the *current window* except the one that hosts the GDB CLI."""

    def __init__(self):
        super(TmxClean, self).__init__("tcln", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        if not os.environ.get("TMUX"):
            gdb.write("[tmx-clean] Not inside tmux. Start tmux first.\n", gdb.STDERR)
            return

        # GDB's controlling tty (the CLI pane's TTY)
        try:
            cli_tty = os.ttyname(0)
        except Exception as e:
            gdb.write(f"[tmx-clean] Could not resolve GDB TTY: {e}\n", gdb.STDERR)
            return

        # The current pane-id (like %3). We’ll scope list/kill to this window.
        pane_id = _tmux_out("display-message -p '#{pane_id}'")

        # Get pane-id, index, and tty for all panes in *this* window.
        lines = _tmux_out(
            f"list-panes -t {pane_id} -F '#{{pane_id}} #{{pane_index}} #{{pane_tty}}'"
        ).splitlines()

        keep_id = None
        panes = []
        for ln in lines:
            pid, pidx, ptty = ln.split()
            panes.append((pid, pidx, ptty))
            if ptty == cli_tty:
                keep_id = pid

        if keep_id is None:
            # Fallback: keep our current pane if TTY match failed for some reason.
            keep_id = pane_id
            gdb.write(f"[tmx-clean] WARNING: CLI TTY {cli_tty} not found; keeping {keep_id}.\n")

        # Kill everything else by *pane-id*
        for pid, pidx, ptty in panes:
            if pid != keep_id:
                try:
                    _tmux(f"kill-pane -t {pid}")
                except subprocess.CalledProcessError as e:
                    gdb.write(f"[tmx-clean] Failed to kill pane {pid} (idx {pidx}): {e}\n", gdb.STDERR)

        # Focus the kept pane
        try:
            _tmux(f"select-pane -t {keep_id}")
        except Exception:
            pass

        gdb.write(f"[tmx-clean] Kept pane {keep_id} (tty {cli_tty}); others killed.\n")

TmxClean()
end

define hook-quit
  tcln
end

