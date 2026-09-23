import os;
import from urllib.parse {
    splittype,
    splithost,
    splituser,
    splitpasswd,
    splitport,
    splittag,
    splitattr,
    splitvalue,
    unwrap,
    quote,
    unquote,
    unquote_to_bytes,
    urlsplit,
    urlparse,
    urlunparse,
    urljoin
}
import from urllib.error { URLError, HTTPError, ContentTooShortError }
import from urllib.response { addinfourl, addclosehook }
import from socket { create_connection }
import from _socket_native { resolve_all }
import from ssl { create_default_context }
import from io { BytesIO }
import from base64 { b64encode, b64decode }
import from _file_native { read_file_bytes, write_file_bytes }


obj:pub Headers {
    has:pub names: list[str] = [],
        values: list[str] = [];

    def add(name: str, value: str) {
        self.names.append(name);
        self.values.append(value);
    }

    def contains(name: str) -> bool {
        target = name.lower();
        for n in self.names {
            if n.lower() == target {
                return True;
            }
        }
        return False;
    }

    def get(name: str, failobj: any = None) -> any {
        target = name.lower();
        i = 0;
        while i < len(self.names) {
            if self.names[i].lower() == target {
                return self.values[i];
            }
            i += 1;
        }
        return failobj;
    }

    def get_all(name: str) -> list[str] {
        target = name.lower();
        out: list[str] = [];
        i = 0;
        while i < len(self.names) {
            if self.names[i].lower() == target {
                out.append(self.values[i]);
            }
            i += 1;
        }
        return out;
    }

    def items -> list[tuple[(str, str)]] {
        out: list[tuple[(str, str)]] = [];
        i = 0;
        while i < len(self.names) {
            out.append((self.names[i], self.values[i]));
            i += 1;
        }
        return out;
    }
}


def _parse_headers(text: str) -> Headers {
    h = Headers();
    for line in text.split("\r\n") {
        colon = line.find(":");
        if colon != -1 {
            h.add(line[:colon].strip(), line[colon + 1:].strip());
        }
    }
    return h;
}


def:pub request_host(request: Request) -> str {
    url = request.full_url;
    parts = urlsplit(url);
    host = parts.netloc;
    if len(host) == 0 {
        v = request.get_header("Host", "");
        if isinstance(v, str) {
            host = v;
        }
    }

    colon = host.rfind(":");
    if colon != -1 {
        tail = host[colon + 1:];
        digits = len(tail) > 0;
        for ch in tail {
            if not ch.isdigit() {
                digits = False;
            }
        }
        if digits {
            host = host[:colon];
        }
    }
    return host.lower();
}


obj:pub Request {
    has:pub _full_url: str = "",
        fragment: str = "",
        data: any = None,
        headers: dict[str, str] = {},
        unredirected_hdrs: dict[str, str] = {},
        origin_req_host: str = "",
        unverifiable: bool = False,
        method: str = "",
        type: str = "",
        host: str = "",
        selector: str = "",
        tunnel_host: str = "",
        timeout: any = None,
        redirect_dict: any = None;

    def init(
        url: str,
        data: any = None,
        headers: dict[str, str] = {},
        origin_req_host: str = "",
        unverifiable: bool = False,
        method: str = ""
    ) {
        self.set_full_url(url);
        self.set_data(data);
        for (k, v) in headers.items() {
            self.add_header(k, v);
        }
        if len(origin_req_host) == 0 {
            self.origin_req_host = request_host(self);
        } else {
            self.origin_req_host = origin_req_host;
        }
        self.unverifiable = unverifiable;
        if len(method) > 0 {
            self.method = method;
        }
    }

    has:pub full_url: str { getter; }

    def set_full_url(url: str) {
        u = unwrap(url);
        st = splittag(u);
        self._full_url = st[0];
        frag = st[1];
        if frag != None {
            f: str = frag;
            self.fragment = f;
        } else {
            self.fragment = "";
        }
        self._parse();
    }

    def set_data(data: any) {
        if data != None or self.data != None {
            self.data = data;

            if self.has_header("Content-length") {
                self.remove_header("Content-length");
            }
        } else {
            self.data = data;
        }
    }

    def _parse {
        sp = splittype(self._full_url);
        ty = sp[0];
        if ty == None {
            raise ValueError("unknown url type: " + self.full_url);
        }
        t: str = ty;
        self.type = t;
        sh = splithost(sp[1]);
        h = sh[0];
        self.selector = sh[1];
        if h != None {
            hh: str = h;
            self.host = unquote(hh);
        }
    }

    def get_method -> str {
        if len(self.method) > 0 {
            return self.method;
        }
        if self.data != None {
            return "POST";
        }
        return "GET";
    }

    def get_full_url -> str {
        return self.full_url;
    }

    def set_proxy(host: str, type: str) {
        if self.type == "https" and len(self.tunnel_host) == 0 {
            self.tunnel_host = self.host;
        } else {
            self.type = type;
            self.selector = self.full_url;
        }
        self.host = host;
    }

    def has_proxy -> bool {
        return self.selector == self.full_url;
    }

    def add_header(key: str, val: str) {
        self.headers[key.capitalize()] = val;
    }

    def add_unredirected_header(key: str, val: str) {
        self.unredirected_hdrs[key.capitalize()] = val;
    }

    def has_header(header_name: str) -> bool {
        return header_name in self.headers or header_name in self.unredirected_hdrs;
    }

    def get_header(header_name: str, failobj: any = None) -> any {
        if header_name in self.headers {
            return self.headers[header_name];
        }
        if header_name in self.unredirected_hdrs {
            return self.unredirected_hdrs[header_name];
        }
        return failobj;
    }

    def remove_header(header_name: str) {
        if header_name in self.headers {
            self.headers.pop(header_name);
        }
        if header_name in self.unredirected_hdrs {
            self.unredirected_hdrs.pop(header_name);
        }
    }

    def header_items -> list[tuple[(str, str)]] {
        out: list[tuple[(str, str)]] = [];
        for (k, v) in self.unredirected_hdrs.items() {
            if k not in self.headers {
                out.append((k, v));
            }
        }
        for (k, v) in self.headers.items() {
            out.append((k, v));
        }
        return out;
    }
}

impl Request.full_url.getter -> str {
    if len(self.fragment) > 0 {
        return self._full_url + "#" + self.fragment;
    }
    return self._full_url;
}


def _insort(hs: list[BaseHandler], h: BaseHandler) {
    i = 0;
    while i < len(hs) {
        if hs[i].handler_order > h.handler_order {
            hs.insert(i, h);
            return;
        }
        i += 1;
    }
    hs.append(h);
}


obj:pub BaseHandler {
    has:pub parent: any = None,
        handler_order: int = 500,
        open_kinds: list[str] = [],
        error_codes: list[int] = [],
        req_kinds: list[str] = [],
        resp_kinds: list[str] = [],
        serves_error_default: bool = False;

    def add_parent(parent: OpenerDirector) {
        self.parent = parent;
    }

    def close {}
    def open_for(kind: str, req: Request) -> any {
        return None;
    }

    def request_for(kind: str, req: Request) -> Request {
        return req;
    }

    def response_for(kind: str, req: Request, response: any) -> any {
        return response;
    }

    def error_for(code: int, req: Request, fp: any, msg: str, hdrs: any) -> any {
        return None;
    }

    def http_error_default(
        req: Request, fp: any, code: int, msg: str, hdrs: any
    ) -> any {
        return None;
    }
}


obj:pub OpenerDirector {
    has:pub addheaders: list[tuple[(str, str)]] = [],
        handlers: list[BaseHandler] = [],
        handle_open: dict[str, list[BaseHandler]] = {},
        handle_error: dict[int, list[BaseHandler]] = {},
        handle_error_default: list[BaseHandler] = [],
        process_request: dict[str, list[BaseHandler]] = {},
        process_response: dict[str, list[BaseHandler]] = {};

    def init {
        self.addheaders = [("User-agent", "Jac-urllib/0.37")];
    }

    def add_handler(handler: BaseHandler) {
        added = False;
        for kind in handler.open_kinds {
            if kind not in self.handle_open {
                self.handle_open[kind] = [];
            }
            _insort(self.handle_open[kind], handler);
            added = True;
        }
        for code in handler.error_codes {
            if code not in self.handle_error {
                self.handle_error[code] = [];
            }
            _insort(self.handle_error[code], handler);
            added = True;
        }
        if handler.serves_error_default {
            _insort(self.handle_error_default, handler);
            added = True;
        }
        for kind in handler.req_kinds {
            if kind not in self.process_request {
                self.process_request[kind] = [];
            }
            _insort(self.process_request[kind], handler);
            added = True;
        }
        for kind in handler.resp_kinds {
            if kind not in self.process_response {
                self.process_response[kind] = [];
            }
            _insort(self.process_response[kind], handler);
            added = True;
        }
        if added {
            _insort(self.handlers, handler);
            handler.add_parent(self);
        }
    }

    def close {}
    def _call_open(kind: str, req: Request) -> any {
        if kind not in self.handle_open {
            return None;
        }
        for handler in self.handle_open[kind] {
            result = handler.open_for(kind, req);
            if result != None {
                return result;
            }
        }
        return None;
    }

    def _open(req: Request, data: any = None) -> any {
        result = self._call_open("default", req);
        if result != None {
            return result;
        }
        result = self._call_open(req.type, req);
        if result != None {
            return result;
        }
        return self._call_open("unknown", req);
    }

    def open(fullurl: any, data: any = None, timeout: any = None) -> any {
        req: Request;
        if isinstance(fullurl, str) {
            u: str = fullurl;
            req = Request(u, data);
        } else {
            req = fullurl;
            if data != None {
                req.set_data(data);
            }
        }
        req.timeout = timeout;
        protocol = req.type;
        write_file_bytes("/tmp/dbg_proto", protocol.encode());

        if protocol in self.process_request {
            for processor in self.process_request[protocol] {
                write_file_bytes("/tmp/dbg_reqfor", b"1");
                req = processor.request_for(protocol, req);
            }
        }
        write_file_bytes("/tmp/dbg_preopen", b"1");
        response = self._open(req, data);
        write_file_bytes("/tmp/dbg_postopen", b"1");

        if protocol in self.process_response {
            for processor in self.process_response[protocol] {
                write_file_bytes("/tmp/dbg_respfor", b"1");
                response = processor.response_for(protocol, req, response);
            }
        }
        write_file_bytes("/tmp/dbg_done", b"1");
        return response;
    }

    def error(
        proto: str, req: Request, fp: any, code: int, msg: str, hdrs: any
    ) -> any {
        if proto == "http" or proto == "https" {
            write_file_bytes("/tmp/dbg_err_in", str(code).encode());
            if code in self.handle_error {
                for h in self.handle_error[code] {
                    result = h.error_for(code, req, fp, msg, hdrs);
                    if result != None {
                        return result;
                    }
                }
            }
            for h in self.handle_error_default {
                write_file_bytes("/tmp/dbg_err_def", b"1");
                result = h.http_error_default(req, fp, code, msg, hdrs);
                if result != None {
                    return result;
                }
            }
            return None;
        }
        return None;
    }
}


def:pub build_opener(handlers: list[BaseHandler] = []) -> OpenerDirector {
    opener = OpenerDirector();

    skip_flags = [False, False, False, False, False, False, False, False, False, False];
    for h in handlers {
        if isinstance(h, ProxyHandler) {
            skip_flags[0] = True;
        }
        if isinstance(h, UnknownHandler) {
            skip_flags[1] = True;
        }
        if isinstance(h, HTTPHandler) and not isinstance(h, HTTPSHandler) {
            skip_flags[2] = True;
        }
        if isinstance(h, HTTPDefaultErrorHandler) {
            skip_flags[3] = True;
        }
        if isinstance(h, HTTPRedirectHandler) {
            skip_flags[4] = True;
        }
        if isinstance(h, FTPHandler) {
            skip_flags[5] = True;
        }
        if isinstance(h, FileHandler) {
            skip_flags[6] = True;
        }
        if isinstance(h, HTTPErrorProcessor) {
            skip_flags[7] = True;
        }
        if isinstance(h, DataHandler) {
            skip_flags[8] = True;
        }
        if isinstance(h, HTTPSHandler) {
            skip_flags[9] = True;
        }
    }
    if not skip_flags[0] {
        opener.add_handler(ProxyHandler());
    }
    if not skip_flags[1] {
        opener.add_handler(UnknownHandler());
    }
    if not skip_flags[2] {
        opener.add_handler(HTTPHandler());
    }
    if not skip_flags[3] {
        opener.add_handler(HTTPDefaultErrorHandler());
    }
    if not skip_flags[4] {
        opener.add_handler(HTTPRedirectHandler());
    }
    if not skip_flags[5] {
        opener.add_handler(FTPHandler());
    }
    if not skip_flags[6] {
        opener.add_handler(FileHandler());
    }
    if not skip_flags[7] {
        opener.add_handler(HTTPErrorProcessor());
    }
    if not skip_flags[8] {
        opener.add_handler(DataHandler());
    }
    if not skip_flags[9] {
        opener.add_handler(HTTPSHandler());
    }
    for h in handlers {
        opener.add_handler(h);
    }
    return opener;
}


obj:pub HTTPErrorProcessor(BaseHandler) {
    def init {
        self.handler_order = 1000;
        self.resp_kinds = ["http", "https"];
    }

    def http_response(request: Request, response: any) -> any {
        code = -1;
        msg = "";
        hdrs: any = None;
        if isinstance(response, HTTPResp) {
            write_file_bytes("/tmp/dbg_hr_is", b"1");
            hr: HTTPResp = response;
            c = hr.code;
            if c != None {
                ci: int = c;
                code = ci;
            } else {
                write_file_bytes("/tmp/dbg_hr_cnull", b"1");
            }
            msg = hr.msg;
            hdrs = hr.info();
        }
        write_file_bytes("/tmp/dbg_hr_code", str(code).encode());
        if code < 200 or code >= 300 {
            write_file_bytes("/tmp/dbg_hr_err", b"1");
            par = self.parent;
            if isinstance(par, OpenerDirector) {
                od: OpenerDirector = par;
                response = od.error("http", request, response, code, msg, hdrs);
            }
            write_file_bytes("/tmp/dbg_hr_errdone", b"1");
        }
        write_file_bytes("/tmp/dbg_hr_ret", b"1");
        return response;
    }

    def response_for(kind: str, req: Request, response: any) -> any {
        return self.http_response(req, response);
    }
}


obj:pub HTTPDefaultErrorHandler(BaseHandler) {
    def init {
        self.serves_error_default = True;
    }

    def http_error_default(
        req: Request, fp: any, code: int, msg: str, hdrs: any
    ) -> any {
        write_file_bytes("/tmp/dbg_deh_ctor", b"1");
        e = HTTPError(req.full_url, code, msg, hdrs, fp);
        write_file_bytes("/tmp/dbg_deh_raise", b"1");
        raise e;
    }
}


obj:pub HTTPRedirectHandler(BaseHandler) {
    has:pub max_repeats: int = 4,
        max_redirections: int = 10,
        inf_msg: str = "The HTTP server returned a redirect error that would lead to an infinite loop.\nThe last 30x error message was:\n";

    def init {
        self.error_codes = [301, 302, 303, 307, 308];
    }

    def error_for(code: int, req: Request, fp: any, msg: str, hdrs: any) -> any {
        return self.http_error_302(req, fp, code, msg, hdrs);
    }

    def redirect_request(
        req: Request, fp: any, code: int, msg: str, headers: any, newurl: str
    ) -> any {
        m = req.get_method();
        ok = False;
        if (code == 301 or code == 302 or code == 303 or code == 307 or code == 308)
            and (m == "GET" or m == "HEAD") {
            ok = True;
        }
        if (code == 301 or code == 302 or code == 303) and m == "POST" {
            ok = True;
        }
        if not ok {
            raise HTTPError(req.full_url, code, msg, headers, fp);
        }
        newurl2 = newurl.replace(" ", "%20");
        newheaders: dict[str, str] = {};
        for (k, v) in req.headers.items() {
            kl = k.lower();
            if kl != "content-length" and kl != "content-type" {
                newheaders[k] = v;
            }
        }
        nm = "GET";
        if m == "HEAD" {
            nm = "HEAD";
        }
        return Request(newurl2, None, newheaders, req.origin_req_host, True);
    }

    def http_error_302(
        req: Request, fp: any, code: int, msg: str, headers: any
    ) -> any {
        newurl = "";
        loc: any = None;
        uri: any = None;
        if isinstance(headers, Headers) {
            hh: Headers = headers;
            loc = hh.get("location", None);
            uri = hh.get("uri", None);
        }
        if isinstance(loc, str) {
            newurl = loc;
        } elif isinstance(uri, str) {
            newurl = uri;
        } else {
            return None;
        }

        parts = urlparse(newurl);
        if parts.scheme != "http"
            and parts.scheme != "https"
            and parts.scheme != "ftp"
            and parts.scheme != "" {
            raise HTTPError(
                newurl,
                code,
                msg + " - Redirection to url '" + newurl + "' is not allowed",
                headers,
                fp
            );
        }
        if len(parts.path) == 0 and len(parts.netloc) > 0 {
            newurl = urlunparse(
                [
                    parts.scheme,
                    parts.netloc,
                    "/",
                    parts.params,
                    parts.query,
                    parts.fragment
                ]
            );
        }

        newurl = quote(newurl, safe="!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~");
        newurl = urljoin(req.full_url, newurl);

        new = self.redirect_request(req, fp, code, msg, headers, newurl);
        if new == None {
            return None;
        }

        visited: dict[str, int];
        if req.redirect_dict != None {
            rd: dict[str, int] = req.redirect_dict;
            visited = rd;
        } else {
            visited = {};
            req.redirect_dict = visited;
        }
        new_req: Request = new;
        new_req.redirect_dict = visited;
        count = 0;
        if newurl in visited {
            count = visited[newurl];
        }
        if count >= self.max_repeats or len(visited) >= self.max_redirections {
            raise HTTPError(req.full_url, code, self.inf_msg + msg, headers, fp);
        }
        visited[newurl] = count + 1;

        fp.read();
        fp.close();
        par = self.parent;
        if isinstance(par, OpenerDirector) {
            od: OpenerDirector = par;
            return od.open(new_req, None, req.timeout);
        }
        return None;
    }
}


def _parse_proxy(
    proxy: str
) -> tuple[((str | None), (str | None), (str | None), (str | None))] {
    st = splittype(proxy);
    scheme = st[0];
    r_scheme = st[1];
    authority = "";
    if not r_scheme.startswith("/") {
        scheme = None;
        authority = proxy;
    } else {
        if not r_scheme.startswith("//") {
            raise ValueError("proxy URL with no authority: " + proxy);
        }
        end = -1;
        if "@" in r_scheme {
            host_separator = r_scheme.find("@");
            end = r_scheme.find("/", host_separator);
        } else {
            end = r_scheme.find("/", 2);
        }
        if end == -1 {
            authority = r_scheme[2:];
        } else {
            authority = r_scheme[2:end];
        }
    }
    su = splituser(authority);
    userinfo = su[0];
    hostport = su[1];
    user: (str | None) = None;
    password: (str | None) = None;
    if userinfo != None {
        ui: str = userinfo;
        pw = splitpasswd(ui);
        user = pw[0];
        password = pw[1];
    }
    return (scheme, user, password, hostport);
}


obj:pub ProxyHandler(BaseHandler) {
    has:pub proxies: dict[str, str] = {};

    def init(proxies: any = None) {
        self.handler_order = 100;
        if proxies == None {
            self.proxies = getproxies();
        } else {
            self.proxies = proxies;
        }
        for (t, u) in self.proxies.items() {
            self.open_kinds.append(t.lower());
        }
    }

    def open_for(kind: str, req: Request) -> any {
        if kind in self.proxies {
            return self.proxy_open(req, self.proxies[kind], kind);
        }
        return None;
    }

    def proxy_open(req: Request, proxy: str, type: str) -> any {
        orig_type = req.type;
        pp = _parse_proxy(proxy);
        proxy_type = pp[0];
        user = pp[1];
        password = pp[2];
        hostport = pp[3];
        ptype = orig_type;
        if proxy_type != None {
            pt: str = proxy_type;
            ptype = pt;
        }

        if len(req.host) > 0 and proxy_bypass(req.host) {
            return None;
        }

        if user != None and password != None {
            u: str = user;
            p: str = password;
            user_pass = unquote(u) + ":" + unquote(p);
            creds = b64encode(user_pass.encode()).decode();
            req.add_header("Proxy-authorization", "Basic " + creds);
        }
        hp = "";
        if hostport != None {
            h: str = hostport;
            hp = h;
        }
        req.set_proxy(unquote(hp), ptype);
        if orig_type == ptype or orig_type == "https" {
            return None;
        }
        par = self.parent;
        if isinstance(par, OpenerDirector) {
            od: OpenerDirector = par;
            return od.open(req, None, req.timeout);
        }
        return None;
    }
}


obj:pub HTTPPasswordMgr {
    has:pub passwd: dict[str, list[tuple[(tuple[(str, str)], str, str)]]] = {};

    def add_password(realm: str, uri: any, user: str, passwd: str) {
        uris: list[str] = [];
        if isinstance(uri, str) {
            u: str = uri;
            uris = [u];
        } else {
            uris = uri;
        }
        if realm not in self.passwd {
            self.passwd[realm] = [];
        }

        for default_port in [True, False] {
            for u in uris {
                self.passwd[realm].append(
                    (self.reduce_uri(u, default_port), user, passwd)
                );
            }
        }
    }

    def find_user_password(
        realm: str, authuri: str
    ) -> tuple[((str | None), (str | None))] {
        if realm not in self.passwd {
            return (None, None);
        }
        domains = self.passwd[realm];
        for default_port in [True, False] {
            reduced_authuri = self.reduce_uri(authuri, default_port);
            for row in domains {
                if self.is_suburi(row[0], reduced_authuri) {
                    return (row[1], row[2]);
                }
            }
        }
        return (None, None);
    }

    def reduce_uri(uri: str, default_port: bool = True) -> tuple[(str, str)] {
        parts = urlsplit(uri);
        scheme = parts.scheme;
        authority = parts.netloc;
        path = parts.path;
        if len(path) == 0 {
            path = "/";
        }
        if len(authority) > 0 {
            hp = splitport(authority);
            host = hp[0];
            port = hp[1];
            dflt = "";
            if scheme == "http" {
                dflt = "80";
            } elif scheme == "https" {
                dflt = "443";
            } elif scheme == "ftp" {
                dflt = "21";
            }
            authority = authority.lower();
            if default_port and port != None and port == dflt {
                authority = host.lower();
            }
        } else {
            authority = parts.path;
            if "@" in authority {
                authority = authority[authority.rfind("@") + 1:];
            }
            hp = splitport(authority);
            port = hp[1];
            if port != None {
                p: str = port;
                if p == "21" {
                    scheme = "ftp";
                } elif p == "443" {
                    scheme = "https";
                } else {
                    scheme = "http";
                }
            } else {
                scheme = "http";
            }
            authority = authority.lower();
        }
        return (scheme, authority + path);
    }

    def is_suburi(base: tuple[(str, str)], t_uri: tuple[(str, str)]) -> bool {
        if base == t_uri {
            return True;
        }
        if base[0] != t_uri[0] {
            return False;
        }
        return t_uri[1].startswith(base[1]);
    }
}


obj:pub HTTPPasswordMgrWithDefaultRealm(HTTPPasswordMgr) {
    def find_user_password(
        realm: str, authuri: str
    ) -> tuple[((str | None), (str | None))] {
        result = HTTPPasswordMgr.find_user_password(self, realm, authuri);
        if result[0] != None or result[1] != None {
            return result;
        }
        if "" not in self.passwd {
            return (None, None);
        }
        domains = self.passwd[""];
        for default_port in [True, False] {
            reduced_authuri = self.reduce_uri(authuri, default_port);
            for row in domains {
                if self.is_suburi(row[0], reduced_authuri) {
                    return (row[1], row[2]);
                }
            }
        }
        return (None, None);
    }
}


obj:pub HTTPPasswordMgrWithPriorAuth(HTTPPasswordMgrWithDefaultRealm) {
    has:pub passwd_authed: dict[str, list[tuple[(tuple[(str, str)], str, str)]]] = {};

    def add_password_authed(
        realm: str, uri: any, user: str, passwd: str, is_authenticated: bool
    ) {
        self.add_password(realm, uri, user, passwd);
        if is_authenticated {
            uris: list[str] = [];
            if isinstance(uri, str) {
                u: str = uri;
                uris = [u];
            } else {
                uris = uri;
            }
            if realm not in self.passwd_authed {
                self.passwd_authed[realm] = [];
            }
            for u in uris {
                self.passwd_authed[realm].append(
                    (self.reduce_uri(u, True), user, passwd)
                );
            }
        }
    }

    def update_authenticated(uri: any, is_authenticated: bool) {
        uris: list[str] = [];
        if isinstance(uri, str) {
            u: str = uri;
            uris = [u];
        } else {
            uris = uri;
        }
        for (realm, entries) in self.passwd.items() {
            for row in entries {
                matched = False;
                for u in uris {
                    if self.is_suburi(row[0], self.reduce_uri(u, True)) {
                        matched = True;
                    }
                }
                if matched {
                    if is_authenticated {
                        if realm not in self.passwd_authed {
                            self.passwd_authed[realm] = [];
                        }
                        already = False;
                        for ae in self.passwd_authed[realm] {
                            if ae[0] == row[0] {
                                already = True;
                            }
                        }
                        if not already {
                            self.passwd_authed[realm].append(row);
                        }
                    } elif realm in self.passwd_authed {
                        kept: list[tuple[(tuple[(str, str)], str, str)]] = [];
                        for ae in self.passwd_authed[realm] {
                            if ae[0] != row[0] {
                                kept.append(ae);
                            }
                        }
                        self.passwd_authed[realm] = kept;
                    }
                }
            }
        }
    }

    def is_authenticated(authuri: str) -> bool {
        reduced = self.reduce_uri(authuri, True);
        for (realm, entries) in self.passwd_authed.items() {
            for row in entries {
                if self.is_suburi(row[0], reduced) {
                    return True;
                }
            }
        }
        return False;
    }
}


obj:pub AbstractBasicAuthHandler {
    has:pub passwd: any = None,
        retry_count: int = 0,
        max_retries: int = 5;

    def parse_realm(header: str) -> tuple[(str, str)] {
        i = header.find("realm=\"");
        if i == -1 {
            return ("", "");
        }
        j = header.find("\"", i + 7);
        if j == -1 {
            return ("", "");
        }
        scheme = header[:i].strip();
        realm = header[i + 7:j];
        return (scheme, realm);
    }

    def http_error_auth_reqed(
        authreq: str, host: str, req: Request, headers: any
    ) -> any {
        authreq_l = authreq.lower();
        hostport = req.host;
        aval: any = "";
        if isinstance(headers, Headers) {
            hh: Headers = headers;
            aval = hh.get(authreq, "");
        }
        ahdr = "";
        if isinstance(aval, str) {
            ahdr = aval;
        }
        pr = self.parse_realm(ahdr);
        scheme = pr[0];
        realm = pr[1];
        if len(scheme) == 0 {
            return None;
        }
        if scheme.lower() != "basic" {
            return None;
        }
        if self.retry_count > 0 {
            self.retry_count = 0;
        }
        return self.retry_http_basic_auth(hostport, req, realm);
    }

    def retry_http_basic_auth(host: str, req: Request, realm: str) -> any {
        return None;
    }
}


obj:pub HTTPBasicAuthHandler(AbstractBasicAuthHandler, BaseHandler) {
    def init(password_mgr: any = None) {
        self.error_codes = [401];
        if password_mgr == None {
            self.passwd = HTTPPasswordMgr();
        } else {
            self.passwd = password_mgr;
        }
    }

    def error_for(code: int, req: Request, fp: any, msg: str, hdrs: any) -> any {
        if code != 401 {
            return None;
        }
        return self.http_error_auth_reqed("www-authenticate", req.host, req, hdrs);
    }

    def retry_http_basic_auth(host: str, req: Request, realm: str) -> any {
        pm = self.passwd;
        if isinstance(pm, HTTPPasswordMgr) {
            pmm: HTTPPasswordMgr = pm;
            pair = pmm.find_user_password(realm, req.full_url);
            user = pair[0];
            pw = pair[1];
            if user != None and pw != None {
                u: str = user;
                p: str = pw;
                raw = u + ":" + p;
                auth = "Basic " + b64encode(raw.encode()).decode();
                req.add_header("Authorization", auth);
                req.add_unredirected_header("Authorization", auth);
                par = self.parent;
                if isinstance(par, OpenerDirector) {
                    od: OpenerDirector = par;
                    return od.open(req, None, req.timeout);
                }
            }
        }
        return None;
    }
}


obj:pub ProxyBasicAuthHandler(AbstractBasicAuthHandler, BaseHandler) {
    def init(password_mgr: any = None) {
        self.error_codes = [407];
        if password_mgr == None {
            self.passwd = HTTPPasswordMgr();
        } else {
            self.passwd = password_mgr;
        }
    }

    def error_for(code: int, req: Request, fp: any, msg: str, hdrs: any) -> any {
        if code != 407 {
            return None;
        }
        return self.http_error_auth_reqed("proxy-authenticate", req.host, req, hdrs);
    }

    def retry_http_basic_auth(host: str, req: Request, realm: str) -> any {
        pm = self.passwd;
        if isinstance(pm, HTTPPasswordMgr) {
            pmm: HTTPPasswordMgr = pm;
            pair = pmm.find_user_password(realm, req.full_url);
            user = pair[0];
            pw = pair[1];
            if user != None and pw != None {
                u: str = user;
                p: str = pw;
                raw = u + ":" + p;
                auth = "Basic " + b64encode(raw.encode()).decode();
                req.add_header("Proxy-authorization", auth);
                req.add_unredirected_header("Proxy-authorization", auth);
                par = self.parent;
                if isinstance(par, OpenerDirector) {
                    od: OpenerDirector = par;
                    return od.open(req, None, req.timeout);
                }
            }
        }
        return None;
    }
}


obj:pub HTTPResp(addinfourl) {
    has:pub msg: str = "",
        body_length: int = 0;
}


def _do_open(req: Request, use_tls: bool) -> HTTPResp {
    host = req.host;
    if len(host) == 0 {
        raise URLError("no host given");
    }

    hp = splitport(host);
    hostname = hp[0];
    port = 443 if use_tls else 80;
    if hp[1] != None {
        p: str = hp[1];
        port = int(p);
    }

    headers: dict[str, str] = {};
    for (k, v) in req.unredirected_hdrs.items() {
        headers[k] = v;
    }
    for (k, v) in req.headers.items() {
        headers[k] = v;
    }
    headers["Connection"] = "close";

    data: bytes = b"";
    has_body = False;
    if req.data != None {
        has_body = True;
        d = req.data;
        if isinstance(d, bytes) {
            data = d;
        } elif isinstance(d, str) {
            data = d.encode();
        }
    }
    if has_body and "Content-length" not in headers {
        headers["Content-length"] = str(len(data));
    }

    selector = req.selector;
    if len(selector) == 0 {
        selector = "/";
    }
    reqtext = req.get_method() + " " + selector + " HTTP/1.1\r\n";
    for (k, v) in headers.items() {
        reqtext += k.title() + ": " + v + "\r\n";
    }
    reqtext += "\r\n";
    reqb = reqtext.encode() + data;

    sock = create_connection((hostname, port));
    raw = b"";
    if use_tls {
        ctx = create_default_context();
        ss = ctx.wrap_socket(sock, server_hostname=hostname);
        ss.sendall(reqb);
        chunk = ss.recv(8192);
        while len(chunk) > 0 {
            raw += chunk;
            chunk = ss.recv(8192);
        }
        ss.close();
    } else {
        sock.sendall(reqb);
        chunk = sock.recv(8192);
        while len(chunk) > 0 {
            raw += chunk;
            chunk = sock.recv(8192);
        }
        sock.close();
    }

    n = len(raw);
    sep = -1;
    i = 0;
    while i + 3 < n {
        if raw[i] == 13
            and raw[i + 1] == 10
            and raw[i + 2] == 13
            and raw[i + 3] == 10 {
            sep = i;
            break;
        }
        i += 1;
    }
    header_bytes = raw;
    body = b"";
    if sep != -1 {
        header_bytes = raw[:sep];
        body = raw[sep + 4:];
    }
    lines = header_bytes.decode().split("\r\n");
    status: int = 0;
    reason: str = "";
    status_line = lines[0];
    sp1 = status_line.find(" ");
    if sp1 != -1 {
        after = status_line[sp1 + 1:];
        sp2 = after.find(" ");
        if sp2 == -1 {
            status = int(after);
        } else {
            status = int(after[:sp2]);
            reason = after[sp2 + 1:];
        }
    }
    hdrs = Headers();
    j = 1;
    while j < len(lines) {
        line = lines[j];
        colon = line.find(":");
        if colon != -1 {
            hdrs.add(line[:colon].strip(), line[colon + 1:].strip());
        }
        j += 1;
    }
    r = HTTPResp(fp=BytesIO(body), headers=hdrs, url=req.get_full_url(), code=status);
    r.msg = reason;
    r.body_length = len(body);
    return r;
}


obj:pub AbstractHTTPHandler(BaseHandler) {
    has:pub _debuglevel: int = 0;

    def set_http_debuglevel(level: int) {
        self._debuglevel = level;
    }

    def do_request_(request: Request) -> Request {
        host = request.host;
        if len(host) == 0 {
            raise URLError("no host given");
        }
        if request.data != None {
            if not request.has_header("Content-type") {
                request.add_unredirected_header(
                    "Content-type", "application/x-www-form-urlencoded"
                );
            }
            if not request.has_header("Content-length")
                and not request.has_header("Transfer-encoding") {
                d = request.data;
                if isinstance(d, bytes) {
                    db: bytes = d;
                    request.add_unredirected_header("Content-length", str(len(db)));
                } elif isinstance(d, str) {
                    ds: str = d;
                    request.add_unredirected_header(
                        "Content-length", str(len(ds.encode()))
                    );
                } else {
                    request.add_unredirected_header("Transfer-encoding", "chunked");
                }
            }
        }
        sel_host = host;
        if request.has_proxy() {
            st = splittype(request.selector);
            sh = splithost(st[1]);
            if sh[0] != None {
                shh: str = sh[0];
                sel_host = shh;
            }
        }
        if not request.has_header("Host") {
            request.add_unredirected_header("Host", sel_host);
        }
        par = self.parent;
        if isinstance(par, OpenerDirector) {
            od: OpenerDirector = par;
            for (name, value) in od.addheaders {
                cap = name.capitalize();
                if not request.has_header(cap) {
                    request.add_unredirected_header(cap, value);
                }
            }
        }
        return request;
    }
}


obj:pub HTTPHandler(AbstractHTTPHandler) {
    def init {
        self.open_kinds = ["http"];
        self.req_kinds = ["http"];
    }

    def http_open(req: Request) -> any {
        return _do_open(req, False);
    }

    def open_for(kind: str, req: Request) -> any {
        if kind == "http" {
            return self.http_open(req);
        }
        return None;
    }

    def request_for(kind: str, req: Request) -> Request {
        return self.do_request_(req);
    }
}


obj:pub HTTPSHandler(AbstractHTTPHandler) {
    def init(context: any = None) {
        self.open_kinds = ["https"];
        self.req_kinds = ["https"];
    }

    def https_open(req: Request) -> any {
        return _do_open(req, True);
    }

    def open_for(kind: str, req: Request) -> any {
        if kind == "https" {
            return self.https_open(req);
        }
        return None;
    }

    def request_for(kind: str, req: Request) -> Request {
        return self.do_request_(req);
    }
}


obj:pub HTTPCookieProcessor(BaseHandler) {
    has:pub cookiejar: any = None;

    def init(cookiejar: any = None) {
        self.cookiejar = cookiejar;
        self.req_kinds = ["http", "https"];
        self.resp_kinds = ["http", "https"];
    }

    def http_request(request: Request) -> Request {
        if self.cookiejar != None {
            self.cookiejar.add_cookie_header(request);
        }
        return request;
    }

    def http_response(request: Request, response: any) -> any {
        if self.cookiejar != None {
            self.cookiejar.extract_cookies(response, request);
        }
        return response;
    }

    def request_for(kind: str, req: Request) -> Request {
        return self.http_request(req);
    }

    def response_for(kind: str, req: Request, response: any) -> any {
        return self.http_response(req, response);
    }
}


obj:pub UnknownHandler(BaseHandler) {
    def init {
        self.open_kinds = ["unknown"];
    }

    def open_for(kind: str, req: Request) -> any {
        raise URLError("unknown url type: " + req.type);
    }
}


def:pub parse_keqv_list(l: list[str]) -> dict[str, str] {
    parsed: dict[str, str] = {};
    for elt in l {
        kv = elt.split("=", 1);
        if len(kv) == 2 {
            v = kv[1];
            if len(v) >= 1 and v[0] == "\"" and v[len(v) - 1] == "\"" {
                v = v[1:len(v) - 1];
            }
            parsed[kv[0]] = v;
        }
    }
    return parsed;
}


def:pub parse_http_list(s: str) -> list[str] {
    res: list[str] = [];
    part = "";
    escape = False;
    inquote = False;
    for cur in s {
        if escape {
            part += cur;
            escape = False;
            continue;
        }
        if inquote {
            if cur == "\\" {
                escape = True;
                continue;
            } elif cur == "\"" {
                inquote = False;
            }
            part += cur;
            continue;
        }
        if cur == "," {
            res.append(part);
            part = "";
            continue;
        }
        if cur == "\"" {
            inquote = True;
        }
        part += cur;
    }
    if len(part) > 0 {
        res.append(part);
    }
    out: list[str] = [];
    for p in res {
        out.append(p.strip());
    }
    return out;
}


obj:pub FileHandler(BaseHandler) {
    def init {
        self.open_kinds = ["file"];
    }

    def open_for(kind: str, req: Request) -> any {
        return self.open_local_file(req);
    }

    def open_local_file(req: Request) -> any {
        localfile = url2pathname(req.full_url, True, False);
        try {
            data = read_file_bytes(localfile);
        } except OSError as e {
            raise URLError(e, localfile);
        }
        hdrs = Headers();
        hdrs.add("Content-type", "text/plain");
        hdrs.add("Content-length", str(len(data)));
        origurl = pathname2url(localfile, True);
        return addinfourl(BytesIO(data), hdrs, origurl);
    }
}


obj:pub FTPHandler(BaseHandler) {
    def init {
        self.open_kinds = ["ftp"];
    }

    def open_for(kind: str, req: Request) -> any {
        return self.ftp_open(req);
    }

    def ftp_open(req: Request) -> any {
        raise URLError("ftp error: ftplib is not available natively");
    }
}


obj:pub CacheFTPHandler(FTPHandler) {
    has:pub cache: dict[str, any] = {},
        timeout: dict[str, float] = {},
        soonest: float = 0.0,
        delay: float = 60.0,
        max_conns: int = 16;

    def setTimeout(t: float) {
        self.delay = t;
    }

    def setMaxConns(m: int) {
        self.max_conns = m;
    }
}


obj:pub DataHandler(BaseHandler) {
    def init {
        self.open_kinds = ["data"];
    }

    def open_for(kind: str, req: Request) -> any {
        return self.data_open(req);
    }

    def data_open(req: Request) -> any {
        url = req.full_url;
        first = url.split(":", 1);
        if len(first) != 2 {
            raise URLError("bad data url");
        }
        second = first[1].split(",", 1);
        if len(second) != 2 {
            raise URLError("bad data url");
        }
        mediatype = second[0];
        datastr = second[1];
        for ch in mediatype {
            if ch < " " or ch == "\x7f" {
                raise ValueError("Control characters not allowed in data: mediatype");
            }
        }
        data = unquote_to_bytes(datastr);
        if mediatype.endswith(";base64") {
            data = b64decode(data);
            mediatype = mediatype[:len(mediatype) - 7];
        }
        if len(mediatype) == 0 {
            mediatype = "text/plain;charset=US-ASCII";
        }
        hdrs = Headers();
        hdrs.add("Content-type", mediatype);
        hdrs.add("Content-length", str(len(data)));
        return addinfourl(BytesIO(data), hdrs, url);
    }
}


glob _opener: any = None;


def:pub urlopen(
    url: any, data: any = None, timeout: any = None, context: any = None
) -> any {
    opener: OpenerDirector;
    if context != None {
        hs: list[BaseHandler] = [HTTPSHandler()];
        opener = build_opener(hs);
    } elif _opener == None {
        opener = build_opener();
        _opener = opener;
    } else {
        opener = _opener;
    }
    return opener.open(url, data, timeout);
}


def:pub install_opener(opener: OpenerDirector) {
    _opener = opener;
}


glob _url_tempfiles: list[str] = [];


def:pub urlretrieve(
    url: any, filename: str = "", reporthook: any = None, data: any = None
) -> tuple[(str, any)] {
    url_type = "";
    st = splittype(url);
    if st[0] != None {
        ut: str = st[0];
        url_type = ut;
    }
    path = st[1];

    fp = urlopen(url, data);
    headers = fp.info();
    if url_type == "file" and len(filename) == 0 {
        return (path, headers);
    }
    fname = filename;
    if len(fname) == 0 {
        import tempfile;
        fname = tempfile.mktemp();
        _url_tempfiles.append(fname);
    }
    body = fp.read();
    b: bytes = body;
    size = -1;
    cl = headers.get("Content-Length", None);
    if cl != None {
        c: str = cl;
        size = int(c);
    }
    bs = 1024 * 8;
    blocknum = 0;
    if reporthook != None {
        r0 = reporthook(blocknum, bs, size);
    }
    off = 0;
    while off < len(b) {
        chunk = b[off:off + bs];
        off += len(chunk);
        blocknum += 1;
        if reporthook != None {
            r0 = reporthook(blocknum, bs, size);
        }
    }
    write_file_bytes(fname, b);
    read_total = len(b);
    result = (fname, headers);
    if size >= 0 and read_total < size {
        raise ContentTooShortError(
            "retrieval incomplete: got only "
                + str(read_total)
                + " out of "
                + str(size)
                + " bytes",
            result
        );
    }
    return result;
}


def:pub urlcleanup {
    for temp_file in _url_tempfiles {
        try {
            os.unlink(temp_file);
        } except OSError {}
    }
    _url_tempfiles = [];
    if _opener != None {
        _opener = None;
    }
}


def _is_local_authority(authority: str, resolve: bool) -> bool {
    if len(authority) == 0 or authority == "localhost" {
        return True;
    }
    if not resolve {
        return False;
    }
    r: tuple[(list[bytes], int)] = resolve_all(authority, "0");
    return r[1] == 0 and len(r[0]) > 0;
}


def:pub url2pathname(
    url: str, require_scheme: bool = False, resolve_host: bool = False
) -> str {
    u = url;
    if not require_scheme {
        u = "file:" + u;
    }
    parts = urlsplit(u);
    if parts.scheme != "file" {
        raise URLError("URL is missing a 'file:' scheme");
    }
    if not _is_local_authority(parts.netloc, resolve_host) {
        raise URLError("file:// scheme is supported only on localhost");
    }
    return unquote(parts.path);
}


def:pub pathname2url(pathname: str, add_scheme: bool = False) -> str {
    scheme = "";
    if add_scheme {
        scheme = "file:";
    }
    drive = "";
    slash = "";
    tail = pathname;
    if pathname.startswith("/") {
        if pathname.startswith("//") {
            slash = "//" + pathname[:1];
            tail = pathname[1:];
        } else {
            slash = "//" + pathname[:1];
            tail = pathname[1:];
        }
    }
    return scheme + drive + slash + quote(tail);
}


def:pub localhost -> str {
    return "127.0.0.1";
}


def:pub thishost -> str {
    return localhost();
}


def:pub noheaders -> Headers {
    return Headers();
}


def _environ_pairs -> dict[str, str] {
    env: dict[str, str] = {};
    raw = b"";
    try {
        raw = read_file_bytes("/proc/self/environ");
    } except OSError {
        return env;
    }
    n = len(raw);
    start = 0;
    i = 0;
    while i <= n {
        if i == n or raw[i] == 0 {
            if i > start {
                ent = raw[start:i];
                eq = 0;
                while eq < len(ent) and ent[eq] != 61 {
                    eq += 1;
                }
                if eq > 0 and eq < len(ent) {
                    env[ent[0:eq].decode()] = ent[eq + 1:].decode();
                }
            }
            start = i + 1;
        }
        i += 1;
    }
    return env;
}


def:pub getproxies_environment -> dict[str, str] {
    proxies: dict[str, str] = {};
    environment: list[tuple[(str, str, str)]] = [];
    env = _environ_pairs();
    for name in env.keys() {
        if len(name) > 5
            and name[len(name) - 6] == "_"
            and name[len(name) - 5:].lower() == "proxy" {
            v: str = env[name];
            proxy_name = name[:len(name) - 6].lower();
            environment.append((name, v, proxy_name));
            if len(v) > 0 {
                proxies[proxy_name] = v;
            }
        }
    }
    if "REQUEST_METHOD" in env {
        if "http" in proxies {
            proxies.pop("http");
        }
    }
    for (name, value, proxy_name) in environment {
        if name[len(name) - 6:] == "_proxy" {
            if len(value) > 0 {
                proxies[proxy_name] = value;
            } elif proxy_name in proxies {
                proxies.pop(proxy_name);
            }
        }
    }
    return proxies;
}


def:pub proxy_bypass_environment(host: str, proxies: any = None) -> bool {
    p: dict[str, str] = {};
    if proxies == None {
        p = getproxies_environment();
    } elif isinstance(proxies, dict) {
        pd: dict[str, str] = proxies;
        p = pd;
    }
    if "no" not in p {
        return False;
    }
    no_proxy = p["no"];
    if no_proxy == "*" {
        return True;
    }
    host_l = host.lower();
    hp = splitport(host_l);
    hostonly = hp[0];
    for name in no_proxy.split(",") {
        n = name.strip();
        if len(n) > 0 {
            n = n.lstrip(".");
            n = n.lower();
            if hostonly == n or host_l == n {
                return True;
            }
            n2 = "." + n;
            if hostonly.endswith(n2) or host_l.endswith(n2) {
                return True;
            }
        }
    }
    return False;
}


def:pub getproxies -> dict[str, str] {
    return getproxies_environment();
}


def:pub proxy_bypass(host: str) -> bool {
    return proxy_bypass_environment(host);
}
