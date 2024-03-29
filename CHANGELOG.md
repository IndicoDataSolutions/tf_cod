# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
## [IPA-6.0.0]
- Update cluster default version to 1.23, 1.24 may also be upgraded to.
- Use AWS add-on aws-ebs-csi-driver
## [1.0.14]
### Updates
- Allow using either FSX or EFS
- Updated to use eks terraform module v18 from v17.

## [1.0.2]
### Updates
- Fixed snapshot save/restore to use proper account name
- Updated applications 

## [1.0.1]

### Updates
- Removed un-necessary users
- Added variable `ipa_pre_reqs_version` 
- Added variable `ipa_crds_version`
- Updated IPA chart to 0.1.2

## [1.0.0]
- Initial Release
- Default IPA Pre-reqs to 0.1.1
- Default IPA CRDs to 0.1.0
