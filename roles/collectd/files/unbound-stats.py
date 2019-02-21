#!/usr/bin/python2

import collectd
import subprocess

STATS_NORESET = ["/usr/sbin/unbound-control", "stats_noreset"]


def read_callback():
    proc = subprocess.Popen(STATS_NORESET, stdout=subprocess.PIPE)
    return_code = proc.wait()

    if return_code > 0:
        collectd.error('unbound plugin: Error code collecting stats %d' % return_code)
    else:
        for line in proc.stdout:
            if line.startswith("time.") or line.startswith("total."):
                key, value = line.rstrip().split("=")
                val = collectd.Values(plugin='unbound')
                val.type = "gauge"
                val.type_instance = key.replace(".", "/")
                val.values = [value]
                val.dispatch()


collectd.register_read(read_callback)
