#!/usr/bin/env python3
"""Fetch a URL and write the response body to stdout or a file (POC helper).

Uses only the stdlib. HTML is not cleaned; for heavy pages prefer saving and
summarizing in Open WebUI or a dedicated extractor.

Examples:
  python3 scripts/fetch_url.py https://example.com -o ~/vap-sandbox-0/page.html
  python3 scripts/fetch_url.py https://example.com | head
"""

from __future__ import annotations

import argparse
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch URL body to stdout or a file.")
    parser.add_argument("url", help="http(s) URL")
    parser.add_argument(
        "-o",
        "--output",
        metavar="PATH",
        help="Write body to this file (UTF-8); default is stdout",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=30.0,
        help="Socket timeout in seconds (default: 30)",
    )
    args = parser.parse_args()

    req = Request(
        args.url,
        headers={"User-Agent": "local-ai-fetch/1.0"},
        method="GET",
    )
    try:
        with urlopen(req, timeout=args.timeout) as resp:
            data = resp.read()
    except HTTPError as e:
        print(f"HTTP error: {e.code} {e.reason}", file=sys.stderr)
        return 1
    except URLError as e:
        print(f"URL error: {e.reason}", file=sys.stderr)
        return 1

    text = data.decode("utf-8", errors="replace")
    if args.output:
        path = args.output
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        print(path, file=sys.stderr)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
