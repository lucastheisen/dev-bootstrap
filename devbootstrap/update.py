import os

"""
Provides updates for devbootstrap.
"""

URL = 'https://raw.githubusercontent.com/lucastheisen/dev-bootstrap/master/bootstrap.sh'

def update(args):
    """
    Use execl to replace current process, then use the standard `curl | bash`
    approach to update in case the update process has changed server side
    since the last update (as opposed to simply running `bootstrap.sh`).
    """
    os.execl(
        '/bin/bash',
        '/bin/bash',
        '-c',
        'curl {} | /bin/bash'.format(URL))
