"""Test async for loop parsing."""

def demo_async_for {
    async for item in aiter() {
        print(item);
    }
    async for item in aiter() {
        print(item);
    } else {
        print("empty");
    }
}
