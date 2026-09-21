# Import walker from server module
import from .separated { create_todo }

def:pub app -> JsxElement {
    has todos: list = [],
        input: str = "";

    # Event Handler
    async def addTodo -> None {
        if not input.strip() {
            return;
        }
        response = root spawn create_todo(text=input.strip());
        new_todo = response.reports[0][0];
        todos = todos + [new_todo];
        input = "";

        def foo {}
    }

    return
        <div>
            <h2>My Todos</h2>
            <input
                value={input}
                onChange={lambda (e: any) { setInput(e.target.value); }}
                onKeyPress={lambda (e: any) { if e.key == "Enter" { addTodo(); }}}
            />
            <button onClick={addTodo}>Add Todo</button>
            <div>
                {[
                    <div key={jid(todo)}>
                        <span>{todo.text}</span>
                    </div> for todo in todos
                ]}
            </div>
        </div>;
}
