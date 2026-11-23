#!/bin/sh
# Type checks src and tests with luau-lsp, the same way locally and in CI.
# luau-lsp comes from rokit.toml; its Roblox types are fetched once for that
# version into .luau-lsp/ (not tracked).
set -eu
cd "$(dirname "$0")/.."

version=$(luau-lsp --version)
cache=.luau-lsp/$version
mkdir -p "$cache"

if [ ! -s "$cache/globalTypes.d.luau" ]; then
	curl -fsSL --retry 3 --retry-all-errors -o "$cache/globalTypes.d.luau" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$version/scripts/globalTypes.d.luau"
fi

# TestEZ's globals, loosely typed like the specs that use them.
cat > "$cache/testez.d.luau" <<'EOF'
declare function describe(name: string, fn: () -> ()): ()
declare function it(name: string, fn: () -> ()): ()
declare function beforeEach(fn: () -> ()): ()
declare function afterEach(fn: () -> ()): ()
declare function beforeAll(fn: () -> ()): ()
declare function afterAll(fn: () -> ()): ()
declare function expect(value: any): any
EOF

rojo sourcemap test.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json \
	--definitions=@roblox="$cache/globalTypes.d.luau" \
	--definitions=@testez="$cache/testez.d.luau" \
	src tests
