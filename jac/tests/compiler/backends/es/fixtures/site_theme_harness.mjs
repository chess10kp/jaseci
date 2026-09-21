import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const input = JSON.parse(readFileSync(new URL("./theme.json", import.meta.url)));
const source = input.module
    .replace(/^import .*;$/gm, "")
    .replace(/^export \{.*\};?$/gm, "");

for (const saved of [null, "light", "dark", "invalid"]) {
    for (const blocked of ["none", "read", "write"]) {
        let persisted = saved;
        const storage = {
            getItem() {
                if (blocked === "read") throw new Error("Storage denied");
                return persisted;
            },
            setItem(key, value) {
                if (blocked !== "none") throw new Error("Storage denied");
                persisted = value;
            },
        };
        const root = { style: {}, classList: {
            toggle(name, value) { root.dark = value; },
        } };
        vm.runInNewContext(input.bootstrap, {
            localStorage: storage, document: { documentElement: root },
        });
        const initial = blocked === "read" || saved !== "light";
        assert.equal(root.dark, initial);
        assert.equal(root.style.colorScheme, initial ? "dark" : "light");

        // Hook doubles expose subscriptions and state changes without React.
        let active;
        const context = vm.createContext({
            __getLocalStorage: () => storage.getItem("jac-theme"),
            __setLocalStorage: (key, value) => storage.setItem(key, value),
            dark_palette: () => ({}),
            light_palette: () => ({}),
            useJacState(value) {
                if (!active.state) {
                    const state = { val: value, set(next) { state.val = next; } };
                    active.state = state;
                }
                return active.state;
            },
            useEffect(effect) {
                if (!active.cleanup) active.cleanup = effect();
            },
        });
        vm.runInContext(source, context);
        const render = subscriber => {
            active = subscriber;
            return context.useTheme();
        };
        const shell = {}, navbar = {};
        assert.equal(render(shell).dark, initial);
        const first = render(navbar);
        assert.equal(first.dark, initial);
        first.toggle();
        assert.equal(render(shell).dark, !initial);
        assert.equal(render(navbar).dark, !initial);

        navbar.cleanup();
        const remounted = {};
        assert.equal(render(remounted).dark, !initial);
        // A handler from an earlier render must still toggle the current theme.
        first.toggle();
        assert.equal(render(shell).dark, initial);
        assert.equal(render(remounted).dark, initial);
        if (blocked === "none") {
            assert.equal(persisted, initial ? "dark" : "light");
        } else {
            assert.equal(persisted, saved);
        }
        shell.cleanup();
        remounted.cleanup();
    }
}
console.log("site theme checks passed");
