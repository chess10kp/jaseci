def _utc_now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}

impl TriggerSpec.validate(
    trigger: str,
    interval: float | None = None,
    cron: str | None = None,
    date: str | None = None
) -> TriggerSpec {
    valid = ('interval', 'cron', 'date');
    if trigger not in valid {
        raise ValueError(f"trigger must be one of: {list(valid)}");
    }
    if trigger == 'interval' {
        if interval is None {
            raise ValueError("interval (seconds) required for trigger='interval'");
        }
        if float(interval) <= 0 {
            raise ValueError("interval must be > 0 seconds");
        }
    } elif trigger == 'cron' {
        if not cron {
            raise ValueError("cron expression required for trigger='cron'");
        }
        _ct: any = CronTrigger;
        if _ct is None {
            raise ValueError(
                "cron triggers require APScheduler — enable the 'scheduler' capability and run 'jac install'."
            );
        }
        try {
            _ct.from_crontab(cron);
        } except Exception as e {
            raise ValueError(f"invalid cron expression: {e}");
        }
    } elif trigger == 'date' {
        if not date {
            raise ValueError("date (ISO datetime string) required for trigger='date'");
        }
    }
    return TriggerSpec(trigger=trigger, interval=interval, cron=cron, date=date);
}

impl TriggerSpec.from_dict(d: dict[str, any]) -> TriggerSpec {
    kw: dict[str, any] = {'trigger': d.get('trigger', 'interval')};
    comptime for f in fields(TriggerSpec) {
        comptime if f.name != 'trigger' {
            kw[f.name] = d.get(f.name);
        }
    }
    return TriggerSpec(**kw);
}

impl TriggerSpec.to_dict -> dict[str, any] {
    out: dict[str, any] = {};
    comptime for f in fields(TriggerSpec) {
        out[f.name] = get_field(self, f.name);
    }
    return out;
}

impl TriggerSpec.apscheduler_kwargs -> dict[str, any] {
    if self.trigger == 'interval' {
        if self.interval is None {
            raise ValueError("interval (seconds) required for trigger='interval'");
        }
        return {'seconds': float(self.interval)};
    }
    if self.trigger == 'cron' {
        parts = (self.cron or '').strip().split();
        (f_min, f_hour, f_day, f_month, f_weekday) = parts;
        return {
            'minute': f_min,
            'hour': f_hour,
            'day': f_day,
            'month': f_month,
            'day_of_week': f_weekday
        };
    }
    return {'run_date': self.date};
}

def _doc_row(raw: any) -> dict[str, any] {
    return raw if isinstance(raw, dict) else json.loads(str(raw));
}

def _fire_lease_ttl(spec: TriggerSpec) -> int {
    if spec.trigger == 'interval' and spec.interval {
        return max(1, min(300, int(float(spec.interval) * 0.8)));
    }
    if spec.trigger == 'cron' {
        return 45;
    }
    return 300;
}

def _where_sql(where: dict[str, any] | None, params: dict[str, any]) -> str {
    sql = '';
    n = 0;
    for (k, v) in (where or {}).items() {
        key = f"w{n}";
        n += 1;
        params[key] = json.dumps(v, `default=str);
        sql += f" AND doc->'{k}' = CAST(:{key} AS jsonb)";
    }
    return sql;
}
