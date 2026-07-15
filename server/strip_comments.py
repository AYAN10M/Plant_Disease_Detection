import tokenize
import io
import os

def strip_comments(source):
    io_obj = io.StringIO(source)
    out = ""
    last_lineno = -1
    last_col = 0
    try:
        for tok in tokenize.generate_tokens(io_obj.readline):
            token_type = tok[0]
            token_string = tok[1]
            start_line, start_col = tok[2]
            end_line, end_col = tok[3]
            
            if start_line > last_lineno:
                last_col = 0
            if start_col > last_col:
                out += (" " * (start_col - last_col))
                
            if token_type == tokenize.COMMENT:
                pass 
            else:
                out += token_string
                
            last_col = end_col
            last_lineno = end_line
    except Exception as e:
        return source
    
    return out

for root, _, files in os.walk(r"c:\Users\gopal\Documents\Plant_Disease_Detection\server"):
    for file in files:
        if file.endswith(".py"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            new_content = strip_comments(content)
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_content)
