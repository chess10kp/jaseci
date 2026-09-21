obj SizeProtocol {
    def __len__ -> int {
        return 0;
    }
}

obj Runnable(Protocol) {
    def run {}
}

obj Thread {
    def run {
        print("Thread Running");
    }
}

obj Foo {}

def run(runnable: Runnable) {
    runnable.run();
}

glob
     # len() expect protocol with __len__ method
     lst: list[int] = [1, 2, 3];
with entry {
    len(lst);  # <-- Ok
    len(SizeProtocol());  # <-- OK
    len(Foo());  # <-- Error

    # run() expect protocol with run method
    run(Thread());  # <-- OK
    run(Foo());  # <-- Error
}
