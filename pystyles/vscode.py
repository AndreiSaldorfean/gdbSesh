from pygments.style import Style
from pygments.token import Comment, Keyword, Name, Number, String, Operator

class VScode(Style):
    background_color = "#0f111a"  # panel bg
    highlight_color  = "#1f2335"  # current line bg
    styles = {
        Comment:   "italic #5c6370",
        Keyword:   "bold #c678dd",
        Name:      "#e5c07b",
        Name.Function: "bold #61afef",
        Name.Class:    "bold #e06c75",
        String:    "#98c379",
        Number:    "#d19a66",
        Operator:  "#56b6c2",
    }
