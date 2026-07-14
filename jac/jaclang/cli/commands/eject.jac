import from jaclang.cli.command { ArgKind }
import from jaclang.cli.registry { get_registry }

glob registry = get_registry();

def eject(source: str = ".", output: str = "", force: bool = False) -> int;
