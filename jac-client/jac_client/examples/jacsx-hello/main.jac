"""JacSX walking skeleton — View + Text only, one source, two platforms.

The whole point of this example is to prove the JacSX pipeline end to end on
the smallest possible surface before the other primitives are built:

    jac start main.jac                       # web   -> View=<div>,  Text=<span>  (via react-native-web)
    jac start main.jac --client react-native # native -> View/Text are real RN components

There is no ``div``/``span``/``button`` here on purpose — JacSX apps import the
portable primitives from ``@jac/ui`` and never touch raw HTML tags. The bundler
aliases ``@jac/ui`` to the compiled ``client_ui.js`` and (on web only) rewrites
``react-native`` -> ``react-native-web``.
"""

cl {
    import from "@jac/ui" { View, Text }

    def:pub app -> JsxElement {
        return
            <View
                style={{
                    padding: 24,
                    backgroundColor: "#1e1e2f",
                    flex: 1,
                    justifyContent: "center",
                    alignItems: "center"
                }}
            >
                <Text
                    style={{
                        fontSize: 22,
                        fontWeight: "bold",
                        marginBottom: 8,
                        color: "#ffffff"
                    }}
                >
                    Hello JacSX
                </Text>
            </View>;
    }
}
