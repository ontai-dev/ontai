#!/usr/bin/env python3
"""Test-only graphify graph builder.

Builds a separate knowledge graph containing only test code -- *_test.go files
and all files under test/ directories (unit, integration, e2e) across every
operator repo. Output goes to graphify-tests-out/graph.json and never touches
the production graph at graphify-out/graph.json.

Run from the ontai root:
    python graphify-tests.py

The production graph at graphify-out/ excludes test files via .graphifyignore.
This script builds the complementary graph so test infrastructure, shared
helpers, fake clients, scheme builders, and suite structure are queryable.
"""
import json
import sys
from pathlib import Path

REPOS = [
    "conductor",
    "guardian",
    "platform",
    "wrapper",
    "seam-core",
    "domain-core",
    "app-core",
]

ROOT = Path(__file__).parent.resolve()
OUT_DIR = ROOT / "graphify-tests-out"


def collect_test_files() -> list[Path]:
    """Return all *_test.go files and Go files under test/ directories."""
    seen: set[Path] = set()
    files: list[Path] = []

    def add(p: Path) -> None:
        r = p.resolve()
        if r not in seen:
            seen.add(r)
            files.append(r)

    for repo in REPOS:
        repo_path = ROOT / repo
        if not repo_path.exists():
            continue
        # *_test.go co-located with production code
        for f in repo_path.rglob("*_test.go"):
            if "vendor" not in f.parts and "graphify" not in str(f):
                add(f)
        # All .go files under test/ trees (unit, integration, e2e)
        for test_dir in repo_path.rglob("test"):
            if not test_dir.is_dir():
                continue
            if "vendor" in test_dir.parts:
                continue
            for f in test_dir.rglob("*.go"):
                add(f)

    return sorted(files)


def main() -> None:
    try:
        from graphify.extract import extract
        from graphify.build import build
        from graphify.cluster import cluster
        from graphify.export import to_json
    except ImportError:
        print("graphify not found. Install with: pip install graphifyy", file=sys.stderr)
        sys.exit(1)

    test_files = collect_test_files()
    print(f"Test files collected: {len(test_files)}")

    OUT_DIR.mkdir(exist_ok=True)

    print("Running AST extraction...")
    result = extract(test_files, cache_root=None)
    print(f"AST: {len(result['nodes'])} nodes, {len(result['edges'])} edges")

    print("Building graph...")
    G = build([result])
    print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")

    print("Detecting communities...")
    communities = cluster(G)
    print(f"Communities: {len(communities)}")

    out_path = OUT_DIR / "graph.json"
    ok = to_json(G, communities, str(out_path), force=True)
    if not ok:
        print("Warning: to_json returned False -- check output.", file=sys.stderr)
    print(f"Saved: {out_path}")

    sizes = sorted(((len(v), k) for k, v in communities.items()), reverse=True)
    print("\nTop communities by size:")
    for size, comm_id in sizes[:15]:
        members = communities[comm_id]
        print(f"  [{comm_id}] {size} nodes -- e.g. {', '.join(members[:3])}")


if __name__ == "__main__":
    main()
