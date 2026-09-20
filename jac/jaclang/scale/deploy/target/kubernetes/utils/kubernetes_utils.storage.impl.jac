import from jaclang.scale._optdeps.kubernetes { client }

impl parse_storage_quantity(quantity: str) -> int {
    q = quantity.strip();
    if q == '' {
        raise ValueError('Storage quantity cannot be empty.');
    }
    suffixes_binary: dict[str, int] = {
        'Ki': 1024,
        'Mi': 1024 ** 2,
        'Gi': 1024 ** 3,
        'Ti': 1024 ** 4,
        'Pi': 1024 ** 5,
        'Ei': 1024 ** 6
    };
    suffixes_decimal: dict[str, int] = {
        'k': 1000,
        'M': 1000 ** 2,
        'G': 1000 ** 3,
        'T': 1000 ** 4,
        'P': 1000 ** 5,
        'E': 1000 ** 6
    };
    for (suffix, multiplier) in suffixes_binary.items() {
        if q.endswith(suffix) {
            number_part = q[:-len(suffix)].strip();
            if number_part == '' {
                raise ValueError(
                    f"Storage quantity '{quantity}' is missing a numeric component."
                );
            }
            return int(number_part) * multiplier;
        }
    }
    for (suffix, multiplier) in suffixes_decimal.items() {
        if q.endswith(suffix) {
            number_part = q[:-len(suffix)].strip();
            if number_part == '' {
                raise ValueError(
                    f"Storage quantity '{quantity}' is missing a numeric component."
                );
            }
            return int(number_part) * multiplier;
        }
    }
    try {
        return int(q);
    } except ValueError {
        raise ValueError(
            f"Unrecognized storage quantity '{quantity}'. "
            f"Use a plain integer (bytes) or a suffix: Ki, Mi, Gi, Ti, Pi, Ei, k, M, G, T, P, E."
        );
    }
}

impl resize_pvc_if_needed(
    core_v1: client.CoreV1Api, namespace: str, pvc_name: str, desired_size: str
) -> None {
    try {
        pvc = core_v1.read_namespaced_persistent_volume_claim(pvc_name, namespace);
    } except ApiException as exc {
        if exc.status == 404 {
            return;
        }
        raise;
    }
    current_size_str = pvc.spec.resources.requests.get('storage', '0');
    current_bytes = parse_storage_quantity(current_size_str);
    desired_bytes = parse_storage_quantity(desired_size);

    if desired_bytes < current_bytes {
        raise ValueError(
            f"Cannot shrink PVC '{pvc_name}': desired size '{desired_size}' is "
            f"smaller than current size '{current_size_str}'. "
            f"Decrease of PVC size is not supported."
        );
    }
    if desired_bytes == current_bytes {
        return;
    }
    patch = {'spec': {'resources': {'requests': {'storage': desired_size}}}};
    core_v1.patch_namespaced_persistent_volume_claim(pvc_name, namespace, patch);
}
