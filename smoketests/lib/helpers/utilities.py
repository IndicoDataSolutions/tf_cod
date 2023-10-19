import os
import subprocess
import json
import time
import boto3
import logging
import configparser


class Process:
    def __init__(self, logger, account, region, name):
        self.logger = logger
        self.account = account
        self.region = region
        self.name = name
    
        logger = logging.getLogger(__name__)
        logger.setLevel(logging.DEBUG)

    def run(self, args, stdout, shell=False, hideLogs=False):
        if not hideLogs:
            self.logger.debug(" ".join(args))
        return subprocess.run(args, stdout=stdout, shell=shell)

