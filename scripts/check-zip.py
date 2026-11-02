#!/usr/bin/env python3
"""Independent inspection of an exported ZIP, without modifying its source."""
import json
import sys
import zipfile
from pathlib import PurePosixPath

with zipfile.ZipFile(sys.argv[1]) as archive:
    assert archive.testzip() is None, 'ZIP CRC failure'
    names = archive.namelist()
    assert 'training-v1.json' in names and 'README.txt' in names
    assert all(not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts for name in names)
    document = json.loads(archive.read('training-v1.json'))
    assert document['formatVersion'] == 1
    assert set(document['records']) <= {'goals','tasks','sessions','reflections','notes','bounties','competitions'}
    assert 'profile' not in document and 'access_token' not in document
    print(f'ZIP integrity and structure verified: {len(names)} files.')
