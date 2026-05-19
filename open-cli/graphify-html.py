import json
from pathlib import Path

extraction = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding='utf-8'))
analysis = json.loads(Path('graphify-out/.graphify_analysis.json').read_text(encoding='utf-8'))
labels_raw = json.loads(Path('graphify-out/.graphify_labels.json').read_text(encoding='utf-8')) if Path('graphify-out/.graphify_labels.json').exists() else {}

from graphify.build import build_from_json
from graphify.export import to_html

G = build_from_json(extraction)
communities = {int(k): v for k, v in analysis['communities'].items()}
labels = {int(k): v for k, v in labels_raw.items()}

NODE_LIMIT = 5000
if G.number_of_nodes() > NODE_LIMIT:
    print(f'Graph has {G.number_of_nodes()} nodes (above {NODE_LIMIT} limit). Building aggregated community view...')
else:
    to_html(G, communities, 'graphify-out/graph.html', community_labels=labels or None)
    print(f'graph.html written - open in any browser, no server needed')