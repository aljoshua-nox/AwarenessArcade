"""Static validation for the interview case graphs.

There is no headless Godot in this workspace, so a broken `next` target or a
dead-end node would otherwise only show up as a blank screen mid-playtest.
Run from anywhere:  python tools/validate_cases.py
"""
import json, glob, os, re, sys

base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob(os.path.join(base, "resources", "cases", "interview_case_*.json")))

# Script is the fourth half of identity, and the one the investigation routes
# on: a suspect answers for the scripts their floor runs (`accepts_scripts` on a
# row, `required_scripts` on a check), and a victim's testimony carries the
# script that hit them. So every victim's case says which one (`person.script`),
# every call script says the same (`person.script_id` - `script` there is the
# card's display name, "Bank fraud desk"), the two must agree for a linked
# victim, and every id must come from this closed vocabulary. Add to it when a
# new script is written; a typo would otherwise be a testimony no suspect can
# ever accept - which the coverage checks below would then also report.
SCRIPT_IDS = {"bank_fraud", "tech_support", "lottery", "family_emergency",
              "government", "job_offer", "utility"}


def check_script_set(sids, where):
    """A list of script ids, or ["*"] for every script."""
    if not isinstance(sids, list) or not sids:
        errors.append(f"{where} must be a non-empty list of script ids, or [\"*\"]")
        return False
    ok = True
    for sid in sids:
        if sid != "*" and sid not in SCRIPT_IDS:
            errors.append(f"{where} names '{sid}', not one of {sorted(SCRIPT_IDS)}")
            ok = False
    if "*" in sids and len(sids) > 1:
        errors.append(f"{where}: \"*\" already means every script - list nothing beside it")
        ok = False
    return ok


def set_covers(sids, script):
    return bool(script) and isinstance(sids, list) and ("*" in sids or script in sids)


# An accepts_evidence row either names one item or accepts every testimony from
# victims of a set of scripts. Named rows win at runtime, so a specific reaction
# is never flattened into the generic one; the script row is the floor.
def check_accepts_row(e, where):
    named = "evidence_id" in e
    routed = "accepts_scripts" in e
    if named == routed:
        errors.append(f"{where} must carry an evidence_id or an accepts_scripts set - not both, not neither")
        return
    if named:
        if e["evidence_id"] not in global_evidence:
            errors.append(f"{where} unknown evidence '{e['evidence_id']}'")
        return
    if not check_script_set(e["accepts_scripts"], f"{where}.accepts_scripts"):
        return
    if e.get("wrong") or e.get("contradicts"):
        errors.append(f"{where}: a script row cannot be a decoy or a contradiction - name the item instead")
    if not str(e.get("response", "")).strip():
        errors.append(f"{where}: a script row needs a response - it is the line for every witness nobody wrote one for")


# What a node's `dispositions` block may vary, mirrored from interview.gd.
NODE_VARIANT_KEYS = {"harmed", "resistant", "unfinished"}
NODE_OVERRIDE_KEYS = {"prompt", "choices", "evidence_hint", "evidence_prompt",
                      "accepts_evidence", "milestone", "grants_evidence", "claim", "tactic_quiz"}

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

    data_own_ids = {item["id"] for item in data.get("evidence", [])}
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
            check_accepts_row(e, f"{name}: {nid}.accepts_evidence[{i}]")
        ec = node.get("evidence_check")
        if ec:
            check(ec.get("next_if_met"), f"{nid}.evidence_check.next_if_met")
            check(ec.get("next_if_not_met"), f"{nid}.evidence_check.next_if_not_met")
            by_id = "required_evidence" in ec
            by_script = "required_scripts" in ec
            if by_id == by_script:
                errors.append(f"{name}: {nid}.evidence_check must carry required_evidence or required_scripts - not both, not neither")
            for eid in ec.get("required_evidence", []):
                if eid not in global_evidence:
                    errors.append(f"{name}: {nid}.evidence_check unknown evidence '{eid}'")
            if by_script:
                check_script_set(ec["required_scripts"], f"{name}: {nid}.evidence_check.required_scripts")
                # A script check counts either testimonies (`min_matching`) or
                # distinct scripts (`min_distinct_scripts`) - one of the two.
                has_count = isinstance(ec.get("min_matching"), int) and ec["min_matching"] >= 1
                has_breadth = isinstance(ec.get("min_distinct_scripts"), int) and ec["min_distinct_scripts"] >= 1
                if has_count == has_breadth:
                    errors.append(f"{name}: {nid}.evidence_check.required_scripts needs exactly one of"
                                  f" min_matching or min_distinct_scripts (>= 1)"
                                  f" - 'every testimony of these scripts' is not a thing a player can be asked to hold")
                if has_breadth and isinstance(ec["required_scripts"], list) and "*" not in ec["required_scripts"] \
                        and ec["min_distinct_scripts"] > len(ec["required_scripts"]):
                    errors.append(f"{name}: {nid}.evidence_check asks for {ec['min_distinct_scripts']} distinct scripts"
                                  f" but only lists {len(ec['required_scripts'])}")
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
        variants = [node] + list(node.get("dispositions", {}).values())
        for variant in variants:
            for c in variant.get("choices", []):
                stack.append(c.get("next"))
            for e in variant.get("accepts_evidence", []):
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

    # --- Disposition variants on nodes and evidence --------------------------
    # A node may carry `dispositions`: per-outcome overrides of the keys the
    # engine lets a variant replace. The opening node's prompt belongs to the
    # person block, so a node-level prompt there would be silently ignored.
    for nid, node in nodes.items():
        for key, override in node.get("dispositions", {}).items():
            where = f"{name}: {nid}.dispositions['{key}']"
            if key not in NODE_VARIANT_KEYS:
                errors.append(f"{where} is not one of {sorted(NODE_VARIANT_KEYS)}")
                continue
            if not isinstance(override, dict) or not override:
                errors.append(f"{where} must be a non-empty object")
                continue
            bad = set(override) - NODE_OVERRIDE_KEYS
            if bad:
                errors.append(f"{where} overrides {sorted(bad)} - the engine only applies {sorted(NODE_OVERRIDE_KEYS)}")
            if nid == data.get("start_node") and "prompt" in override:
                errors.append(f"{where} sets a prompt on the start node - the person block's disposition prompt owns that beat")
            for tf in ("prompt", "evidence_hint"):
                if "[color" in str(override.get(tf, "")) or "[font" in str(override.get(tf, "")):
                    errors.append(f"{where}.{tf} carries markup - the engine styles case text")
            choices = override.get("choices", [])
            if "choices" in override and not choices:
                errors.append(f"{where} replaces the choices with nothing - a dead end in that outcome")
            if len(choices) > 4:
                errors.append(f"{where} has >4 choices (UI has 4 buttons)")
            for i, c in enumerate(choices):
                check(c.get("next"), f"{nid}.dispositions['{key}'].choices[{i}]")
            for i, e in enumerate(override.get("accepts_evidence", [])):
                check(e.get("next"), f"{nid}.dispositions['{key}'].accepts_evidence[{i}]")
                check_accepts_row(e, f"{where}.accepts_evidence[{i}]")
            q = override.get("tactic_quiz")
            if q is not None:
                if not node.get("tactic_quiz"):
                    errors.append(f"{where} overrides a quiz on a node that has none")
                elif set(q) - {"setup", "question"}:
                    errors.append(f"{where}.tactic_quiz may only reword setup/question - the options are the lesson")
        for i, e in enumerate(node.get("accepts_evidence", [])):
            for key in e.get("responses", {}):
                if key not in NODE_VARIANT_KEYS:
                    errors.append(f"{name}: {nid}.accepts_evidence[{i}].responses['{key}'] is not a disposition")

    for i, item in enumerate(data.get("evidence", [])):
        where = f"{name}: evidence[{i}] '{item.get('id')}'"
        for key in item.get("only_for", []):
            if key not in NODE_VARIANT_KEYS:
                errors.append(f"{where}.only_for names '{key}', not a disposition")
        for key, override in item.get("dispositions", {}).items():
            if key not in NODE_VARIANT_KEYS:
                errors.append(f"{where}.dispositions['{key}'] is not a disposition")
                continue
            if not isinstance(override, dict) or not override:
                errors.append(f"{where}.dispositions['{key}'] must be a non-empty object")
                continue
            bad = set(override) - {"omit", "label", "description", "tactic", "tactic_id"}
            if bad:
                errors.append(f"{where}.dispositions['{key}'] overrides {sorted(bad)}")
            if "omit" in override and override["omit"] is not True:
                errors.append(f"{where}.dispositions['{key}'].omit must be true")
        if item.get("only_for") and item.get("dispositions", {}).get("omit"):
            errors.append(f"{where} uses both only_for and omit")

    # Every outcome the prologue can hand this person must still leave an
    # evidence step with something presentable. An item the variant omits, or a
    # hit that only names an omitted item, is a witness who cannot be secured.
    if person.get("dispositions"):
        for outcome in sorted(NODE_VARIANT_KEYS) + ["neutral"]:
            pool = set()
            for item in data.get("evidence", []):
                if "only_for" in item and outcome not in item["only_for"]:
                    continue
                if item.get("dispositions", {}).get(outcome, {}).get("omit"):
                    continue
                pool.add(item["id"])
            for nid, node in nodes.items():
                resolved = dict(node)
                resolved.update(node.get("dispositions", {}).get(outcome, {}))
                if not resolved.get("evidence_prompt"):
                    continue
                # Only a hit that moves the interview on counts; corroboration
                # that loops back to the same node secures nobody.
                hits = [e.get("evidence_id", "") for e in resolved.get("accepts_evidence", [])
                        if not e.get("wrong") and e.get("next") != nid]
                if not any(h in pool or h not in data_own_ids for h in hits):
                    errors.append(f"{name}: {nid} has no presentable hit that advances when the witness is "
                                  f"'{outcome}' - every accepted item is omitted for that outcome")
    print(f"{name}: {len(ids)} nodes, {endings} endings, "
          f"{sum(1 for n in nodes.values() if n.get('tactic_quiz'))} quiz")

# --- Contradictions ----------------------------------------------------------
# A claim the player cannot disprove is dead text, and a contradiction attached
# to a node that makes no claim gives them nothing to aim at. Both halves have
# to exist on the same node.
for f, data in parsed.items():
    name = os.path.basename(f)
    for nid, node in data.get("nodes", {}).items():
        claim = str(node.get("claim", "")).strip()
        breakers = [e for e in node.get("accepts_evidence", [])
                    if e.get("contradicts", False)]
        if claim and not breakers:
            errors.append(f"{name}: '{nid}' makes a claim nothing can disprove")
        if breakers and not claim:
            errors.append(f"{name}: '{nid}' accepts contradicting evidence but states no claim")
        for entry in breakers:
            if entry.get("wrong", False):
                errors.append(f"{name}: '{nid}' marks the same evidence as both a contradiction and wrong")
            if int(entry.get("cooperation", 0)) <= 0:
                errors.append(f"{name}: '{nid}' catches a lie without rewarding it")

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

# --- Settings ----------------------------------------------------------------
# Every case names where its interview happens (`person.setting`), and the
# interview picks its background from that. The vocabulary is the keys of
# SETTING_BACKGROUNDS in interview.gd, read from the script so the two cannot
# drift; a setting the engine does not know would silently fall back to the
# office photo, which is the bug this exists to catch.
settings_vocab = set()
interview_path = os.path.join(base, "scripts", "investigation", "interview.gd")
if os.path.exists(interview_path):
    with open(interview_path, encoding="utf-8") as fh:
        in_block = False
        for line in fh:
            if line.startswith("const SETTING_BACKGROUNDS"):
                in_block = True
                continue
            if in_block:
                if line.strip().startswith("}"):
                    break
                m = re.match(r'\s*"(\w+)":', line)
                if m:
                    settings_vocab.add(m.group(1))
if not settings_vocab:
    errors.append("interview.gd: could not read SETTING_BACKGROUNDS - the settings check has nothing to check against")
for f, data in parsed.items():
    name = os.path.basename(f)
    setting = data.get("person", {}).get("setting", "")
    if not setting:
        errors.append(f"{name}: person has no setting - the interview needs to know where it happens")
    elif settings_vocab and setting not in settings_vocab:
        errors.append(f"{name}: setting '{setting}' is not one of {sorted(settings_vocab)} (interview.gd SETTING_BACKGROUNDS)")

# --- The briefing ------------------------------------------------------------
# The desk sergeant's brief on the case journal's first tab. Prose like any
# other, so it gets the register lint and the one-copy rule below; on top of
# that, the only token it may carry is {statements} (the budget) - the number
# and the company are the street's to reveal, and the journal does not expand
# them, so a {number} here would print as a literal brace.
BRIEFING_FIELDS = ["case_number", "subject", "to", "from", "paragraphs", "prologue_note", "closing"]
BRIEFING_TOKENS = {"{statements}"}
briefing_path = os.path.join(base, "resources", "journal", "briefing.json")
briefing = {}
if os.path.exists(briefing_path):
    with open(briefing_path, encoding="utf-8") as fh:
        briefing = json.load(fh)
    for field in BRIEFING_FIELDS:
        if not briefing.get(field):
            errors.append(f"briefing.json: no {field}")
    if not isinstance(briefing.get("paragraphs"), list):
        errors.append("briefing.json: paragraphs must be a list")


    def briefing_walk(obj, where):
        if isinstance(obj, list):
            for i, v in enumerate(obj):
                briefing_walk(v, f"{where}[{i}]")
        elif isinstance(obj, str):
            for token in re.findall(r"\{[^}]*\}", obj):
                if token not in BRIEFING_TOKENS:
                    errors.append(f"briefing.json: {where} carries {token}, which the journal does not expand "
                                  f"(only {', '.join(sorted(BRIEFING_TOKENS))})")
            if "[" in obj or "]" in obj:
                errors.append(f"briefing.json: {where} carries markup - the journal applies all styling")


    for field in BRIEFING_FIELDS:
        briefing_walk(briefing.get(field, ""), field)
    print(f"briefing.json: {len(briefing.get('paragraphs', []))} paragraphs")
else:
    errors.append("briefing.json: missing - the case journal's first tab reads it")

# --- The objectives ----------------------------------------------------------
# The journal's list of what to do next. Each objective completes (and may
# unlock or fail) on conditions from a closed vocabulary read off SessionState;
# every id a condition names must exist, or the objective can never move and
# the player is steered at a wall. Milestone titles are collected from the case
# files and from the string literals of the exploration scripts, which is where
# the street stops and the office stations declare theirs.
CONDITION_KEYS = {"any", "statements_at_least", "credibility_at_least", "interviewed",
                  "flag", "evidence", "milestone"}
OBJECTIVE_FIELDS = {"id", "title", "detail", "unlock_when", "complete_when", "failed_when", "failed_detail"}
person_ids = {data.get("person", {}).get("person_id", "") for data in parsed.values()}
session_flags = set()
statement_budget = None
if os.path.exists(session_state_path := os.path.join(base, "scripts", "autoload", "session_state.gd")):
    with open(session_state_path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"var (\w+): bool", line.strip())
            if m:
                session_flags.add(m.group(1))
            m = re.match(r"const STATEMENT_BUDGET := (\d+)", line.strip())
            if m:
                statement_budget = int(m.group(1))
milestone_titles = set()
for data in parsed.values():
    for node in data.get("nodes", {}).values():
        for holder in (node, node.get("tactic_quiz", {})):
            title = (holder.get("milestone") or {}).get("title", "")
            if title:
                milestone_titles.add(title)
for rel in glob.glob(os.path.join(base, "scripts", "exploration", "*.gd")):
    with open(rel, encoding="utf-8") as fh:
        for line in fh:
            for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
                milestone_titles.add(literal.replace('\\"', '"'))


def check_condition(cond, where):
    if not isinstance(cond, dict) or len(cond) != 1:
        errors.append(f"objectives.json: {where} must be one condition, {{key: value}}")
        return
    key, value = next(iter(cond.items()))
    if key not in CONDITION_KEYS:
        errors.append(f"objectives.json: {where} uses '{key}', not one of {sorted(CONDITION_KEYS)}")
    elif key == "any":
        if not isinstance(value, list) or not value:
            errors.append(f"objectives.json: {where}.any must be a non-empty list")
        else:
            for i, option in enumerate(value):
                check_condition(option, f"{where}.any[{i}]")
    elif key == "statements_at_least":
        if not isinstance(value, int) or value < 1 or (statement_budget and value > statement_budget):
            errors.append(f"objectives.json: {where} asks for {value} statements of a budget of {statement_budget}")
    elif key == "credibility_at_least":
        if not isinstance(value, int) or not 0 <= value <= 100:
            errors.append(f"objectives.json: {where} credibility {value} is not 0-100")
    elif key == "interviewed" and value not in person_ids:
        errors.append(f"objectives.json: {where} names '{value}', who has no case file")
    elif key == "flag" and value not in session_flags:
        errors.append(f"objectives.json: {where} names flag '{value}', not a bool on SessionState")
    elif key == "evidence" and value not in global_evidence:
        errors.append(f"objectives.json: {where} names evidence '{value}', which nothing grants")
    elif key == "milestone" and value not in milestone_titles:
        errors.append(f"objectives.json: {where} names milestone '{value}', which nothing records")


objectives_path = os.path.join(base, "resources", "journal", "objectives.json")
objectives = []
if os.path.exists(objectives_path):
    with open(objectives_path, encoding="utf-8") as fh:
        objectives = json.load(fh).get("objectives", [])
    seen_objectives = set()
    for i, objective in enumerate(objectives):
        oid = objective.get("id", "")
        where = oid or f"objectives[{i}]"
        if not oid:
            errors.append(f"objectives.json: objectives[{i}] has no id")
        elif oid in seen_objectives:
            errors.append(f"objectives.json: duplicate id '{oid}'")
        seen_objectives.add(oid)
        for field in ("title", "detail", "complete_when"):
            if not objective.get(field):
                errors.append(f"objectives.json: {where} has no {field}")
        for field in objective:
            if field not in OBJECTIVE_FIELDS:
                errors.append(f"objectives.json: {where} carries unknown field '{field}'")
        for field in ("unlock_when", "complete_when", "failed_when"):
            if field in objective:
                check_condition(objective[field], f"{where}.{field}")
        if "failed_detail" in objective and "failed_when" not in objective:
            errors.append(f"objectives.json: {where} has a failed_detail but nothing fails it")
        for field in ("title", "detail", "failed_detail"):
            text = str(objective.get(field, ""))
            if "[" in text or "]" in text:
                errors.append(f"objectives.json: {where}.{field} carries markup - the journal applies all styling")
    if not objectives:
        errors.append("objectives.json: no objectives")
    print(f"objectives.json: {len(objectives)} objectives")
else:
    errors.append("objectives.json: missing - the case journal reads it")

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
    "evelyn_marsh": "interview_case_005.json",
    "lina_reyes": "interview_case_006.json",
    "teodoro_villanueva": "interview_case_007.json",
    "joel_abad": "interview_case_010.json",
    "patricia_lim": "interview_case_008.json",
}

# Mirror of SessionState's closed call vocabulary and its outcome -> disposition
# mapping. The prologue picks a victim's perspective line as
# [outcome, disposition_for_outcome(outcome)], so a gap here is a call the player
# can make that shows no consequence at all - which is exactly how every
# non-payout outcome sat silent, with the lines written for it unreachable.
CALL_OUTCOMES = ["success", "partial", "refused", "hung_up",
                 "escalated", "timeout", "aborted"]
DISPOSITIONS = ["harmed", "resistant", "unfinished"]


def disposition_for_outcome(outcome):
    if outcome in ("success", "partial"):
        return "harmed"
    if outcome in ("refused", "hung_up"):
        return "resistant"
    return "unfinished"


PERSPECTIVE_KEYS = set(CALL_OUTCOMES) | set(DISPOSITIONS)

# --- Prologue call scripts ---------------------------------------------------
# call_content.json is a roster: one script file per victim, in list order. A
# script is shaped like a case file - a `person` block plus a node graph - and
# the graph has three kinds of node: a line the player answers (`choices`), a
# `doubt_check` that routes on the meter and is never shown, and an ending
# (`outcome`) that declares its own payout and consequence. Everything the
# ledger prints and the interview quotes back comes from the ending node, so an
# ending that lies about its outcome breaks the coupling silently.
content_path = os.path.join(base, "resources", "dialogue", "call_content.json")
with open(content_path, encoding="utf-8") as fh:
    roster = json.load(fh).get("calls", [])

if not roster:
    errors.append("call_content.json: the roster names no call scripts")

CHOICE_BUTTONS = 4
PAYING_OUTCOMES = {"success", "partial"}
REPORTING_OUTCOMES = {"refused", "hung_up"}

victims = []
for res_path in roster:
    rel = res_path.replace("res://", "").replace("/", os.sep)
    script_path = os.path.join(base, rel)
    sname = os.path.basename(script_path)
    if not os.path.exists(script_path):
        errors.append(f"call_content.json: roster names a missing script '{res_path}'")
        continue
    with open(script_path, encoding="utf-8") as fh:
        script = json.load(fh)
    # Flatten the way the engine does, so the identity checks below read one
    # dictionary per victim.
    flat = dict(script.get("person", {}))
    flat["perspective_variants"] = script.get("perspective_variants", {})
    flat["_file"] = sname
    victims.append(flat)

    person = script.get("person", {})
    for field in ("person_id", "name", "age", "occupation", "portrait", "script", "patience_seconds", "doubt_start"):
        if field not in person:
            errors.append(f"{sname}: person block has no '{field}'")
    ds = person.get("doubt_start", 0)
    if not isinstance(ds, int) or not 0 <= ds < 100:
        errors.append(f"{sname}: doubt_start must be 0-99 (got {ds!r}) - 100 hangs up before a word is said")

    nodes = script.get("nodes", {})
    ids = set(nodes.keys())

    def scheck(target, where):
        if not target:
            errors.append(f"{sname}: EMPTY target at {where}")
        elif target not in ids:
            errors.append(f"{sname}: '{target}' -> missing node (at {where})")

    scheck(script.get("start_node"), "start_node")
    hang_up = script.get("hang_up_node")
    scheck(hang_up, "hang_up_node")
    if hang_up in nodes and nodes[hang_up].get("outcome") != "hung_up":
        errors.append(f"{sname}: hang_up_node '{hang_up}' must be an ending with outcome 'hung_up'")

    for nid, node in nodes.items():
        kinds = [k for k in ("choices", "doubt_check", "outcome") if node.get(k)]
        if len(kinds) != 1:
            errors.append(f"{sname}: {nid} must be exactly one of a line (choices), a doubt_check"
                          f" or an ending (outcome) - has {kinds or 'none'}")
        for text_field in ("prompt", "consequence"):
            if "[color" in str(node.get(text_field, "")) or "[font" in str(node.get(text_field, "")):
                errors.append(f"{sname}: {nid}.{text_field} carries markup - the engine styles call text")

        choices = node.get("choices", [])
        if len(choices) > CHOICE_BUTTONS:
            errors.append(f"{sname}: {nid} has >{CHOICE_BUTTONS} choices (UI has {CHOICE_BUTTONS} buttons)")
        if choices and not node.get("prompt"):
            errors.append(f"{sname}: {nid} offers choices with no prompt to answer")
        for i, c in enumerate(choices):
            scheck(c.get("next"), f"{nid}.choices[{i}]")
            if not c.get("text"):
                errors.append(f"{sname}: {nid}.choices[{i}] has no text")
            if '"' in str(c.get("text", "")):
                errors.append(f"{sname}: {nid}.choices[{i}] contains a double quote - the engine quotes the player's line")
            if not isinstance(c.get("doubt", 0), int):
                errors.append(f"{sname}: {nid}.choices[{i}] doubt must be an integer")
            tid = c.get("tactic_id")
            if tid and tid not in catalogue_ids:
                errors.append(f"{sname}: {nid}.choices[{i}] tactic_id '{tid}' is not in the catalogue")

        dc = node.get("doubt_check")
        if dc:
            scheck(dc.get("next_if_calm"), f"{nid}.doubt_check.next_if_calm")
            scheck(dc.get("next_if_wary"), f"{nid}.doubt_check.next_if_wary")
            md = dc.get("max_doubt")
            if not isinstance(md, int) or not 0 < md < 100:
                errors.append(f"{sname}: {nid}.doubt_check.max_doubt must be 1-99 (got {md!r})")
            if node.get("prompt"):
                errors.append(f"{sname}: {nid} is a doubt_check but has a prompt - checks are never shown")

        outcome = node.get("outcome")
        if outcome:
            if outcome not in CALL_OUTCOMES:
                errors.append(f"{sname}: {nid} outcome '{outcome}' is not in the call vocabulary")
            if not node.get("prompt"):
                errors.append(f"{sname}: ending {nid} has no prompt - the call would close on nothing")
            if not node.get("consequence"):
                errors.append(f"{sname}: ending {nid} has no consequence - the interview would quote nothing")
            payout = node.get("payout", 0)
            if outcome in PAYING_OUTCOMES and not (isinstance(payout, int) and payout > 0):
                errors.append(f"{sname}: ending {nid} is '{outcome}' but declares no payout")
            if outcome not in PAYING_OUTCOMES and payout:
                errors.append(f"{sname}: ending {nid} is '{outcome}' but declares a payout of {payout}")
            if node.get("reports") and outcome not in REPORTING_OUTCOMES:
                errors.append(f"{sname}: ending {nid} reports the number on a '{outcome}' - only a"
                              f" victim who caught on ({'/'.join(sorted(REPORTING_OUTCOMES))}) does")

    # Reachability. The hang-up node is entered by the engine at the doubt
    # ceiling, so it is a root, not something a choice has to point at.
    seen, stack = set(), [script.get("start_node"), hang_up]
    while stack:
        n = stack.pop()
        if not n or n in seen or n not in nodes:
            continue
        seen.add(n)
        node = nodes[n]
        for c in node.get("choices", []):
            stack.append(c.get("next"))
        dc = node.get("doubt_check", {})
        stack.extend([dc.get("next_if_calm"), dc.get("next_if_wary")])
    for nid in sorted(ids - seen):
        errors.append(f"{sname}: {nid} is unreachable")
    outcomes_reached = {nodes[n].get("outcome") for n in seen if nodes[n].get("outcome")}
    if "success" not in outcomes_reached:
        errors.append(f"{sname}: no reachable ending pays out - the script cannot be won")
    if not (outcomes_reached & REPORTING_OUTCOMES):
        errors.append(f"{sname}: no reachable ending refuses - the script cannot be lost")
    if not any(nodes[n].get("reports") for n in seen if nodes[n].get("outcome")):
        errors.append(f"{sname}: no reachable ending reports the number - this victim can never add to the line's reports")
    print(f"{sname}: {len(nodes)} nodes, endings {sorted(outcomes_reached)}")

prologue_ids = {}
for v in victims:
    vid = v.get("person_id", "")
    vname = v.get("name", "?")
    if not vid:
        errors.append(f"{v['_file']}: victim '{vname}' has no person_id")
    elif vid in prologue_ids:
        errors.append(f"{v['_file']}: duplicate person_id '{vid}'"
                      f" ({prologue_ids[vid]} and {vname})")
    else:
        prologue_ids[vid] = vname

    pv = v.get("perspective_variants", {})
    if not isinstance(pv, dict) or not pv:
        errors.append(f"{v['_file']}: victim '{vname}' has no perspective_variants,"
                      f" so a call the engine has to force closed shows no consequence")
        continue
    for key, quotes in pv.items():
        if key not in PERSPECTIVE_KEYS:
            errors.append(f"{v['_file']}: {vname} perspective_variants key '{key}' is"
                          f" neither a call outcome nor a disposition - nothing reads it")
        elif not isinstance(quotes, list) or not [q for q in quotes if str(q).strip()]:
            errors.append(f"{v['_file']}: {vname} perspective_variants['{key}'] is empty")
    for outcome in CALL_OUTCOMES:
        fallback = disposition_for_outcome(outcome)
        if not (pv.get(outcome) or pv.get(fallback)):
            errors.append(f"{v['_file']}: {vname} has no perspective line for a"
                          f" '{outcome}' call - add '{outcome}' or '{fallback}'")

case_ids = {os.path.basename(f): d.get("person", {}).get("person_id", "")
            for f, d in parsed.items()}

for pid, case_file in EXPECTED_LINKS.items():
    if pid not in prologue_ids:
        errors.append(f"call_content.json: expected a victim with person_id '{pid}'")
    if case_ids.get(case_file) != pid:
        errors.append(f"{case_file}: person_id is '{case_ids.get(case_file)}',"
                      f" expected '{pid}' to match the prologue victim")

# Age is the other half of identity. Evelyn was 58 in her case file and 74 in
# the prologue for a whole build, and nothing read both numbers side by side;
# an artist briefed from one file would have painted the wrong person.
case_ages = {os.path.basename(f): (d.get("person", {}).get("name", "?"),
                                   d.get("person", {}).get("age"))
             for f, d in parsed.items()}
prologue_ages = {v.get("person_id", ""): (v.get("name", "?"), v.get("age"))
                 for v in victims}

for pid, case_file in EXPECTED_LINKS.items():
    if case_file not in case_ages or pid not in prologue_ages:
        continue
    case_name, case_age = case_ages[case_file]
    pro_name, pro_age = prologue_ages[pid]
    if case_age != pro_age:
        errors.append(
            f"{case_file}: {case_name} is {case_age} but the prologue has"
            f" {pro_name} at {pro_age} - the same person ages between the two halves")

# Occupation is the third half. Evelyn was a retired bookkeeper in her interview
# ("thirty years telling other people to check their figures") and a retired
# seamstress on the prologue's call card, and both strings are shown to the
# player under her name. One string per person, compared verbatim - two
# phrasings of the same job are still two things to keep in step.
case_jobs = {os.path.basename(f): (d.get("person", {}).get("name", "?"),
                                   d.get("person", {}).get("occupation"))
             for f, d in parsed.items()}
prologue_jobs = {v.get("person_id", ""): (v.get("name", "?"), v.get("occupation"))
                 for v in victims}

for pid, case_file in EXPECTED_LINKS.items():
    if case_file not in case_jobs or pid not in prologue_jobs:
        continue
    case_name, case_job = case_jobs[case_file]
    pro_name, pro_job = prologue_jobs[pid]
    if case_job != pro_job:
        errors.append(
            f"{case_file}: {case_name} is '{case_job}' but the prologue has"
            f" {pro_name} as '{pro_job}' - the same person changes job between the two halves")

for f, data in parsed.items():
    name = os.path.basename(f)
    person = data.get("person", {})
    if person.get("role") != "Victim":
        if "script" in person:
            errors.append(f"{name}: only a victim's case carries `script` - a suspect answers for scripts, not one")
        continue
    sid = person.get("script")
    if not sid:
        errors.append(f"{name}: a victim's case must say which script hit them (`person.script`)")
    elif sid not in SCRIPT_IDS:
        errors.append(f"{name}: script '{sid}' is not one of {sorted(SCRIPT_IDS)}")

for v in victims:
    sid = v.get("script_id")
    if not sid:
        errors.append(f"{v.get('person_id', '?')}: call script must carry `script_id`")
    elif sid not in SCRIPT_IDS:
        errors.append(f"{v.get('person_id', '?')}: script_id '{sid}' is not one of {sorted(SCRIPT_IDS)}")

case_scripts = {os.path.basename(f): (d.get("person", {}).get("name", "?"),
                                      d.get("person", {}).get("script"))
                for f, d in parsed.items()}
prologue_scripts = {v.get("person_id", ""): (v.get("name", "?"), v.get("script_id"))
                    for v in victims}
for pid, case_file in EXPECTED_LINKS.items():
    if case_file not in case_scripts or pid not in prologue_scripts:
        continue
    case_name, case_sid = case_scripts[case_file]
    pro_name, pro_sid = prologue_scripts[pid]
    if case_sid != pro_sid:
        errors.append(
            f"{case_file}: {case_name} was hit by '{case_sid}' but the prologue runs"
            f" '{pro_sid}' on {pro_name} - the same person is scammed two different ways")

# Portraits. Two rules, both of them learned from shipped bugs.
#
# 1. A character has ONE face. Evelyn was drawn as lady 2 in her interview and
#    lady 1 in the prologue, and Lina was the exact reverse - so calling someone
#    as the scammer and then interviewing them as the detective showed two
#    different people, and nothing anywhere caught it.
# 2. No victim wears an antagonist's face. Evelyn, the entry witness, shared a
#    portrait with Elena, so the director of the operation looked like the first
#    person the player helped - at the confrontation the whole game builds to.
#
# There are only four portraits for ten characters, so victims sharing with each
# other is expected and deliberate; these two cases are not.
case_portraits = {}
for f, d in parsed.items():
    person = d.get("person", {})
    case_portraits[os.path.basename(f)] = (person.get("name", "?"),
                                           person.get("role", ""),
                                           person.get("portrait", ""))

prologue_portraits = {v.get("person_id", ""): (v.get("name", "?"), v.get("portrait", ""))
                      for v in victims}

for pid, case_file in EXPECTED_LINKS.items():
    if case_file not in case_portraits or pid not in prologue_portraits:
        continue
    case_name, _role, case_portrait = case_portraits[case_file]
    pro_name, pro_portrait = prologue_portraits[pid]
    if case_portrait != pro_portrait:
        errors.append(
            f"{case_file}: {case_name} is drawn as"
            f" '{os.path.basename(case_portrait)}' but the prologue draws"
            f" {pro_name} as '{os.path.basename(pro_portrait)}' - the same person"
            f" changes face between the two halves")

suspect_faces = {portrait: name
                 for name, role, portrait in case_portraits.values()
                 if role == "Suspect" and portrait}
for name, role, portrait in case_portraits.values():
    if role != "Suspect" and portrait in suspect_faces:
        errors.append(
            f"{name} shares a portrait with {suspect_faces[portrait]}, who is a"
            f" suspect - a victim must not wear an antagonist's face")

unique_faces = sorted({os.path.basename(p) for _n, _r, p in case_portraits.values() if p})
print(f"portraits: {len(unique_faces)} in use across {len(case_portraits)} cases"
      f" ({', '.join(unique_faces)})")

linked = sorted(pid for pid in EXPECTED_LINKS if pid in prologue_ids
                and case_ids.get(EXPECTED_LINKS[pid]) == pid)
print(f"call_content.json: {len(prologue_ids)} call scripts, "
      f"{len(linked)} linked to an interview ({', '.join(linked) if linked else 'none'})")

# --- Coverage: routing must leave nobody stranded ----------------------------
# A testimony is a granted item; it carries the script of the victim it came
# from (the granting case's `person.script`, or its own `script` when the case
# is not a victim's). Four things must hold once suspects accept by script:
#   1. every testimony is accepted by someone - a witness nobody can use is
#      decorative, which is the bug `min_matching` was introduced to kill;
#   2. every suspect can be cracked by something that exists;
#   3. every script-based check can actually be met by the testimonies written;
#   4. every suspect has a witness gated at or below the starting 50, so a
#      player who fails early still has a way into every floor.
# And a suspect who names a witness by id must answer for that witness's
# script, or he is reacting by name to a floor he supposedly knows nothing of.
testimonies = {}
for f, data in parsed.items():
    name = os.path.basename(f)
    person = data.get("person", {})
    for nid, node in data.get("nodes", {}).items():
        for variant in [node] + list(node.get("dispositions", {}).values()):
            for g in variant.get("grants_evidence", []):
                if not str(g.get("id", "")).startswith("test_"):
                    continue  # a granted document (the owner's name) is evidence, not testimony
                script = g.get("script") or person.get("script")
                if not script:
                    errors.append(f"{name}: {nid} grants '{g.get('id')}' with no script - a case that is not a"
                                  f" victim's must tag the item itself")
                    continue
                if script not in SCRIPT_IDS:
                    errors.append(f"{name}: {nid} grants '{g.get('id')}' tagged '{script}', not one of {sorted(SCRIPT_IDS)}")
                    continue
                testimonies[g["id"]] = {"script": script, "case": name,
                                        "gate": int(person.get("min_credibility") or 0)}


def accepted_by(data):
    """(named ids, script sets) this case answers - its non-decoy rows across
    every variant, and its evidence checks, which is how a confrontation
    (Elena) uses testimony without ever being shown it."""
    named, sets = set(), []
    for node in data.get("nodes", {}).values():
        for variant in [node] + list(node.get("dispositions", {}).values()):
            for e in variant.get("accepts_evidence", []):
                if e.get("wrong"):
                    continue
                if "evidence_id" in e:
                    named.add(e["evidence_id"])
                elif "accepts_scripts" in e:
                    sets.append(e["accepts_scripts"])
        ec = node.get("evidence_check", {})
        named.update(ec.get("required_evidence", []))
        if isinstance(ec.get("required_scripts"), list):
            sets.append(ec["required_scripts"])
    return named, sets


acceptance = {os.path.basename(f): accepted_by(d) for f, d in parsed.items()}

for tid, t in testimonies.items():
    takers = [n for n, (named, sets) in acceptance.items()
              if tid in named or any(set_covers(ss, t["script"]) for ss in sets)]
    if not takers:
        errors.append(f"{t['case']}: testimony '{tid}' ({t['script']}) is accepted by nobody"
                      f" - a witness no interview can use is decorative")

for f, data in parsed.items():
    name = os.path.basename(f)
    if data.get("person", {}).get("role") != "Suspect":
        continue
    named, sets = acceptance[name]
    crackers = {tid for tid, t in testimonies.items()
                if tid in named or any(set_covers(ss, t["script"]) for ss in sets)}
    if not crackers:
        errors.append(f"{name}: no testimony that exists can crack this suspect")
    elif not any(testimonies[tid]["gate"] <= 50 for tid in crackers):
        errors.append(f"{name}: every witness who can crack this suspect is gated above the starting 50"
                      f" - a player who fails early has no way in ({sorted(crackers)})")
    for nid, node in data.get("nodes", {}).items():
        for variant in [node] + list(node.get("dispositions", {}).values()):
            rows = variant.get("accepts_evidence", [])
            node_sets = [e["accepts_scripts"] for e in rows if "accepts_scripts" in e]
            if not node_sets:
                continue
            for e in rows:
                tid = e.get("evidence_id")
                if tid in testimonies and not e.get("wrong") and \
                        not any(set_covers(ss, testimonies[tid]["script"]) for ss in node_sets):
                    errors.append(f"{name}: {nid} names '{tid}' ({testimonies[tid]['script']}) but its script"
                                  f" rows answer for {node_sets} - a suspect reacting by name to a floor he"
                                  f" does not answer for")
        ec = node.get("evidence_check", {})
        if "required_scripts" in ec and isinstance(ec.get("min_matching"), int):
            available = sum(1 for t in testimonies.values() if set_covers(ec["required_scripts"], t["script"]))
            if available < ec["min_matching"]:
                errors.append(f"{name}: {nid}.evidence_check asks for {ec['min_matching']} testimonies from"
                              f" {ec['required_scripts']} but only {available} exist")
        if "required_scripts" in ec and isinstance(ec.get("min_distinct_scripts"), int):
            scripts_available = {t["script"] for t in testimonies.values() if set_covers(ec["required_scripts"], t["script"])}
            if len(scripts_available) < ec["min_distinct_scripts"]:
                errors.append(f"{name}: {nid}.evidence_check asks for {ec['min_distinct_scripts']} distinct scripts from"
                              f" {ec['required_scripts']} but witnesses only cover {sorted(scripts_available)}")


# --- Prose lint: the interview must not contradict the prologue --------------
# The engine varies a case per disposition node by node, and the checks above
# make sure every override's targets resolve. What nothing checked is the prose:
# an override forgotten on one node leaves "she lost nothing" standing in front
# of a player who took her money, which is exactly how Evelyn read for a build
# and was fixed by hand. This scans the text a player would actually see under
# each disposition for phrases that assert the opposite of it.
#
# It is a blunt instrument on purpose. A false positive costs a review and an
# entry in the case's `lint_allow` (substrings to ignore); a miss is the bug.
# A case can add its own phrases under `lint_forbid` {disposition: [regex]}.
# Neutral is never linted: it is the case exactly as written, and its premise
# is whatever the writer chose.

LINT_FORBID = {
    # Money was taken from this person. Nothing may say it was not.
    "harmed": [
        r"\blost nothing\b",
        r"\b(didn't|did not|never|hadn't|had not)( even)? pa(y|id)\b",
        r"\bnothing (was|had been) taken\b",
        r"\bno transaction\b",
        r"\bno loss to report\b",
        r"\brefused the call\b",
        r"\b(she|he) (refused|hung up)\b",
        r"\bhung up on (you|him|her|them)\b",
        r"\bnot a (penny|peso|cent)\b",
        r"\bkept (her|his) money\b",
    ],
    # Refused the call, unharmed. Nothing may say money moved.
    "resistant": [
        r"\b(she|he) paid\b",
        r"\btook (her|his|their) money\b",
        r"\btook money from\b",
        r"\bthe transfer\b",
        r"\btransferred\b",
        r"\b(sent|wired) (the |her |his )?money\b",
        r"\bmoney (she|he) sent\b",
        r"\blost (her|his|the|their) (savings|money|deposit)\b",
    ],
    # The call never resolved. Nothing may say money moved, or that they refused.
    "unfinished": [
        r"\b(she|he) paid\b",
        r"\btook (her|his|their) money\b",
        r"\btook money from\b",
        r"\bthe transfer\b",
        r"\btransferred\b",
        r"\b(sent|wired) (the |her |his )?money\b",
        r"\bmoney (she|he) sent\b",
        r"\blost (her|his|the|their) (savings|money|deposit)\b",
        r"\brefused the call\b",
        r"\b(she|he) refused\b",
        r"\bhung up on (you|him|her|them)\b",
    ],
}
LINT_WHY = {
    "harmed": "the player took money from this person",
    "resistant": "this person refused and lost nothing",
    "unfinished": "this call was never resolved",
}


def lint_texts(node, disposition):
    """Every string a player can read on this node under this disposition."""
    resolved = dict(node)
    resolved.update(node.get("dispositions", {}).get(disposition, {}))
    if "tactic_quiz" in node and "tactic_quiz" in node.get("dispositions", {}).get(disposition, {}):
        quiz = dict(node["tactic_quiz"])
        quiz.update(node["dispositions"][disposition]["tactic_quiz"])
        resolved["tactic_quiz"] = quiz
    out = []
    for key in ("prompt", "evidence_hint", "evidence_prompt", "claim"):
        if resolved.get(key):
            out.append((key, resolved[key]))
    for i, c in enumerate(resolved.get("choices", [])):
        if c.get("text"):
            out.append((f"choices[{i}].text", c["text"]))
    for i, e in enumerate(resolved.get("accepts_evidence", [])):
        for key in ("response", "contradiction_note"):
            if e.get(key):
                out.append((f"accepts_evidence[{i}].{key}", e[key]))
    m = resolved.get("milestone", {})
    for key in ("title", "detail"):
        if m.get(key):
            out.append((f"milestone.{key}", m[key]))
    q = resolved.get("tactic_quiz", {})
    for key in ("setup", "question"):
        if q.get(key):
            out.append((f"tactic_quiz.{key}", q[key]))
    for i, o in enumerate(q.get("options", [])):
        for key in ("text", "feedback"):
            if o.get(key):
                out.append((f"tactic_quiz.options[{i}].{key}", o[key]))
    return out


def lint_evidence_texts(item, disposition):
    if "only_for" in item and disposition not in item["only_for"]:
        return []
    override = item.get("dispositions", {}).get(disposition, {})
    if override.get("omit"):
        return []
    resolved = dict(item)
    resolved.update({k: v for k, v in override.items() if k != "omit"})
    return [(key, resolved[key]) for key in ("label", "description", "tactic") if resolved.get(key)]


def lint_scan(name, where, text, disposition, allow, forbid):
    if not isinstance(text, str):
        return  # `evidence_prompt` is a flag on some nodes, not a line
    for pattern in forbid:
        hit = re.search(pattern, text, re.IGNORECASE)
        if not hit:
            continue
        if any(a.lower() in text.lower() for a in allow):
            continue
        errors.append(
            f"{name}: under '{disposition}', {where} says \"{hit.group(0)}\""
            f" - but {LINT_WHY[disposition]}")
        return


# Who granted each testimony, so a suspect's reaction to it can be read under
# the disposition of the person it came from.
testimony_owner = {}
for f, data in parsed.items():
    pid = data.get("person", {}).get("person_id", "")
    for node in data.get("nodes", {}).values():
        for g in node.get("grants_evidence", []):
            testimony_owner[g["id"]] = (os.path.basename(f), pid)
linked_cases = {os.path.basename(f) for f, d in parsed.items() if d.get("person", {}).get("dispositions")}

for f, data in parsed.items():
    name = os.path.basename(f)
    person = data.get("person", {})
    allow = data.get("lint_allow", [])
    extra = data.get("lint_forbid", {})
    if not isinstance(allow, list) or not all(isinstance(a, str) for a in allow):
        errors.append(f"{name}: lint_allow must be a list of strings")
        allow = []
    if not isinstance(extra, dict):
        errors.append(f"{name}: lint_forbid must be an object keyed by disposition")
        extra = {}
    for key in extra:
        if key not in VALID_DISPOSITIONS:
            errors.append(f"{name}: lint_forbid['{key}'] is not a disposition")

    if person.get("dispositions"):
        # A linked victim: everything the player reads, under each outcome.
        for d in sorted(VALID_DISPOSITIONS):
            forbid = LINT_FORBID[d] + list(extra.get(d, []))
            entry = person["dispositions"].get(d, {})
            for key in ("prompt", "note"):
                if entry.get(key):
                    lint_scan(name, f"person.dispositions.{d}.{key}", entry[key], d, allow, forbid)
            for nid, node in data.get("nodes", {}).items():
                for where, text in lint_texts(node, d):
                    lint_scan(name, f"{nid}.{where}", text, d, allow, forbid)
            for i, item in enumerate(data.get("evidence", [])):
                for where, text in lint_evidence_texts(item, d):
                    lint_scan(name, f"evidence[{i}].{where}", text, d, allow, forbid)
    else:
        # A suspect: their reaction to a testimony is read under the disposition
        # of whoever gave it. `responses` is keyed by that; `response` is the
        # line for anyone it does not name.
        for nid, node in data.get("nodes", {}).items():
            variants = [node] + list(node.get("dispositions", {}).values())
            for variant in variants:
                for i, e in enumerate(variant.get("accepts_evidence", [])):
                    if "accepts_scripts" in e:
                        by_source = e.get("responses", {})
                        for d in sorted(VALID_DISPOSITIONS):
                            text = by_source.get(d, e.get("response", ""))
                            if text:
                                lint_scan(name, f"{nid}.accepts_evidence[{i}] (any of {e['accepts_scripts']})",
                                          text, d, allow, LINT_FORBID[d] + list(extra.get(d, [])))
                        continue
                    owner = testimony_owner.get(e.get("evidence_id", ""))
                    if not owner or owner[0] not in linked_cases:
                        continue
                    by_source = e.get("responses", {})
                    for d in sorted(VALID_DISPOSITIONS):
                        text = by_source.get(d, e.get("response", ""))
                        if text:
                            lint_scan(name, f"{nid}.accepts_evidence[{i}] ({e['evidence_id']}, {owner[1]})",
                                      text, d, allow, LINT_FORBID[d] + list(extra.get(d, [])))

# --- One copy of the number, one copy of the name ----------------------------
# SessionState.OPERATION_NUMBER and SessionState.COMPANY_NAME are printed by the
# street, the call floor and now the interviews, and the player is meant to
# notice the repetition unprompted - which only works if there is exactly one
# string. A case file writes {number} or {company} and the engine expands it;
# a case that spells either out is a second copy that will drift.
session_state_path = os.path.join(base, "scripts", "autoload", "session_state.gd")
one_copy = {}
if os.path.exists(session_state_path):
    with open(session_state_path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r'const (OPERATION_NUMBER|COMPANY_NAME) := "([^"]+)"', line.strip())
            if m:
                one_copy[m.group(1)] = m.group(2)


def one_copy_walk(obj, where):
    if isinstance(obj, dict):
        for k, v in obj.items():
            one_copy_walk(v, f"{where}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            one_copy_walk(v, f"{where}[{i}]")
    elif isinstance(obj, str):
        for name, literal in one_copy.items():
            if literal.lower() in obj.lower():
                token = "{number}" if name == "OPERATION_NUMBER" else "{company}"
                errors.append(f"{where} spells out {name} - write {token} and let the engine print the one copy")


for f, data in parsed.items():
    one_copy_walk(data, os.path.basename(f))
for v in victims:
    one_copy_walk(v, f"{v.get('person_id', '?')}.json")
one_copy_walk(briefing, "briefing.json")
one_copy_walk(objectives, "objectives.json")

# --- Register lint: the game is set in the Philippines and reads like it -----
# The first four cases and the terrace's stops were written in British English
# (realise, kerb, noticeboard, perspex) while the setting names barangays,
# pesos and Lolo, and the expansion inherited the register before anyone
# noticed. Player-facing text is Philippine English: American spelling,
# everyday American vocabulary, and the local words where they are the natural
# ones (barangay, sari-sari store, cash-in, remittance, Lolo, the 15th). This
# scans every string a player can read for the British forms that crept in.
# `register_allow` on a case lists substrings to ignore, for the rare line
# where the word is right (a character quoting a sign, a proper noun).
REGISTER_FORBID = [
    # spelling
    (r"\b(real|recogn|organ|apolog|memor|author|minim|maxim|emphas|summar|capital|normal|priorit|special|sympath|util|critic|civil|stabil|scrutin|penal|patron|hospital|final|legal|vocal|mobil|neutral|symbol|equal|formal)i[sz]?(se|sed|ses|sing|sation|sations)\b", "-ize / -ization spelling"),
    (r"\b(analy|paraly)se[sd]?\b", "-yze spelling"),
    (r"\b(col|neighb|behavi|fav|hon|lab|hum|flav|harb|rum|arm|vap|od|sav|end|dem)our\w*", "-or spelling"),
    (r"\b(cent|met|theat|lit|fib|calib)re\b|\b(cent|met|theat|lit|fib)res\b", "-er spelling"),
    (r"\b(licence|defence|offence|pretence)\b", "-se spelling"),
    (r"\bpractis(e|ed|es|ing)\b", "practice (verb, US)"),
    (r"\b(cheque|programme|grey|tyre|kerb|storey|pyjama|aluminium|jewellery|catalogue|cancelled|cancelling|travelled|travelling|modelling|pencilled|marvellous|labelled|labelling|counsellor|learnt|spelt|dreamt|burnt|smelt|whilst|amongst)\w*", "British spelling"),
    # vocabulary
    (r"\bpavements?\b", "sidewalk"),
    (r"\bnotice ?boards?\b", "bulletin board"),
    (r"\bhoardings?\b", "billboard"),
    (r"\bterraces?\b", "row / street (the district is Sampaguita Street)"),
    (r"\bshopkeepers?\b", "store owner"),
    (r"\bqueues?\b|\bqueue[ds]\b|\bqueuing\b", "line / on hold"),
    (r"\bfortnight\w*", "two weeks"),
    (r"\bmums?\b|\bmummy\b", "mom / Nanay"),
    (r"\bperspex\b", "plastic / acrylic"),
    (r"\btimetables?\b", "schedule"),
    (r"\bholidays?\b", "vacation"),
    (r"\blorr(y|ies)\b", "truck"),
    (r"\bbiscuits?\b", "cookie / cracker"),
    (r"\brubbish\b", "trash / garbage"),
    (r"\bcar parks?\b", "parking lot"),
    (r"\bpetrol\b", "gas"),
    (r"\bpostcodes?\b", "zip code"),
    (r"\b(the|a|locked|service|goods) lifts?\b|\blifts? (needs?|to|door|access)\b", "elevator"),
    (r"\ba flat\b(?! (tone|voice|no|refusal))|\bmy flat\b|\bher flat\b|\bhis flat\b|\bthe flat\b(?! (of|on)\b)|\bflat (in|near|above|upstairs)\b", "apartment"),
    (r"\bthe till\b", "the register"),
    (r"\bpost(ed|ing)? (it|the letter|a letter|the form|him|her|them) (to|back|off)\b|\bin the post\b|\bby post\b", "mail"),
    (r"\b(I|we|he|she|they) rang\b|\brang (the|him|her|them|me|it|my|his|her|off|back)\b|\bring (the|him|her|them|me|my|his|back)\b|\brings? (him|her|them|me|you|off)\b", "call / phone (rang -> called)"),
    (r"\btelephoned\b|\btelephoning\b|\bI telephone\b|\bto telephone\b", "phone / call (the verb - the noun is fine)"),
    (r"\bput the (phone|receiver) down\b", "hung up"),
    (r"\bsort(ed|ing)? (it|that|this|the rest) out\b|\bI'll sort\b|\bsort the rest\b", "fix / take care of"),
    (r"\bhi-vis\b", "safety vest / reflective vest"),
    (r"\bmarker pen\b", "marker"),
    (r"\bkettle\b", "coffee / water on the stove (British idiom)"),
    (r"\bmate\b(?<!batch-mate)(?<!batchmate)", "friend / batchmate"),
    (r"\bbatch-mate\b", "batchmate (one word, PH usage)"),
    (r"\bmobile\b(?= (phone|number))", "cellphone / cell number"),
    (r"\bdustbin\b|\bbins?\b(?= (bag|man|men))", "trash can"),
    (r"\bskip\b(?= (at|on|in|behind|by)\b)", "dumpster"),
]

# Where player-facing prose lives outside the JSON: the stop tables and HUD
# strings in the district scripts, the office's stations, the summaries.
REGISTER_SCRIPTS = [
    "scripts/exploration/district_exterior.gd",
    "scripts/exploration/urban_exterior.gd",
    "scripts/exploration/terminal_road.gd",
    "scripts/exploration/office_interior.gd",
    "scripts/autoload/case_journal.gd",
    "scripts/investigation/investigation_end.gd",
    "scripts/investigation/interview.gd",
    "scripts/prologue/prologue_call.gd",
    "scripts/prologue/prologue_end.gd",
    "scripts/autoload/tactic_notebook.gd",
    "scripts/autoload/session_state.gd",
    "scripts/ui/main_menu.gd",
]


def register_scan(where, text, allow):
    if not isinstance(text, str):
        return
    for pattern, suggestion in REGISTER_FORBID:
        for hit in re.finditer(pattern, text, re.IGNORECASE):
            if any(a.lower() in text.lower() for a in allow):
                return
            errors.append(f"{where}: \"{hit.group(0)}\" is not Philippine English - {suggestion}")
            return


def register_walk(obj, where, allow):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ("portrait", "id", "evidence_id", "next", "person_id", "tactic_id", "script", "script_id",
                     "start_node", "hang_up_node", "failure_node", "case_id", "lint_allow", "register_allow"):
                continue
            register_walk(v, f"{where}.{k}", allow)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            register_walk(v, f"{where}[{i}]", allow)
    elif isinstance(obj, str):
        register_scan(where, obj, allow)


for f, data in parsed.items():
    register_walk(data, os.path.basename(f), data.get("register_allow", []))
for v in victims:
    register_walk(v, f"{v.get('person_id', '?')}.json", v.get("register_allow", []))
catalogue_path = os.path.join(base, "resources", "tactics", "tactic_catalogue.json")
if os.path.exists(catalogue_path):
    with open(catalogue_path, encoding="utf-8") as fh:
        register_walk(json.load(fh), "tactic_catalogue.json", [])
register_walk(briefing, "briefing.json", [])
register_walk(objectives, "objectives.json", [])

# String literals only: a British comment is nobody's business but the
# author's, a British line on screen is the game's.
STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
for rel in REGISTER_SCRIPTS:
    path = os.path.join(base, *rel.split("/"))
    if not os.path.exists(path):
        continue
    with open(path, encoding="utf-8") as fh:
        for number, line in enumerate(fh, 1):
            stripped = line.strip()
            if stripped.startswith("#") or "push_error(" in line or "printerr(" in line:
                continue  # comments and developer messages are not the game
            for literal in STRING_LITERAL.findall(line):
                if len(literal) < 12 or "res://" in literal or "%" == literal.strip():
                    continue
                register_scan(f"{rel}:{number}", literal, [])

print()
if errors:
    print("FAILURES:")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("All case graphs valid.")
