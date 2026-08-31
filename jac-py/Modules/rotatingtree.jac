# Interpreter-oracle shim: ``@__jac_value__`` is a c2jac arch marker, not a
# runtime name. Native lower may skip these objs; server codespace needs this.
def __jac_value__(x: any) -> any {
    return x;
}

@__jac_value__
obj rotating_tree_enum_fn {
    def call(`node: rotating_node_t, arg: object) -> int {
        return 0;
    }
}

@__jac_value__
obj rotating_node_t {
    has key: object = object(),
        left: (rotating_node_t | None) = None,
        right: (rotating_node_t | None) = None;
}

glob random_value: int = 1,
     random_stream: int = 0,
     random_mutex: int = 0;

def random_lock {
    ;
    random_mutex = 1;
}

def random_unlock {
    ;
    random_mutex = 0;
}

def randombits(bits: int) -> int {
    ;
    result: int = 0;
    random_lock();
    if (random_stream < (1 << bits)) {
        random_value *= 1082527;
        random_stream = random_value;
    }

    result = random_stream & ((1 << bits) - 1);
    random_stream >>= bits;
    random_unlock();
    return result;
}

def RotatingTree_RandomBits(bits: int) -> int {
    return randombits(bits);
}

def RotatingTree_Add(`root: (rotating_node_t | None), `node: rotating_node_t) {
    while (`root != None) {
        if (`node.key < `root.key) {
            `root = `root.left;
        } else {
            `root = `root.right;
        }
    }

    `node.left = None;
    `node.right = None;
    `root = `node;
}

def RotatingTree_Get(`root: (rotating_node_t | None), key: object) -> (rotating_node_t | None) {
    if (randombits(3) != 4) {
        `node: (rotating_node_t | None) = `root;
        while (`node != None) {
            if (`node.key == key) {
                return `node;
            }
            if (key < `node.key) {
                `node = `node.left;
            } else {
                `node = `node.right;
            }
        }

        return None;
    } else {
        pnode: object = `root;
        `node: (rotating_node_t | None) = pnode;
        next: (rotating_node_t | None) = None;
        rotate: int = 0;
        if (`node == None) {
            return None;
        }
        cur: rotating_node_t = `node;  # jac:ignore[E1001]
        while 1 {
            if (cur.key == key) {
                return cur;
            }
            rotate = not randombits(1);
            if (key < cur.key) {
                next = cur.left;
                if (next == None) {
                    return None;
                }
                if rotate {
                    cur.left = next.right;
                    next.right = cur;
                    pnode = next;
                } else {
                    pnode = cur.left;
                }
            } else {
                next = cur.right;
                if (next == None) {
                    return None;
                }
                if rotate {
                    cur.right = next.left;
                    next.left = cur;
                    pnode = next;
                } else {
                    pnode = cur.right;
                }
            }

            cur = next;  # jac:ignore[E1001]
        }
    }
}

def RotatingTree_Enum(
    `root: (rotating_node_t | None), enumfn: rotating_tree_enum_fn, arg: object
) -> int {
    result: int = 0;
    `node: (rotating_node_t | None) = None;
    while (`root != None) {
        result = RotatingTree_Enum(`root.left, enumfn, arg);
        if (result != 0) {
            return result;
        }
        `node = `root.right;
        result = enumfn.call(`root, arg);
        if (result != 0) {
            return result;
        }
        `root = `node;
    }

    return 0;
}
