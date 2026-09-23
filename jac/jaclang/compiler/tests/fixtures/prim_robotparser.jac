"""Bundled native ``urllib.robotparser`` cross-backend equivalence fixture.

The sv entry drives CPython's real ``urllib.robotparser``; the na entry
drives the bundled ``na_stdlib/urllib/robotparser.jac``. ES/JS opts out.

Only the pure-parse surface is exercised (``parse`` + ``can_fetch`` /
``crawl_delay`` / ``request_rate`` / ``site_maps`` / ``str``): ``read()``
needs network, and ``RequestRate`` is a namedtuple in CPython but a plain
object natively, so rates are compared through their fields.

The robots.txt body covers: ``*`` group rules, longest-match allow vs
disallow, ``$`` end anchors, ``*`` wildcards, crawl-delay, request-rate,
sitemaps, agent substring matching, and the implicit /robots.txt allow.
"""

import urllib.robotparser as urob;


def _robots() -> list[str] {
    return [
        "# comment line",
        "User-agent: *",
        "Disallow: /private",
        "Allow: /private/pub",
        "",
        "User-agent: badbot",
        "Disallow: /",
        "Crawl-delay: 5",
        "Request-rate: 3/10",
        "",
        "User-agent: starbot",
        "Disallow: /*.gif$",
        "Disallow: /tmp/*",
        "Disallow: /x$y",  # '$' not at end -> ValueError -> rule dropped
        "",
        "Sitemap: http://ex.com/sitemap.xml"
    ];
}


def robot_py() -> dict[any, any] {
    rp: any = urob.RobotFileParser("http://ex.com/robots.txt");
    rp.parse(_robots());
    rr: any = rp.request_rate("badbot");
    unread: any = urob.RobotFileParser("http://x/");
    return {
        "host": rp.host,
        "path": rp.path,
        "mtime_pos": 1 if rp.mtime() > 0 else 0,
        "cf_priv": rp.can_fetch("bot", "http://ex.com/private/x"),
        "cf_pub": rp.can_fetch("bot", "http://ex.com/private/pub/x"),
        "cf_bad": rp.can_fetch("badbot", "http://ex.com/any"),
        "cf_bad_root": rp.can_fetch("badbot", "http://ex.com/"),
        "cf_star_gif": rp.can_fetch("starbot", "http://ex.com/i.gif"),
        "cf_star_gifq": rp.can_fetch("starbot", "http://ex.com/i.gif?x=1"),
        "cf_star_tmp": rp.can_fetch("starbot", "http://ex.com/tmp/a/b"),
        "cf_star_xy": rp.can_fetch("starbot", "http://ex.com/x$y"),
        "cf_robots": rp.can_fetch("badbot", "http://ex.com/robots.txt"),
        "delay_bad": rp.crawl_delay("badbot"),
        "delay_bot": rp.crawl_delay("bot"),
        "rr_bad": str(rr.requests) + "/" + str(rr.seconds),
        "rr_bot": rp.request_rate("bot"),
        "sitemaps": rp.site_maps(),
        "sm_unread": unread.site_maps(),
        "str_has_ua": 1 if "User-agent: badbot" in str(rp) else 0,
        "str_has_rr": 1 if "Request-rate: 3/10" in str(rp) else 0,
        "unread_cf": unread.can_fetch("b", "http://x/p"),
        "unread_delay": unread.crawl_delay("b"),
        "entries": len(rp.entries)
    };
}


def robot_cl() -> dict[any, any] {
    return {};
}


# ---- native lane ----

import from urllib.robotparser { RobotFileParser, RequestRate }


def robot_na() -> dict[str, any] {
    rp = RobotFileParser("http://ex.com/robots.txt");
    rp.parse(_robots());
    rr = rp.request_rate("badbot");
    rr_bad = "none";
    if rr != None {
        rrq: RequestRate = rr;
        rr_bad = str(rrq.requests) + "/" + str(rrq.seconds);
    }
    unread = RobotFileParser("http://x/");
    return {
        "host": rp.host,
        "path": rp.path,
        "mtime_pos": 1 if rp.mtime() > 0 else 0,
        "cf_priv": rp.can_fetch("bot", "http://ex.com/private/x"),
        "cf_pub": rp.can_fetch("bot", "http://ex.com/private/pub/x"),
        "cf_bad": rp.can_fetch("badbot", "http://ex.com/any"),
        "cf_bad_root": rp.can_fetch("badbot", "http://ex.com/"),
        "cf_star_gif": rp.can_fetch("starbot", "http://ex.com/i.gif"),
        "cf_star_gifq": rp.can_fetch("starbot", "http://ex.com/i.gif?x=1"),
        "cf_star_tmp": rp.can_fetch("starbot", "http://ex.com/tmp/a/b"),
        "cf_star_xy": rp.can_fetch("starbot", "http://ex.com/x$y"),
        "cf_robots": rp.can_fetch("badbot", "http://ex.com/robots.txt"),
        "delay_bad": rp.crawl_delay("badbot"),
        "delay_bot": rp.crawl_delay("bot"),
        "rr_bad": rr_bad,
        "rr_bot": rp.request_rate("bot"),
        "sitemaps": rp.site_maps(),
        "sm_unread": unread.site_maps(),
        "str_has_ua": 1 if "User-agent: badbot" in str(rp) else 0,
        "str_has_rr": 1 if "Request-rate: 3/10" in str(rp) else 0,
        "unread_cf": unread.can_fetch("b", "http://x/p"),
        "unread_delay": unread.crawl_delay("b"),
        "entries": len(rp.entries)
    };
}
