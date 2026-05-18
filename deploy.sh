#!/bin/bash
set -e

TARGET="${1:-cloudflare}"

case "$TARGET" in
  github)
    # GitHub Pages serves at https://<user>.github.io/rustweek-2026-wasm-myths/
    REPO_PATH="${REPO_PATH-/rustweek-2026-wasm-myths}"
    ;;
  cloudflare)
    # Cloudflare Workers serves at the root of the (sub)domain.
    REPO_PATH="${REPO_PATH-}"
    ;;
  *)
    echo "Usage: $0 [github|cloudflare]" >&2
    exit 1
    ;;
esac

HEAD_HBS="theme/head.hbs"

restore_head() {
  [[ -f "$HEAD_HBS.bak" ]] && mv "$HEAD_HBS.bak" "$HEAD_HBS"
}
trap restore_head EXIT

# Build JS with the deploy base path. Vite needs a leading slash, so default
# to "/" when REPO_PATH is empty.
(cd javascript && npx vite build --base "${REPO_PATH:-}/js/")

# Patch head.hbs for the deploy path, build, then restore.
sed -i.bak "s|src=\"/js/|src=\"${REPO_PATH}/js/|g" "$HEAD_HBS"
mdbook build --dest-dir book-dist
mv "$HEAD_HBS.bak" "$HEAD_HBS"

case "$TARGET" in
  github)
    cd book-dist
    git add -A
    git commit -m "deploy"
    git push origin HEAD:gh-pages -f
    cd ..
    ;;
  cloudflare)
    # COOP/COEP for SharedArrayBuffer (wasm threading appendix).
    cp _headers book-dist/_headers
    npx wrangler deploy
    ;;
esac
