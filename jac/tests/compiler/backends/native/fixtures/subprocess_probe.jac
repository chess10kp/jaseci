"""Congruence probe: `import subprocess` must answer what CPython answers.

Runs on the sv pathway (CPython's subprocess) and the na pathway
(na_stdlib/subprocess.jac). Only deterministic, lane-identical lines are
printed; exception messages are not printed because the repr differs.
"""

import subprocess;
import from subprocess {
    PIPE,
    STDOUT,
    DEVNULL,
    run,
    call,
    check_call,
    check_output,
    Popen,
    CompletedProcess,
    CalledProcessError,
    TimeoutExpired
}

with entry {
    cp = run(["echo", "hello"], capture_output=True, text=True);
    o1: str = str(cp.stdout);
    print("rc=" + str(cp.returncode) + " out=" + o1.strip());

    cp2 = run("echo via-shell", shell=True, capture_output=True, text=True);
    o2: str = str(cp2.stdout);
    print("rc2=" + str(cp2.returncode) + " out2=" + o2.strip());

    cp3 = run(
        ["sh", "-c", "echo out; echo err >&2; exit 3"], capture_output=True, text=True
    );
    o3: str = str(cp3.stdout);
    e3: str = str(cp3.stderr);
    print("rc3=" + str(cp3.returncode) + " o3=" + o3.strip() + " e3=" + e3.strip());

    cp4 = run(["cat"], capture_output=True, text=True, input="stdin-data");
    o4: str = str(cp4.stdout);
    print("rc4=" + str(cp4.returncode) + " o4=" + o4.strip());

    cp5 = run(
        ["sh", "-c", "echo o; echo e >&2"], stdout=PIPE, stderr=STDOUT, text=True
    );
    o5: str = str(cp5.stdout);
    print("merge=" + o5.strip().replace("\n", ","));

    cp6 = run(
        "echo $PROBE_V",
        shell=True,
        env={"PROBE_V": "envval"},
        capture_output=True,
        text=True
    );
    o6: str = str(cp6.stdout);
    print("env=" + o6.strip());

    cp7 = run(["pwd"], capture_output=True, text=True, cwd="/tmp");
    o7: str = str(cp7.stdout);
    print("cwd=" + o7.strip());

    cp8 = run(["echo", "gone"], stdout=DEVNULL, stderr=DEVNULL);
    print("devnull rc=" + str(cp8.returncode) + " out-none=" + str(cp8.stdout is None));

    print("call=" + str(call(["true"])));

    out = check_output(["echo", "ck"], text=True);
    os_: str = str(out);
    print("cko=" + os_.strip());

    try {
        check_call(["false"]);
        print("cce-missed");
    } except CalledProcessError {
        print("cce-raised");
    }

    cpok = run(["true"], capture_output=True);
    cpok.check_returncode();
    print("crc-ok");

    try {
        run(["sleep", "30"], timeout=0.2);
        print("te-missed");
    } except TimeoutExpired {
        print("te-raised");
    }

    p = Popen(args=["sleep", "30"]);
    p.terminate();
    prc = p.`wait();
    print("term-rc=" + str(prc));

    p2 = Popen(args=["echo", "popen-out"], stdout=PIPE, text=True);
    (po, pe) = p2.communicate();
    pos: str = str(po);
    print("popen-out=" + pos.strip() + " err-none=" + str(pe is None));

    print("done");
}
