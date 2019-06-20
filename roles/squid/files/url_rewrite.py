#!/usr/bin/env python3

import re
import sys
import urllib

g = re.compile(
    r"^https?://www\.google\.com/url\?(?:.+=.*&)*url=(?P<url>.+?)(?:&.+=.*)*$"
)


def main():
    request = sys.stdin.readline()
    while request:
        [ch_id, url, method] = request.split()
        m = g.match(url)
        if m:
            url = urllib.unquote(m.group("url"))
            response = "%s OK status=301 url=%s\n" % (ch_id, url)
        else:
            response = "%s OK\n" % ch_id
        sys.stdout.write(response)
        sys.stdout.flush()
        request = sys.stdin.readline()


if __name__ == "__main__":
    main()
