def app -> JsxElement {
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

        def foo { }
    }

    return
        <div>
            <h2>My Todos</h2>
            <input
                value={input}
                onChange={lambda e: Any { input = e.target.value;}}
                onKeyPress={lambda e: Any { if e.key == "Enter" { addTodo(); }}}
            />
            <button onClick={addTodo}>Add Todo</button>
            <div>
                {todos.map(
                    lambda todo: Any -> Any { return
                        <div key={todo._jac_id}>
                            <span>{todo.text}</span>
                        </div>; }
                )}
            </div>
        </div>;
}
