#!/usr/local/bin/python

import re
import sys
import urllib

to_direct = re.compile(r"""
    http://www.google.(?:co\.uk|com)/url\?(?:.+&)?url=([^&]+)(?:&.*)
""", re.I | re.X)

to_https = re.compile(r"""
    http://(?:(?:
        (?:www\.)?(?:
            amazon\.(?:co\.uk|com) |
            bbc\.co\.uk            |
            buddyns\.com           |
            cwjobs\.co\.uk         |
            fastmail\.com          |
            google\.(?:co\.uk|com) |
            guardian\.co\.uk       |
            icloud\.com            |
            marc\.info             |
            meetup\.com            |
            openbsd\.org           |
            paypal\.(?:co\.uk|com) |
            reddit\.com            |
            theguardian\.com       |
            website\.ws
        )                          |
        (?:en\.)?wikipedia\.org    |
        news\.ycombinator\.com
    ))(?:/.*)
""", re.X)

def rewrite(line):
    tokens = line.split(' ')
    url = tokens[0]
    match = to_direct.match(url)
    if match:
        return 'OK status=307 url="' + urllib.unquote(match.group(1)) + '"'
    elif to_https.match(url.lower()):
        return 'OK status=307 url="https:' + url[5:] + '"'
    else:
        return 'OK'

while True:
    line = sys.stdin.readline().strip()
    sys.stdout.write(rewrite(line) + '\n')
    sys.stdout.flush()
