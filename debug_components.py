
import os

search_terms = [
    "vuci-form-item-dummy",
    "VuciFormItemDummy",
    "tlt-form-model-item",
    "TltFormModelItem",
    "vuci-form-item-template",
    "VuciFormItemTemplate", 
    "vuci-form-item-custom",
    "VuciFormItemCustom"
]

root_dir = "package/feeds/vuci/vuci-ui-core/bin/vuci-ui-core/src/dist/www/assets"

print(f"Searching in {root_dir}...")

for dirpath, dirnames, filenames in os.walk(root_dir):
    for filename in filenames:
        if filename.endswith(".js") or filename.endswith(".js.gz"):
            full_path = os.path.join(dirpath, filename)
            try:
                # Basic string check (might fail for gz, but let's try raw read for js first)
                with open(full_path, 'rb') as f:
                    content = f.read()
                    for term in search_terms:
                        if term.encode('utf-8') in content:
                            print(f"Found '{term}' in {filename}")
            except Exception as e:
                print(f"Error reading {filename}: {e}")
