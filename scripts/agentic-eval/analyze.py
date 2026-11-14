"""Summarize agentic eval transcripts ($EVAL_DIR/runs/*.jsonl) with their scores (results.tsv).

Usage: python3 -I analyze.py [eval-dir]   (default: $EVAL_DIR, else $TMPDIR/agentic-eval)
"""

import collections
import csv
import json
import os
import pathlib
import sys
import tempfile

default_dir = os.environ.get("EVAL_DIR") or os.path.join(tempfile.gettempdir(), "agentic-eval")
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else default_dir)
scores = {(r["task"], r["cond"]): r for r in csv.DictReader(open(root / "results.tsv"), delimiter="\t")}


def summarize(path):
    tools = collections.Counter()
    agents = collections.Counter()
    skills = collections.Counter()
    result = {}
    for line in open(path):
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "assistant" and not event.get("parent_tool_use_id"):
            for block in event["message"].get("content", []):
                if block.get("type") != "tool_use":
                    continue
                tools[block["name"]] += 1
                if block["name"] == "Agent":
                    agents[block["input"].get("subagent_type", "?")] += 1
                if block["name"] == "Skill":
                    skills[block["input"].get("skill", "?")] += 1
        if event.get("type") == "result":
            result = event
    usage = result.get("usage", {})
    context_in = sum(usage.get(k, 0) for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
    return {
        "cost": result.get("total_cost_usd"),
        "turns": result.get("num_turns"),
        "minutes": round(result.get("duration_ms", 0) / 60000, 1),
        "in_tok_k": round(context_in / 1000),
        "out_tok_k": round(usage.get("output_tokens", 0) / 1000, 1),
        "tool_calls": sum(tools.values()),
        "subagents": dict(agents),
        "skills": dict(skills),
        "status": result.get("subtype", "no result"),
    }


rows = []
for path in sorted((root / "runs").glob("*.jsonl")):
    task, cond = path.stem.rsplit("-", 1)
    s = summarize(path)
    sc = scores.get((task, cond), {})
    rows.append((task, cond, sc.get("hidden"), sc.get("unit"), sc.get("type_errors"), s))

header = "task cond hidden unit type_err cost$ turns min in_k out_k tools subagents skills status".split()
print("\t".join(header))
for task, cond, hidden, unit, terr, s in rows:
    cost = f"{s['cost']:.2f}" if s["cost"] is not None else "?"
    print("\t".join(map(str, [task, cond, hidden, unit, terr, cost, s["turns"], s["minutes"], s["in_tok_k"], s["out_tok_k"], s["tool_calls"], s["subagents"] or "-", s["skills"] or "-", s["status"]])))

totals = collections.defaultdict(lambda: collections.Counter())
for task, cond, hidden, unit, terr, s in rows:
    if hidden is None:  # run never scored (stopped or still running)
        continue
    t = totals[cond]
    t["runs"] += 1
    t["hidden_pass"] += hidden == "pass"
    t["unit_pass"] += unit == "pass"
    t["cost"] += s["cost"] or 0
    t["minutes"] += s["minutes"]
    t["in_k"] += s["in_tok_k"]
    t["tools"] += s["tool_calls"]
print()
for cond, t in totals.items():
    print(f"{cond}: hidden {t['hidden_pass']}/{t['runs']}, unit {t['unit_pass']}/{t['runs']}, cost ${t['cost']:.2f}, {t['minutes']:.1f} min, {t['in_k']}k input tokens, {t['tools']} tool calls")
