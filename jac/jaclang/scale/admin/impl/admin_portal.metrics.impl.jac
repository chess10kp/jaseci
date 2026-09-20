import from jaclang.server.transport { Meta }
import from jaclang.runtime.runtime { JacRuntime as Jac }
import from jaclang.runtime.constants { Constants as Con }


impl JacAPIServerAdmin.admin_graph_data(
    username: str | None = None, Authorization: str | None = None
) -> JSONResponse {
    error = self.require_admin(Authorization);
    if error {
        return JSONResponse(
            status_code=403,
            content={'error': 'Forbidden', 'message': 'Admin access required'}
        );
    }
    import from jaclang.runtime.graph_utils { collect_node_connections }
    target_username = username or Con.GUEST.value;
    root_id = self._require_user_manager().get_root_id(target_username);
    if not root_id {
        return JSONResponse(
            status_code=404,
            content={
                'error': 'Not found',
                'message': f"User '{target_username}' not found or has no graph"
            }
        );
    }
    ctx = Jac.get_context();
    ctx.set_user_root(root_id);
    try {
        user_root = ctx.get_root();
        visited_nodes: set = set();
        connections: set = set();
        edge_ids: set = set();
        nodes: list[dict[str, str]] = [];
        edges: list[dict[str, str]] = [];

        collect_node_connections(user_root, visited_nodes, connections, edge_ids);

        nodes.append({'id': Jac.object_ref(user_root), 'label': 'root'});
        for node_arch in visited_nodes {
            if node_arch != user_root {
                nodes.append(
                    {'id': Jac.object_ref(node_arch), 'label': repr(node_arch)}
                );
            }
        }
        for (_, source_node, target_node, edge_arch) in connections {
            edge_data: dict[str, str] = {
                'from': Jac.object_ref(source_node),
                'to': Jac.object_ref(target_node)
            };
            if repr(edge_arch) != 'GenericEdge()' {
                edge_data['label'] = repr(edge_arch);
            }
            edges.append(edge_data);
        }

        return JSONResponse(
            status_code=200,
            content={
                'version': '1.0',
                'username': target_username,
                'nodes': nodes,
                'edges': edges
            }
        );
    } except Exception as e {
        return JSONResponse(
            status_code=500, content={'error': 'Internal error', 'message': str(e)}
        );
    }
}


impl JacAPIServerAdmin.admin_get_metrics(
    Authorization: str | None = None
) -> TransportResponse {
    error = self.require_admin(Authorization);
    if error {
        return error;
    }
    if not self._metrics or not self._metrics.is_enabled() {
        return TransportResponse.success(
            data={
                'enabled': False,
                'message': 'Prometheus metrics are not enabled',
                'metrics': []
            },
            meta=Meta(extra={'http_status': 200})
        );
    }
    try {
        raw_metrics = self._metrics.expose().decode('utf-8');
        metrics_data = _parse_prometheus_text(raw_metrics);
        summary = _calculate_metrics_summary(metrics_data);

        return TransportResponse.success(
            data={
                'enabled': True,
                'summary': summary,
                'metrics': metrics_data,
                'raw_available': True
            },
            meta=Meta(extra={'http_status': 200})
        );
    } except Exception as e {
        return TransportResponse.fail(
            code='METRICS_ERROR',
            message=f'Failed to retrieve metrics: {str(e)}',
            meta=Meta(extra={'http_status': 500})
        );
    }
}


def _parse_prometheus_text(raw_metrics: str) -> list[dict[str, any]] {
    import re;

    metrics_data: list[dict[str, any]] = [];
    current_metric: (dict[str, any] | None) = None;
    metric_line_re = re.compile(
        r'^([a-zA-Z_:][a-zA-Z0-9_:]*)((?:\{[^}]*\})?)[ \t]+(.+)$'
    );
    label_re = re.compile(r'([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"');

    for line in raw_metrics.split('\n') {
        line = line.strip();
        if not line {
            continue;
        }

        if line.startswith('# HELP ') {
            parts = line[7:].split(' ', 1);
            current_metric = {
                'name': parts[0],
                'description': parts[1] if len(parts) > 1 else '',
                'type': 'unknown',
                'values': []
            };
            metrics_data.append(current_metric);
        } elif line.startswith('# TYPE ') {
            parts = line[7:].split(' ', 1);
            if current_metric and parts[0] == current_metric['name'] {
                current_metric['type'] = parts[1] if len(parts) > 1 else 'unknown';
            }
        } elif line.startswith('#') {
            continue;
        } else {
            regex_match = metric_line_re.`match(line);
            if regex_match {
                metric_name = regex_match.group(1);
                labels_str = regex_match.group(2);
                value_str = regex_match.group(3);
                labels: dict[str, str] = {};
                if labels_str
                    and labels_str.startswith('{')
                    and labels_str.endswith('}') {
                    for lm in label_re.finditer(labels_str[1:-1]) {
                        labels[lm.group(1)] = lm.group(2);
                    }
                }
                value: (float | str) = value_str;
                try {
                    value = float(value_str);
                } except ValueError {
                    value = value_str;
                }
                found_metric: (dict[str, any] | None) = None;
                for m in metrics_data {
                    m_name: str = m['name'];
                    if m_name == metric_name or metric_name.startswith(m_name + '_') {
                        found_metric = m;
                        break;
                    }
                }
                suffix = '';
                if found_metric {
                    found_name: str = found_metric['name'];
                    if metric_name.startswith(found_name) {
                        suffix = metric_name[len(found_name):];
                    }
                    found_metric['values'].append(
                        {'labels': labels, 'value': value, 'suffix': suffix}
                    );
                } else {
                    metrics_data.append(
                        {
                            'name': metric_name,
                            'description': '',
                            'type': 'unknown',
                            'values': [{'labels': labels, 'value': value, 'suffix': ''}]
                        }
                    );
                }
            }
        }
    }
    return metrics_data;
}


def _classify_path(path: str) -> str {
    import from jaclang.scale.runtime.routing { GATEWAY_WELLKNOWN_SEGMENTS }
    head: str = path.strip('/').split('/')[0];
    if head == 'health' or head == 'healthz' {
        return 'health';
    }
    if head == 'admin' {
        return 'admin';
    }
    if head in GATEWAY_WELLKNOWN_SEGMENTS {
        return 'system';
    }
    return 'app';
}


def _sorted_buckets(acc: dict[float, float]) -> list[dict[str, float]] {
    return [{'le': le, 'count': acc[le]} for le in sorted(acc.keys())];
}


def _percentile_from_buckets(
    buckets: list[dict[str, float]], q: float
) -> dict[str, float | bool] {
    total: float = buckets[-1]['count'] if buckets else 0.0;
    if total <= 0 {
        return {'value': 0.0, 'over': False, 'known': False};
    }
    rank: float = q * total;
    lo: float = 0.0;
    lo_edge: float = 0.0;
    for b in buckets {
        upper: float = b['le'];
        count: float = b['count'];
        if count >= rank {
            if upper == float('inf') {
                return {'value': lo_edge, 'over': True, 'known': True};
            }
            span: float = count - lo;
            frac: float = (rank - lo) / span if span > 0 else 0.0;
            return {
                'value': round(lo_edge + frac * (upper - lo_edge), 6),
                'over': False,
                'known': True
            };
        }
        lo = count;
        lo_edge = upper;
    }
    return {'value': lo_edge, 'over': True, 'known': True};
}


def _format_seconds(secs: float) -> str {
    unit: str = 'ms' if secs < 1.0 else 's';
    value: float = round(secs * 1000.0, 6) if unit == 'ms' else round(secs, 6);
    text: str = str(int(value)) if value == int(value) else str(value);
    return text + unit;
}


def _range_label(lo: float, hi: float) -> str {
    lo_text: str = _format_seconds(lo);
    hi_text: str = _format_seconds(hi);
    lo_unit: str = 'ms' if lo_text.endswith('ms') else 's';
    hi_unit: str = 'ms' if hi_text.endswith('ms') else 's';
    if lo_unit == hi_unit {
        return lo_text[:-len(lo_unit)] + ' - ' + hi_text;
    }
    return lo_text + ' - ' + hi_text;
}


glob _LATENCY_CUTS: list[float] = [0.025, 0.1, 0.5, 2.5];


def _band_edges(edges: list[float]) -> list[float] {
    chosen: list[float] = [];
    for cut in _LATENCY_CUTS {
        nearest: float = edges[0];
        for le in edges {
            if abs(le - cut) < abs(nearest - cut) {
                nearest = le;
            }
        }
        if nearest not in chosen {
            chosen.append(nearest);
        }
    }
    return chosen;
}


def _latency_groups(buckets: list[dict[str, float]]) -> list[dict[str, str | int]] {
    edges: list[float] = [
        b['le']
        for b in buckets
        if b['le'] != float('inf')
    ];
    if not edges {
        return [];
    }
    counts: dict[float, float] = {b['le']: b['count'] for b in buckets};
    total: float = buckets[-1]['count'];
    out: list[dict[str, str | int]] = [];
    prev: float = 0.0;
    lo: float = 0.0;
    for (i, hi) in enumerate(_band_edges(edges)) {
        seen: float = counts[hi];
        label: str = ('under ' + _format_seconds(hi))
            if i == 0
            else _range_label(lo, hi);
        out.append({'label': label, 'count': int(seen - prev)});
        prev = seen;
        lo = hi;
    }
    out.append({'label': 'over ' + _format_seconds(lo), 'count': int(total - prev)});
    return out;
}


def _endpoint_sort_key(row: dict[str, any]) -> tuple[float, int] {
    return (-row['p95']['value'], -row['count']);
}


def _calculate_metrics_summary(metrics_data: list[dict[str, any]]) -> dict[str, any] {
    active: int = 0;
    rows: dict[str, dict[str, any]] = {};
    hist: dict[str, dict[float, float]] = {};

    for metric in metrics_data {
        name: str = metric['name'];
        if 'http_requests_total' in name {
            for v in metric['values'] {
                if not isinstance(v['value'], (int, float)) {
                    continue;
                }
                labels: dict[str, str] = v['labels'];
                method: str = labels.get('method', '?');
                path: str = labels.get('path', '?');
                key: str = method + ' ' + path;
                if key not in rows {
                    rows[key] = {
                        'method': method,
                        'path': path,
                        'kind': _classify_path(path),
                        'count': 0,
                        'server_errors': 0,
                        'client_errors': 0
                    };
                }
                row: dict[str, any] = rows[key];
                n: int = int(v['value']);
                row['count'] += n;
                status: str = labels.get('status_code', '');
                if status.startswith('5') {
                    row['server_errors'] += n;
                } elif status.startswith('4') {
                    row['client_errors'] += n;
                }
            }
        } elif 'requests_in_progress' in name {
            for v in metric['values'] {
                if isinstance(v['value'], (int, float)) {
                    active = int(v['value']);
                }
            }
        } elif 'request_duration_seconds' in name {
            for v in metric['values'] {
                if v['suffix'] != '_bucket'
                    or not isinstance(v['value'], (int, float)) {
                    continue;
                }
                labels: dict[str, str] = v['labels'];
                le_raw: str = labels.get('le', '');
                if not le_raw {
                    continue;
                }
                le: float = float('inf') if le_raw == '+Inf' else float(le_raw);
                key: str = labels.get('method', '?') + ' ' + labels.get('path', '?');
                acc: dict[float, float] = hist.setdefault(key, {});
                acc[le] = acc.get(le, 0.0) + float(v['value']);
            }
        }
    }

    endpoints: list[dict[str, any]] = [];
    for (key, row) in rows.items() {
        buckets = _sorted_buckets(hist.get(key, {}));
        endpoints.append(
            {
                'method': row['method'],
                'path': row['path'],
                'kind': row['kind'],
                'count': row['count'],
                'failed': row['server_errors'] + row['client_errors'],
                'p50': _percentile_from_buckets(buckets, 0.5),
                'p95': _percentile_from_buckets(buckets, 0.95)
            }
        );
    }
    endpoints.sort(key=_endpoint_sort_key);

    scopes: dict[str, dict[str, any]] = {};
    for scope_name in ('app', 'other', 'all') {
        requests: int = 0;
        server_errors: int = 0;
        client_errors: int = 0;
        merged: dict[float, float] = {};
        for (key, row) in rows.items() {
            is_app: bool = row['kind'] == 'app';
            if scope_name == 'app' and not is_app {
                continue;
            }
            if scope_name == 'other' and is_app {
                continue;
            }
            requests += row['count'];
            server_errors += row['server_errors'];
            client_errors += row['client_errors'];
            for (le, count) in hist.get(key, {}).items() {
                merged[le] = merged.get(le, 0.0) + count;
            }
        }
        buckets = _sorted_buckets(merged);
        scopes[scope_name] = {
            'requests': requests,
            'server_errors': server_errors,
            'client_errors': client_errors,
            'p50': _percentile_from_buckets(buckets, 0.5),
            'p95': _percentile_from_buckets(buckets, 0.95),
            'p99': _percentile_from_buckets(buckets, 0.99),
            'distribution': _latency_groups(buckets)
        };
    }

    return {'active_requests': active, 'scopes': scopes, 'endpoints': endpoints};
}
