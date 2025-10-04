python

import sys, os
p = os.path.expanduser("~/.config/gdb/pystyles")
if p not in sys.path:
    sys.path.append(p)

import vscode
from pygments.styles import get_all_styles
from pygments.styles import STYLE_MAP
# expose as a style name "vscode"
STYLE_MAP["vscode"] = "vscode:VScode"

end


