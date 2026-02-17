#!/usr/bin/env python3
"""BasicStation API test runner.

Runs the full BasicStation test suite against a live device and reports
results. Can also run individual test scripts.

Usage:
    python3 test_runner.py                        # run all tests
    python3 test_runner.py --test test_09          # run one test
    python3 test_runner.py --host 192.168.1.1      # custom device IP
    python3 test_runner.py --list                  # list available tests
"""

import argparse
import os
import subprocess
import sys

from env_config import DEVICE_IP, DEVICE_PASS, DEVICE_USER, ROOT

TESTS_DIR = ROOT / "tests" / "basicstation"


def find_tests():
    """Find all test scripts in order."""
    if not TESTS_DIR.exists():
        return []
    return sorted(TESTS_DIR.glob("test_*.sh"))


def run_test(script, host, user, password):
    """Run a single test script."""
    env = os.environ.copy()
    env.update(
        {
            "DEVICE_IP": host,
            "DEVICE_USER": user,
            "DEVICE_PASS": password,
            "BASE_URL": f"https://{host}",
        }
    )
    result = subprocess.run(
        ["bash", str(script)],
        cwd=str(TESTS_DIR),
        env=env,
        capture_output=False,
    )
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description="BasicStation test runner")
    parser.add_argument("--host", default=DEVICE_IP, help="Device IP")
    parser.add_argument("--user", default=DEVICE_USER, help="SSH user")
    parser.add_argument("--test", help="Run specific test (partial match)")
    parser.add_argument("--list", action="store_true", help="List tests")
    args = parser.parse_args()

    tests = find_tests()
    if not tests:
        print(f"ERROR: No tests found in {TESTS_DIR}")
        sys.exit(1)

    if args.list:
        print(f"Available tests ({len(tests)}):")
        for t in tests:
            print(f"  {t.name}")
        return

    if args.test:
        tests = [t for t in tests if args.test in t.name]
        if not tests:
            print(f"No test matching '{args.test}'")
            sys.exit(1)

    print(f"Running {len(tests)} tests against {args.host}")
    print("=" * 60)

    passed = 0
    failed = 0
    failures = []

    for test in tests:
        ok = run_test(test, args.host, args.user, DEVICE_PASS)
        if ok:
            passed += 1
        else:
            failed += 1
            failures.append(test.name)

    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed out of {len(tests)}")
    if failures:
        print("\nFailed tests:")
        for f in failures:
            print(f"  ❌ {f}")
        sys.exit(1)
    else:
        print("\n✅ All tests passed!")


if __name__ == "__main__":
    main()
