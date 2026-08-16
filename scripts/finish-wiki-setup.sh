#!/usr/bin/env bash
# Run this AFTER a human has created the first wiki page via the GitHub web UI
# (visit https://github.com/gavmor/room-solver/wiki and click "Create the first page" —
# title/content don't matter, this script overwrites Home.md anyway).
#
# GitHub's wiki git backend (room-solver.wiki.git) does not exist until at least
# one page has been saved through the web UI; there is no API workaround
# (confirmed via github.com/orgs/community/discussions/179872, Nov 2025 — still
# unresolved as of this writing). Browser automation would also work but requires
# an authenticated GitHub session this environment doesn't have.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

git clone git@github.com:gavmor/room-solver.wiki.git /tmp/room-solver-wiki-push
cp wiki-seed/*.md /tmp/room-solver-wiki-push/
git -C /tmp/room-solver-wiki-push add .
git -C /tmp/room-solver-wiki-push commit -m "Seed reference pages: WFC, Monoceros, Grasshopper, Revit, Prolog, AC-3/CSP"
git -C /tmp/room-solver-wiki-push push origin HEAD:master

cd "$repo_root"
git submodule add git@github.com:gavmor/room-solver.wiki.git wiki
git add .gitmodules wiki
git commit -m "Add wiki as submodule at wiki/"

echo "Done. Remove wiki-seed/ and this script in a follow-up commit if desired."
