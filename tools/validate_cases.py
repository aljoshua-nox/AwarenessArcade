"""Static validation for the interview case graphs.

There is no headless Godot in this workspace, so a broken `next` target or a
dead-end node would otherwise only show up as a blank screen mid-playtest.
Run from anywhere:  python tools/validate_cases.py
"""
import json, glob, os, sys

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob(os.path.join(base, "resources", "cases", "interview_case_*.json")))

# Evidence ids available across the whole session (seeded pools + granted testimony)
global_evidence = set()
parsed = {}
for f in files:
    with open(f, encoding="utf-8") as fh:
        data = json.load(fh)
    parsed[f] = data
    for item in data.get("evidence", []):
        global_evidence.add(item["id"])
    for node in data.get("nodes", {}).values():
        for g in node.get("grants_evidence", []):
            global_evidence.add(g["id"])

errors = []
for f, data in parsed.items():
    name = os.path.basename(f)
    nodes = data.get("nodes", {})
    ids = set(nodes.keys())

    def check(target, where):
        if not target:
            errors.append(f"{name}: EMPTY target at {where}")
        elif target not in ids:
            errors.append(f"{name}: '{target}' -> missing node (at {where})")

    check(data.get("start_node"), "start_node")
    if "failure_node" in data:
        check(data["failure_node"], "failure_node")
    person = data.get("person", {})
    if "hesitant_start" in person:
        check(person["hesitant_start"], "person.hesitant_start")
    if ("min_credibility" in person) != ("hesitant_start" in person):
        errors.append(f"{name}: min_credibility/hesitant_start must be paired")

    endings = 0
    for nid, node in nodes.items():
        if node.get("outcome"):
            endings += 1
        for i, c in enumerate(node.get("choices", [])):
            check(c.get("next"), f"{nid}.choices[{i}]")
        if len(node.get("choices", [])) > 4:
            errors.append(f"{name}: {nid} has >4 choices (UI has 4 buttons)")
        for i, e in enumerate(node.get("accepts_evidence", [])):
            check(e.get("next"), f"{nid}.accepts_evidence[{i}]")
            eid = e.get("evidence_id")
            if eid not in global_evidence:
                errors.append(f"{name}: {nid}.accepts_evidence[{i}] unknown evidence '{eid}'")
        ec = node.get("evidence_check")
        if ec:
            check(ec.get("next_if_met"), f"{nid}.evidence_check.next_if_met")
            check(ec.get("next_if_not_met"), f"{nid}.evidence_check.next_if_not_met")
            for eid in ec.get("required_evidence", []):
                if eid not in global_evidence:
                    errors.append(f"{name}: {nid}.evidence_check unknown evidence '{eid}'")
        q = node.get("tactic_quiz")
        if q:
            opts = q.get("options", [])
            if len(opts) > 4:
                errors.append(f"{name}: {nid} quiz has >4 options (UI has 4 buttons)")
            correct = [o for o in opts if o.get("correct")]
            if len(correct) != 1:
                errors.append(f"{name}: {nid} quiz has {len(correct)} correct options (need exactly 1)")
            for i, o in enumerate(opts):
                if not o.get("feedback"):
                    errors.append(f"{name}: {nid} quiz option {i} has no feedback")
                if o.get("next"):
                    check(o["next"], f"{nid}.tactic_quiz.options[{i}]")
            for k in ("next", "next_correct", "next_wrong"):
                if q.get(k):
                    check(q[k], f"{nid}.tactic_quiz.{k}")
            if not any(q.get(k) for k in ("next", "next_correct", "next_wrong")) and not all(o.get("next") for o in opts):
                errors.append(f"{name}: {nid} quiz has no next target")
        if node.get("evidence_prompt") and not node.get("accepts_evidence"):
            errors.append(f"{name}: {nid} shows Present Evidence but accepts nothing")

        # A node the player can enter but never leave.
        has_exit = bool(node.get("outcome") or node.get("choices")
                        or node.get("evidence_check") or node.get("tactic_quiz"))
        if not has_exit:
            errors.append(f"{name}: {nid} is a dead end (no choices, outcome, quiz or check)")
        # Evidence-only nodes strand the player if they lack the right item.
        if node.get("evidence_prompt") and not node.get("choices") and not node.get("outcome"):
            errors.append(f"{name}: {nid} exits only via evidence - no fallback choice")
        # An answered quiz node must be able to fall through if re-entered.
        q2 = node.get("tactic_quiz")
        if q2 and not node.get("prompt") and not (q2.get("next") or q2.get("next_correct")):
            errors.append(f"{name}: {nid} quiz has no shared 'next' to fall through to on re-entry")

    # reachability from start
    seen, stack = set(), [data.get("start_node")]
    if person.get("hesitant_start"):
        stack.append(person["hesitant_start"])
    if data.get("failure_node"):
        stack.append(data["failure_node"])
    while stack:
        n = stack.pop()
        if not n or n in seen or n not in nodes:
            continue
        seen.add(n)
        node = nodes[n]
        for c in node.get("choices", []):
            stack.append(c.get("next"))
        for e in node.get("accepts_evidence", []):
            stack.append(e.get("next"))
        ec = node.get("evidence_check")
        if ec:
            stack += [ec.get("next_if_met"), ec.get("next_if_not_met")]
        q = node.get("tactic_quiz")
        if q:
            stack += [q.get("next"), q.get("next_correct"), q.get("next_wrong")]
            stack += [o.get("next") for o in q.get("options", [])]
    orphans = ids - seen
    if orphans:
        errors.append(f"{name}: unreachable nodes {sorted(orphans)}")
    print(f"{name}: {len(ids)} nodes, {endings} endings, "
          f"{sum(1 for n in nodes.values() if n.get('tactic_quiz'))} quiz")

# --- Tactic notebook catalogue ------------------------------------------------
# Every tactic_id in a case must resolve to a catalogue entry, and every
# catalogue entry must be reachable - a tactic nothing can unlock is an entry
# the player is shown as locked forever.
catalogue_path = os.path.join(base, "resources", "tactics", "tactic_catalogue.json")
with open(catalogue_path, encoding="utf-8") as fh:
    catalogue = json.load(fh).get("tactics", [])

catalogue_ids = set()
for t in catalogue:
    tid = t.get("id", "")
    if not tid:
        errors.append("tactic_catalogue.json: an entry has no id")
    elif tid in catalogue_ids:
        errors.append(f"tactic_catalogue.json: duplicate id '{tid}'")
    else:
        catalogue_ids.add(tid)
    for field in ("name", "summary", "spot_it"):
        if not str(t.get(field, "")).strip():
            errors.append(f"tactic_catalogue.json: '{tid}' has no {field}")

reachable = set()
for f, data in parsed.items():
    name = os.path.basename(f)
    # Evidence only teaches its tactic when it is accepted somewhere and not
    # flagged wrong, so an item nothing accepts can never unlock its entry.
    accepted_ids = set()
    for node in data.get("nodes", {}).values():
        for entry in node.get("accepts_evidence", []):
            if not entry.get("wrong", False):
                accepted_ids.add(str(entry.get("evidence_id", "")))

    items = list(data.get("evidence", []))
    for node in data.get("nodes", {}).values():
        items += list(node.get("grants_evidence", []))
    for item in items:
        tid = item.get("tactic_id")
        if not tid:
            continue
        if tid not in catalogue_ids:
            errors.append(f"{name}: evidence '{item.get('id')}' points at unknown tactic '{tid}'")
        elif str(item.get("id", "")) in accepted_ids:
            reachable.add(tid)

    for nid, node in data.get("nodes", {}).items():
        quiz = node.get("tactic_quiz")
        if not quiz:
            continue
        tid = quiz.get("tactic_id")
        if not tid:
            continue
        if tid not in catalogue_ids:
            errors.append(f"{name}: quiz '{nid}' points at unknown tactic '{tid}'")
        else:
            reachable.add(tid)

for tid in sorted(catalogue_ids - reachable):
    errors.append(f"tactic_catalogue.json: '{tid}' can never be unlocked - "
                  f"nothing in any case grants it")

print(f"tactic_catalogue.json: {len(catalogue_ids)} tactics, {len(reachable)} reachable")

# --- Tactic quizzes carry a name ---------------------------------------------
# The ending names the tactics the player got wrong, so an unlabelled quiz would
# silently drop out of that list rather than fail.
for f, data in parsed.items():
    name = os.path.basename(f)
    for nid, node in data.get("nodes", {}).items():
        quiz = node.get("tactic_quiz")
        if not quiz:
            continue
        if not str(quiz.get("tactic", "")).strip():
            errors.append(f"{name}: quiz at '{nid}' has no 'tactic' name to report in the ending")

# --- Disposition blocks ------------------------------------------------------
# A victim's opening beat varies with what the player did to them in the
# prologue. `neutral` is deliberately absent: it means "the case exactly as
# written", which is what a skip-the-prologue run must get.
VALID_DISPOSITIONS = {"harmed", "resistant", "unfinished"}

for f, data in parsed.items():
    name = os.path.basename(f)
    person = data.get("person", {})
    for key, entry in person.get("dispositions", {}).items():
        where = f"{name}: disposition '{key}'"
        if key == "neutral":
            errors.append(f"{where} must not be declared - neutral is the unmodified case")
            continue
        if key not in VALID_DISPOSITIONS:
            errors.append(f"{where} is not one of {sorted(VALID_DISPOSITIONS)}")
            continue
        if not isinstance(entry, dict):
            errors.append(f"{where} is not an object")
            continue
        if "cooperation" not in entry and "prompt" not in entry:
            errors.append(f"{where} changes nothing - give it a cooperation or a prompt")
        coop = entry.get("cooperation")
        if coop is not None:
            if not isinstance(coop, int) or isinstance(coop, bool):
                errors.append(f"{where} cooperation is not an integer")
            elif not 1 <= coop <= 100:
                # 0 would end the interview on the opening frame.
                errors.append(f"{where} cooperation {coop} is outside 1-100")
        for field in ("prompt", "note"):
            if field in entry and not str(entry[field]).strip():
                errors.append(f"{where} has an empty {field}")
        if "[color" in str(entry.get("prompt", "")) or "[font" in str(entry.get("prompt", "")):
            errors.append(f"{where} prompt carries markup - the engine styles case text")

# --- Prologue <-> investigation identity -------------------------------------
# Maria is "Maria S." in the prologue and "Maria Santos" in her case file, so
# the two halves can only be joined on a stable id. A mismatch here does not
# crash anything - it silently makes a victim read as never-called - so it is
# checked statically instead.
#
# Add a row here whenever a prologue victim gains an interview.
EXPECTED_LINKS = {
    "maria_santos": "interview_case_001.json",
    "kevin_d": "interview_case_002.json",
}

content_path = os.path.join(base, "resources", "dialogue", "call_content.json")
with open(content_path, encoding="utf-8") as fh:
    victims = json.load(fh).get("victims", [])

prologue_ids = {}
for v in victims:
    vid = v.get("person_id", "")
    vname = v.get("name", "?")
    if not vid:
        errors.append(f"call_content.json: victim '{vname}' has no person_id")
    elif vid in prologue_ids:
        errors.append(f"call_content.json: duplicate person_id '{vid}'"
                      f" ({prologue_ids[vid]} and {vname})")
    else:
        prologue_ids[vid] = vname

case_ids = {os.path.basename(f): d.get("person", {}).get("person_id", "")
            for f, d in parsed.items()}

for pid, case_file in EXPECTED_LINKS.items():
    if pid not in prologue_ids:
        errors.append(f"call_content.json: expected a victim with person_id '{pid}'")
    if case_ids.get(case_file) != pid:
        errors.append(f"{case_file}: person_id is '{case_ids.get(case_file)}',"
                      f" expected '{pid}' to match the prologue victim")

linked = sorted(pid for pid in EXPECTED_LINKS if pid in prologue_ids
                and case_ids.get(EXPECTED_LINKS[pid]) == pid)
print(f"call_content.json: {len(prologue_ids)} victims, "
      f"{len(linked)} linked to an interview ({', '.join(linked) if linked else 'none'})")

print()
if errors:
    print("FAILURES:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("All case graphs valid.")
