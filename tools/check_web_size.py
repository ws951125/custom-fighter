#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

WASM_BUDGET = 42_000_000
PCK_BUDGET = 1_000_000
TOTAL_BUDGET = 44_000_000


def file_size(path: Path) -> int:
    if not path.is_file():
        raise SystemExit(f"Missing required Web build file: {path}")
    return path.stat().st_size


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    wasm = file_size(root / "index.wasm")
    pck = file_size(root / "index.pck")
    total = sum(path.stat().st_size for path in root.rglob("*") if path.is_file())

    service_workers = sorted(root.glob("*service*worker*.js"))
    manifests = sorted(root.glob("*.manifest.json"))

    print(
        "WEB_SIZE_REPORT "
        f"wasm={wasm} pck={pck} total={total} "
        f"service_workers={len(service_workers)} manifests={len(manifests)}"
    )

    failures: list[str] = []
    if wasm > WASM_BUDGET:
        failures.append(f"index.wasm {wasm} > budget {WASM_BUDGET}")
    if pck > PCK_BUDGET:
        failures.append(f"index.pck {pck} > budget {PCK_BUDGET}")
    if total > TOTAL_BUDGET:
        failures.append(f"Web output {total} > budget {TOTAL_BUDGET}")
    if not service_workers:
        failures.append("PWA enabled but no service worker was exported")

    if failures:
        for failure in failures:
            print(f"WEB_SIZE_BUDGET_FAIL: {failure}", file=sys.stderr)
        return 1

    print("WEB_SIZE_BUDGET_PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
