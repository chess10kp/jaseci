import configparser
import csv
import json
import time
import tomllib


def build_json():
    doc = '{"name": "widget-batch", "id": 4271, "active": true, "ratio": 0.7284, "tag": null, "tags": ["alpha", "beta", "gamma"], "meta": {"src": "bench", "deep": [1, 2, 3, 4, 5], "ok": false}, "orders": ['
    for i in range(20):
        if i > 0:
            doc += ", "
        doc += '{"oid": ' + str(1000 + i) + ', "sku": "SKU-' + str(i) + '", "qty": ' + str((i * 7) % 13) + ', "price": ' + str(1.5 + i) + ', "note": "line ' + str(i) + '"}'
    return doc + "]}"


def build_csv():
    lines = ["sku,qty,price,note"]
    for i in range(200):
        if i % 3 == 0:
            lines.append(str(i) + ',"' + str(i * 2) + ',x","' + str(1.5 + i) + '","say ""hi"" ' + str(i) + '"')
        else:
            lines.append(str(i) + "," + str(i * 2) + "," + str(1.5 + i) + ",plain" + str(i))
    return "\n".join(lines)


def build_toml():
    doc = 'title = "bench"\nrun_at = 2026-09-25T10:30:00Z\nlimit = 4_000\nratio = 0.7284\nports = [80, 443, 8080]\n[owner]\nname = "ops"\ndob = 1979-05-27\n[server]\nenabled = true\nip = "10.0.0.1"\n[server.tls]\nkey = "k.pem"\ncert = "c.pem"\n'
    for i in range(20):
        doc += "[[items]]\nid = " + str(i) + "\nname = \"item-" + str(i) + '\"\nvec = [' + str(i) + ", " + str(i + 1) + ", " + str(i + 2) + "]\n"
    return doc


def build_ini():
    doc = "[DEFAULT]\nbase = 100\nname = bench\n"
    for i in range(40):
        doc += "[s" + str(i) + "]\nnum = " + str(i) + "\nref = %(base)s\nlabel = sec-" + str(i) + "\n"
    return doc


def count_all(v):
    acc = 0
    if isinstance(v, dict):
        for k in v:
            acc += 1 + count_all(v[k])
    elif isinstance(v, list):
        for e in v:
            acc += 1 + count_all(e)
    elif isinstance(v, str):
        acc += len(v)
    return acc


def json_lane(reps, doc):
    acc = 0
    t0 = time.monotonic_ns()
    for _ in range(reps):
        v = json.loads(doc)
        acc += count_all(v)
        acc += len(json.dumps(v))
    return acc, time.monotonic_ns() - t0


def scan_lane(reps, doc):
    acc = 0
    t0 = time.monotonic_ns()
    for _ in range(reps):
        for ch in doc:
            if ch == '"' or ch == "\\":
                acc += 1
    return acc, time.monotonic_ns() - t0


def slice_lane(reps, doc):
    acc = 0
    t0 = time.monotonic_ns()
    for _ in range(reps):
        out = ""
        i = 0
        start = 0
        n = len(doc)
        while i < n:
            ch = doc[i]
            if ch == '"' or ch == "\\":
                out += doc[start:i] + "|"
                i += 1
                start = i
            else:
                i += 1
        out += doc[start:n]
        acc += len(out)
    return acc, time.monotonic_ns() - t0


def csv_lane(reps, doc):
    acc = 0
    lines = doc.split("\n")
    t0 = time.monotonic_ns()
    for _ in range(reps):
        rows = list(csv.reader(lines))
        for row in rows:
            acc += len(row)
    return acc, time.monotonic_ns() - t0


def toml_lane(reps, doc):
    acc = 0
    t0 = time.monotonic_ns()
    for _ in range(reps):
        v = tomllib.loads(doc)
        acc += count_all(v)
    return acc, time.monotonic_ns() - t0


def ini_lane(reps, doc):
    acc = 0
    t0 = time.monotonic_ns()
    for _ in range(reps):
        cp = configparser.ConfigParser()
        cp.read_string(doc)
        acc += len(cp.sections())
        acc += cp.getint("s17", "num")
        acc += len(cp.get("s17", "ref"))
        acc += len(cp.get("s17", "label"))
    return acc, time.monotonic_ns() - t0


def best(lane, reps, doc):
    bt = -1
    bacc = 0
    for k in range(4):
        acc, el = lane(reps, doc)
        if k > 0 and (bt < 0 or el < bt):
            bt, bacc = el, acc
    return bacc, bt


def main():
    jd, cd, td, idoc = build_json(), build_csv(), build_toml(), build_ini()
    print("doclens", len(jd), len(cd), len(td), len(idoc))
    for lane, reps, doc, name in (
        (json_lane, 4000, jd, "json"),
        (csv_lane, 500, cd, "csv"),
        (toml_lane, 4000, td, "toml"),
        (ini_lane, 4000, idoc, "configparser"),
        (scan_lane, 2000, jd, "scan"),
        (slice_lane, 2000, jd, "slice"),
    ):
        acc, el = best(lane, reps, doc)
        print(name, el / reps, str(acc))


if __name__ == "__main__":
    main()
