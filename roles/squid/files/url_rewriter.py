#!/usr/local/bin/python

import re
import sys
import urllib
import urlparse

to_https = frozenset([
    '123-reg.co.uk', 'www.123-reg.co.uk',
    'amazon.co.uk', 'www.amazon.co.uk',
    'amazon.com', 'aws.amazon.com', 'www.amazon.com',
    'bbc.co.uk', 'www.bbc.co.uk',
    'buddyns.com', 'www.buddyns.com',
    'cdnjs.com', 'www.cdnjs.com',
    'circleci.com', 'www.circleci.com',
    'code.jquery.com',
    'cwjobs.co.uk', 'www.cwjobs.co.uk',
    'fast.com', 'www.fast.com',
    'fastmail.com', 'www.fastmail.com',
    'github.com', 'pages.github.com', 'www.github.com',
    'gitlab.com', 'www.gitlab.com',
    'google.co.uk', 'www.google.co.uk',
    'google.com', 'www.google.com',
    'guardian.co.uk', 'www.guardian.co.uk',
    'icloud.com', 'www.icloud.com',
    'imgur.com', 'i.imgur.com', 'p.imgur.com', 's.imgur.com',
    'independent.co.uk', 'www.independent.co.uk',
    'jsdelivr.com', 'www.jsdelivr.com',
    'letsencrypt.org', 'www.letsencrypt.org',
    'linkedin.com', 'www.linkedin.com',
    'marc.info', 'www.marc.info',
    'meetup.com', 'www.meetup.com',
    'nytimes.com', 'www.nytimes.com',
    'openbsd.org', 'www.openbsd.org',
    'paypal.co.uk', 'www.paypal.co.uk',
    'paypal.com', 'www.paypal.com',
    'pornhub.com', 'www.pornhub.com',
    'reddit.com', 'www.reddit.com',
    'statuscake.com', 'www.statuscake.com',
    'theguardian.com', 'www.theguardian.com',
    'theregister.co.uk', 'www.theregister.co.uk',
    'unpkg.com',  # no www.
    'vultr.com', 'www.vultr.com',
    'website.ws', 'www.website.ws',
    'wikipedia.org', 'en.wikipedia.org', 'www.wikipedia.org',
    'ycombinator.com', 'news.ycombinator.com',
])

to_direct = re.compile(r"""
    http:// (?:
        www.google.(?:co\.uk|com)/url \? (?:.+&)? url=([^&]+) (?:&.*)
    )
""", re.I | re.X)


def rewrite(line):
    tokens = line.split(' ')
    url = tokens[0]

    match = to_direct.match(url)
    if match:
        return 'OK status=307 url="' + urllib.unquote(match.group(1)) + '"'

    if urlparse.urlsplit(url).hostname in to_https:
        return 'OK status=307 url="https:' + url[5:] + '"'

    return 'OK'


def main():
    while True:
        line = sys.stdin.readline().strip()
        sys.stdout.write(rewrite(line) + '\n')
        sys.stdout.flush()


if __name__ == "__main__":
    main()
