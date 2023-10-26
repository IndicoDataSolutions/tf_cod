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
        self.command = None
    
    def run(self, args, stdout, shell=False, hideLogs=False):
        if not hideLogs:
            print(" ".join(args))
        self.command = args
        return subprocess.run(args, stdout=stdout, shell=shell)

    def parseResult(self, output, field_name):
      if output.returncode == 0 and len(output.stdout) > 0:
        try:
          results = json.loads(output.stdout)[field_name]
          return results
        except Exception as e:
          print(f"Exception: {e}")
          assert output.returncode != 0, f"ERROR: Parsing json results {output.stdout} from {self.command}"
      else:
        print(f"ERROR: Return code: {output.returncode}")       
        print(output.stdout)
        assert output.returncode != 0, f"Bad returncode: {output.returncode}: {output.stdout}"
    
    def getTag(self, tags, name, keyName="Tag", keyValue="Value"):
      for tag in tags:
        if keyName in tag and tag[keyName] == name:
          return tag[keyValue]
      return None
    
    def searchTags(self, name, tags, keyName="Tag", keyValue="Value"):
        return [
            element
            for element in tags
            if keyName in element
            and element[keyName] == "indico/cluster"
            and element[keyValue] == name
        ]
