import asyncio;
import from jaclang.server.serving.datatypes { Request }


def authed(fn: Callable[..., any]) -> Callable[..., any] {
    async def handler(request: Request, **kwargs: any) -> any {
        return fn(Authorization=request.headers.get('Authorization'), **kwargs);
    }
    return handler;
}

def authed_thread(fn: Callable[..., any]) -> Callable[..., any] {
    async def handler(request: Request, **kwargs: any) -> any {
        return await asyncio.to_thread(
            fn, Authorization=request.headers.get('Authorization'), **kwargs
        );
    }
    return handler;
}
