# Jac-client open audit findings

Remaining items from the mobile / auto port review (not an exhaustive QA sign-off).

## Test / automation

- **`test_cli.jac` - "start dev with client does initial compilation"**: Asserts a **watchdog** auto-install line; if `watchdog` is already installed, the assertion can fail even when dev succeeds. Consider tightening the test or the product messages.

- **Running `pytest jac-client` (entire package tree)**: Can collect **duplicate** tests from `jac-client/build/lib/...` if a build is present. Prefer `pytest jac-client/jac_client/tests` (or ignore `build/`).

- **Full `pytest jac-client` on a single dev machine**: Some E2E cases failed with missing all-in-one assets, missing modules, or profile TOML copy assertions. Treat as **environment/checkout/CI parity** until reproduced under CI’s setup (Python 3.12, editable installs, Node/Bun, Playwright as required).
