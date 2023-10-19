import os
import subprocess
import json
import time
import boto3
import logging
import configparser


class Process:
    def __init__(self, account, region, name):
        self.account = account
        self.region = region
        self.name = name
    
    def run(self, args, stdout, shell=False, hideLogs=False):
        if not hideLogs:
            print(" ".join(args))
        return subprocess.run(args, stdout=stdout, shell=shell)

