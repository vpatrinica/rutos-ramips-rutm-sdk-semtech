
import os

def search_in_binary(file_path, search_term):
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
            if search_term.encode('utf-8') in content:
                return True
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
    return False

search_term = "vuci-form-item-dummy"
root_dir = "package/feeds/vuci/vuci-ui-core"
found = False

for dirpath, dirnames, filenames in os.walk(root_dir):
    for filename in filenames:
        full_path = os.path.join(dirpath, filename)
        if search_in_binary(full_path, search_term):
            print(f"Found '{search_term}' in {full_path}")
            found = True

if not found:
    print(f"'{search_term}' not found in {root_dir}")
