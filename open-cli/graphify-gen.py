import json
from graphify.detect import detect
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.export import to_html, to_json
from pathlib import Path

# Step 1: Detect
detect_result = detect(Path('D:\AI_Projects\open-cli'))
Path('graphify-out/.graphify_detect.json').write_text(json.dumps(detect_result, indent=2), encoding='utf-8')
print(f"Corpus: {detect_result['total_files']} files, ~{detect_result['total_words']} words")

# Step 2: AST extraction
code_files = []
for f in detect_result.get('files', {}).get('code', []):
    code_files.extend(collect_files(Path(f)) if Path(f).is_dir() else [Path(f)])

ast_result = extract(code_files)
Path('graphify-out/.graphify_ast.json').write_text(json.dumps(ast_result, indent=2), encoding='utf-8')
print(f"AST: {len(ast_result['nodes'])} nodes, {len(ast_result['edges'])} edges")

# Step 3: Load cached semantic
sem_cache = []
cache_dir = Path('graphify-out/cache/semantic')
if cache_dir.exists():
    for f in cache_dir.glob('*.json'):
        try:
            sem_cache.append(json.loads(f.read_text(encoding='utf-8')))
        except:
            pass

sem_nodes = []
sem_edges = []
for item in sem_cache:
    sem_nodes.extend(item.get('nodes', []))
    sem_edges.extend(item.get('edges', []))

# Step 4: Merge
seen = {n['id'] for n in ast_result['nodes']}
merged_nodes = list(ast_result['nodes'])
for n in sem_nodes:
    if n['id'] not in seen:
        merged_nodes.append(n)
        seen.add(n['id'])

merged_edges = ast_result['edges'] + sem_edges
merged = {
    'nodes': merged_nodes,
    'edges': merged_edges,
    'hyperedges': [],
    'input_tokens': 0,
    'output_tokens': 0,
}
Path('graphify-out/.graphify_extract.json').write_text(json.dumps(merged, indent=2), encoding='utf-8')
print(f"Merged: {len(merged_nodes)} nodes, {len(merged_edges)} edges")

# Step 5: Build graph
G = build_from_json(merged)
communities = cluster(G)
cohesion = score_all(G, communities)
gods = god_nodes(G)
surprises = surprising_connections(G, communities)

analysis = {
    'communities': {str(k): v for k, v in communities.items()},
    'cohesion': {str(k): v for k, v in cohesion.items()},
    'gods': gods,
    'surprises': surprises,
}
Path('graphify-out/.graphify_analysis.json').write_text(json.dumps(analysis, indent=2), encoding='utf-8')
print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities")

# Step 6: Labels
labels = {
    0: "Tool Execution & Testing",
    1: "Agent Engine & Executor",
    2: "LLM Providers",
    3: "Security & Policy",
    4: "Session & Memory",
    5: "Architecture Design",
    6: "Commands Extension",
    7: "Hooks Extension",
    8: "Skills Extension",
    9: "MCP Client & Protocol",
    10: "Config Schema",
    11: "Server & Orchestrator",
    12: "CLI Entry Point",
    13: "TUI Components",
    14: "File & Git Tools",
    15: "Checkpoint Manager",
    16: "Markdown Renderer",
    17: "Provider Format",
    18: "Hook Manager",
    19: "Provider Chat",
    20: "Security Boundary",
    21: "Path Checking",
    22: "Context & Undo",
    23: "Policy Engine",
    24: "Trusted Folders",
    25: "Session Core",
    26: "Agent Rationale",
    27: "Init Module",
    28: "Registry Pattern",
    29: "Message Types",
    30: "Shutdown & Health",
    31: "Parser Commands",
    32: "Skill Loader",
    33: "Model Selector",
    34: "Theme Support",
    35: "Subagent Manager",
    36: "TUI Design",
    37: "Agent Server",
    38: "Implementation Plans",
    39: "LLM Core",
    40: "Commands Test",
    41: "Hooks Test",
    42: "Skills Test",
    43: "MCP Test",
    44: "Config YAML",
    45: "MCP Tools",
    46: "Effect Enum",
    47: "Permission Read",
    48: "Cmd Error",
    49: "Registry Register",
    50: "Registry Get",
    51: "Registry List",
    52: "Skill Get",
    53: "Skill List",
    54: "Security Level",
    55: "Security Context",
    56: "Effect Allow",
    57: "Effect Deny",
    58: "Path Normalize",
    59: "Is Trusted",
    60: "Checkpoint",
    61: "REPL",
    62: "Command Entity",
    63: "Security Policy",
    64: "Tool Executor Test",
    65: "Markdown Renderer Test",
    66: "Message",
    67: "Tests",
    68: "Tool Framework",
    69: "Server Health",
    70: "Agent Core",
    71: "Agent Type",
    72: "Content Block",
    73: "Tool Call",
    74: "Provider Base",
    75: "AutoMemory",
    76: "CheckpointManager",
    77: "Learning",
    78: "MemoryCategory"
}
Path('graphify-out/.graphify_labels.json').write_text(json.dumps({str(k): v for k, v in labels.items()}), encoding='utf-8')

# Step 7: Generate HTML
to_html(G, communities, 'graphify-out/graph.html', community_labels=labels or None)
print(f"graph.html written - open in any browser")

# Step 8: Save graph.json
to_json(G, communities, 'graphify-out/graph.json')
print("Done!")