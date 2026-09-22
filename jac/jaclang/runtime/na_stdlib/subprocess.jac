import from _subprocess_native {
    sp_waitpid,
    sp_kill,
    sp_strvec,
    sp_fa_new,
    sp_fa_dup2,
    sp_fa_close,
    sp_fa_open,
    sp_fa_chdir,
    sp_fa_free,
    sp_attr_new,
    sp_attr_free,
    sp_spawn,
    sp_pipe,
    sp_close,
    sp_read,
    sp_write,
    sp_usleep,
    sp_time,
    sp_errno,
    sp_errno_text
}

glob:pub PIPE: int = -1,
     STDOUT: int = -2,
     DEVNULL: int = -3;

glob _WNOHANG: int = 1,
     _SIGKILL: int = 9,
     _SIGTERM: int = 15;

obj:pub SubprocessError(Exception) {}

obj:pub CalledProcessError(SubprocessError) {
    has returncode: int = 0,
        cmd: any = None,
        output: any = None,
        stderr: any = None;
}

obj:pub TimeoutExpired(SubprocessError) {
    has cmd: any = None,
        timeout: any = None,
        output: any = None,
        stderr: any = None;
}

obj:pub CompletedProcess {
    has args: any = None,
        returncode: int = 0,
        stdout: any = None,
        stderr: any = None;

    def check_returncode {
        if self.returncode != 0 {
            raise CalledProcessError(
                returncode=self.returncode,
                cmd=self.args,
                output=self.stdout,
                stderr=self.stderr
            );
        }
    }
}

def _shquote(s: str) -> str {
    if s == "" {
        return "''";
    }
    safe = True;
    for c in s {
        if not (
            (c >= "a" and c <= "z")
            or (c >= "A" and c <= "Z")
            or (c >= "0" and c <= "9")
            or c in "@%_+=:,./-"
        ) {
            safe = False;
        }
    }
    if safe {
        return s;
    }
    return "'" + s.replace("'", "'" + '"' + "'" + '"' + "'") + "'";
}

def _args_to_cmdline(args: (str | list[str])) -> str {
    if isinstance(args, str) {
        return args;
    }
    parts: list[str] = [];
    for a in args {
        parts.append(_shquote(a));
    }
    return " ".join(parts);
}

def _to_bytes(data: any) -> bytes {
    if isinstance(data, bytes) {
        return data;
    }
    if isinstance(data, bytearray) {
        return bytes(data);
    }
    return str(data).encode();
}

def _decode_status(st: int) -> int {
    if (st & 0x7f) == 0 {
        return (st >> 8) & 0xff;
    }
    return -(st & 0x7f);
}

obj:pub Popen {
    has args: (str | list[str]) = "",
        stdin: (int | None) = None,
        stdout: (int | None) = None,
        stderr: (int | None) = None,
        text: bool = False,
        cwd: (str | None) = None,
        env: (dict[str, str] | None) = None,
        shell: bool = False,
        returncode: any = None,
        _pid: int = -1,
        _stdin_w: int = -1,
        _stdout_r: int = -1,
        _stderr_r: int = -1;

    def postinit {
        cmdline = _args_to_cmdline(self.args);
        in_pipe: list[int] = [-1, -1];
        out_pipe: list[int] = [-1, -1];
        err_pipe: list[int] = [-1, -1];
        if self.stdin == PIPE {
            in_pipe = sp_pipe();
        }
        if self.stdout == PIPE {
            out_pipe = sp_pipe();
        }
        if self.stderr == PIPE {
            err_pipe = sp_pipe();
        }
        argv: list[str] = [];
        if self.shell {
            argv = ["/bin/sh", "-c", cmdline];
        } elif isinstance(self.args, str) {
            argv = [self.args];
        } else {
            argv = self.args;
        }
        fa = sp_fa_new();
        at = sp_attr_new(64);
        if in_pipe[0] >= 0 {
            sp_fa_dup2(fa, in_pipe[0], 0);
        } elif self.stdin == DEVNULL {
            sp_fa_open(fa, 0, "/dev/null", 2);
        } elif isinstance(self.stdin, int) and self.stdin >= 0 {
            sp_fa_dup2(fa, self.stdin, 0);
        }
        if out_pipe[1] >= 0 {
            sp_fa_dup2(fa, out_pipe[1], 1);
        } elif self.stdout == DEVNULL {
            sp_fa_open(fa, 1, "/dev/null", 2);
        } elif isinstance(self.stdout, int) and self.stdout >= 0 {
            sp_fa_dup2(fa, self.stdout, 1);
        }
        if err_pipe[1] >= 0 {
            sp_fa_dup2(fa, err_pipe[1], 2);
        } elif self.stderr == STDOUT {
            sp_fa_dup2(fa, 1, 2);
        } elif self.stderr == DEVNULL {
            sp_fa_open(fa, 2, "/dev/null", 2);
        } elif isinstance(self.stderr, int) and self.stderr >= 0 {
            sp_fa_dup2(fa, self.stderr, 2);
        }
        for fd in [
            in_pipe[0],
            in_pipe[1],
            out_pipe[0],
            out_pipe[1],
            err_pipe[0],
            err_pipe[1]
        ] {
            if fd >= 0 {
                sp_fa_close(fa, fd);
            }
        }
        cw = self.cwd;
        if cw is not None {
            sp_fa_chdir(fa, cw);
        }
        envp = 0;
        e = self.env;
        if e is not None {
            envv: list[str] = [];
            for k in e {
                envv.append(k + "=" + e[k]);
            }
            envp = sp_strvec(envv);
        }
        r = sp_spawn(argv[0], fa, at, sp_strvec(argv), envp);
        sp_fa_free(fa);
        sp_attr_free(at);
        if r[0] != 0 {
            for fd in [
                in_pipe[0],
                in_pipe[1],
                out_pipe[0],
                out_pipe[1],
                err_pipe[0],
                err_pipe[1]
            ] {
                if fd >= 0 {
                    sp_close(fd);
                }
            }
            raise OSError("[Errno " + str(r[0]) + "] spawn failed");
        }
        self._pid = r[1];
        if in_pipe[0] >= 0 {
            sp_close(in_pipe[0]);
            self._stdin_w = in_pipe[1];
        }
        if out_pipe[1] >= 0 {
            sp_close(out_pipe[1]);
            self._stdout_r = out_pipe[0];
        }
        if err_pipe[1] >= 0 {
            sp_close(err_pipe[1]);
            self._stderr_r = err_pipe[0];
        }
    }

    def _drain(fd: int) -> bytes {
        acc = bytearray();
        while True {
            chunk = sp_read(fd, 65536);
            if len(chunk) == 0 {
                break;
            }
            acc.extend(chunk);
        }
        return bytes(acc);
    }

    def _render(data: bytes) -> any {
        if self.text {
            return data.decode();
        }
        return data;
    }

    def poll -> any {
        if self.returncode is not None {
            return self.returncode;
        }
        if self._pid < 0 {
            return None;
        }
        r = sp_waitpid(self._pid, _WNOHANG);
        if r[0] == self._pid {
            self.returncode = _decode_status(r[1]);
        }
        return self.returncode;
    }

    def `wait(timeout: any = None) -> int {
        deadline = -1;
        if isinstance(timeout, int) {
            deadline = sp_time() + timeout + 1;
        } elif isinstance(timeout, float) {
            deadline = sp_time() + int(timeout) + 1;
        }
        if deadline < 0 {
            r = sp_waitpid(self._pid, 0);
            if r[0] == self._pid {
                self.returncode = _decode_status(r[1]);
            }
            rc = self.returncode;
            if isinstance(rc, int) {
                return rc;
            }
        }
        while True {
            rc = self.poll();
            if isinstance(rc, int) {
                return rc;
            }
            if deadline >= 0 and sp_time() >= deadline {
                self.kill();
                self.poll();
                raise TimeoutExpired(cmd=self.args, timeout=timeout);
            }
            sp_usleep(2000);
        }
    }

    def communicate(input: any = None, timeout: any = None) -> tuple[(any, any)] {
        if input is not None and self._stdin_w >= 0 {
            data = _to_bytes(input);
            off = 0;
            while off < len(data) {
                n = sp_write(self._stdin_w, data[off:]);
                if n <= 0 {
                    break;
                }
                off += n;
            }
        }
        if self._stdin_w >= 0 {
            sp_close(self._stdin_w);
            self._stdin_w = -1;
        }
        out_v: any = None;
        err_v: any = None;
        if self._stdout_r >= 0 {
            out_v = self._render(self._drain(self._stdout_r));
            sp_close(self._stdout_r);
            self._stdout_r = -1;
        }
        if self._stderr_r >= 0 {
            err_v = self._render(self._drain(self._stderr_r));
            sp_close(self._stderr_r);
            self._stderr_r = -1;
        }
        self.`wait(timeout);
        return (out_v, err_v);
    }

    def kill {
        if self._pid >= 0 and self.returncode is None {
            sp_kill(self._pid, _SIGKILL);
            sp_kill(-self._pid, _SIGKILL);
        }
    }

    def terminate {
        if self._pid >= 0 and self.returncode is None {
            sp_kill(self._pid, _SIGTERM);
            sp_kill(-self._pid, _SIGTERM);
        }
    }
}

def:pub run(
    args: (str | list[str]),
    capture_output: bool = False,
    text: bool = False,
    check: bool = False,
    input: any = None,
    timeout: any = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False,
    stdin: (int | None) = None,
    stdout: (int | None) = None,
    stderr: (int | None) = None
) -> CompletedProcess {
    if input is not None and stdin is None {
        stdin = PIPE;
    }
    if capture_output {
        if stdout is None {
            stdout = PIPE;
        }
        if stderr is None {
            stderr = PIPE;
        }
    }
    p = Popen(
        args=args,
        stdin=stdin,
        stdout=stdout,
        stderr=stderr,
        text=text,
        cwd=cwd,
        env=env,
        shell=shell
    );
    (o, e) = p.communicate(input, timeout);
    prc = p.returncode;
    if not isinstance(prc, int) {
        prc = -1;
    }
    cp = CompletedProcess(args=args, returncode=prc, stdout=o, stderr=e);
    if check {
        cp.check_returncode();
    }
    return cp;
}

def:pub call(
    args: (str | list[str]),
    timeout: any = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int {
    cp = run(args, timeout=timeout, cwd=cwd, env=env, shell=shell);
    return cp.returncode;
}

def:pub check_call(
    args: (str | list[str]),
    timeout: any = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> int {
    cp = run(args, timeout=timeout, cwd=cwd, env=env, shell=shell, check=True);
    return cp.returncode;
}

def:pub check_output(
    args: (str | list[str]),
    text: bool = False,
    timeout: any = None,
    cwd: (str | None) = None,
    env: (dict[str, str] | None) = None,
    shell: bool = False
) -> any {
    cp = run(
        args,
        capture_output=True,
        text=text,
        check=True,
        timeout=timeout,
        cwd=cwd,
        env=env,
        shell=shell
    );
    return cp.stdout;
}
