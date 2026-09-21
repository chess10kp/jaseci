"""Test combining consecutive has statements.

Consecutive has statements with the same modifiers (static, access, frozen)
should be combined into a single has statement with comma-separated vars.
"""

obj Person {
    """A person with multiple attributes."""
    has name: str,
        age: int,
        email: str;

    has:pub address: str,
        phone: str;
    has city: str = "Unknown";

    def greet -> str {
        return "Hello, " + self.name;
    }
}

obj Config {
    """Config with static has statements."""
    static has DEBUG: bool = False,
        VERSION: str = "1.0",
        MAX_RETRIES: int = 3;
}
