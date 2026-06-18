"""JacSX portable UI primitives — the ``@jac/ui`` module (walking skeleton).

Skeleton surface: ``View`` and ``Text`` only. Both re-export the React Native
primitives unchanged ("keep everything the same as React Native"). The
platform switch is the bundler's job, NOT this module's:

* native (``--client react-native`` / ``expo``): ``react-native`` resolves to
  the real RN package, so ``View``/``Text`` are RN components rendered by the
  native view system.
* web (default, no ``--client``): the bundler aliases ``react-native`` ->
  ``react-native-web``, so the *same* import lowers to RNW — ``View`` renders
  as a ``<div>`` and ``Text`` as a ``<span>`` in the DOM.

Apps import from the bare ``@jac/ui`` specifier, which the bundler aliases to
the compiled ``client_ui.js`` (mirrors how ``@jac/runtime`` is wired). This is
the *only* sanctioned UI import surface in JacSX mode — see the validation
pass (rejects raw ``div``/``span``/etc.) for the enforcement half.

Lowering table (see docs/jacsx/primitive-contract.md §3):
    View -> react-native View   / react-native-web View  (<div>)
    Text -> react-native Text   / react-native-web Text   (<span>)
"""

import from 'react-native' { View as RNView, Text as RNText }

# Block-level ``glob:pub`` so every alias is exported, matching the native
# runtime's export convention (the per-name ``:pub`` form silently drops
# aliases whose RHS is an imported binding — see client_runtime_native.cl.jac).
glob:pub View = RNView,
     Text = RNText;
