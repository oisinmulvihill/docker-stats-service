#!/usr/bin/env python
import os
from jinja2 import Template

output_file = os.environ.get("CONFIG")
print "server configuration file is '{}'".format(output_file)

with open("/etc/server.ini.template", "r") as fd:
    svr_conf = Template(fd.read())
    with open(output_file, "w") as w_fd:
        print "rendering server template"
        try:
            w_fd.write(svr_conf.render(**os.environ))
        except Exception as e:
            print "failed to render configuration: {}".format(e)
