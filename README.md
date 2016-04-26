Docker Stats-Service Container
==============================

Introduction
------------

The docker container image build, test and release project for stats-service.

 - https://github.com/oisinmulvihill/stats-service


Build & Test
------------

I have a vagrant + Ubuntu 14.04 + docker environment I build and test in. From
this I build and test the stats-service container using the following::

    # change into the docker-stats-service check-out

    # A completely clean rebuild and test:
    $ NO_CACHE=--no-cache . ./jenkins.sh

The jenkins.sh script I use in my Jenkins CI build and verify the stats-service
when the code changes.
