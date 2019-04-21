from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re

def by_role_weight(roles, *args, **kw):
    '''
    Sorts dict items by role_weight value.  Default role_weight is 0.
    '''

    def sort_key(role_name):
        role = roles[role_name]
        if role == None:
            role = {}
        return role.get('role_weight', 0)

    return [{'name': a, 'config': roles[a]} for a in sorted(roles, key = sort_key)]

def to_folder_name(a, *args, **kw):
    ''' 
    Simple whitelist conversion allowing:
    
    * Letters (a-z A-Z)
    * Digits (0-9)
    * Underscore (_)
    * Hyphen (-)
    * Space
    * Dot (.)
    '''

    return re.sub(r'[^-a-zA-Z0-9_ .]', '_', a)

class FilterModule(object):
    '''
    dev-bootstrap jinja2 filters.
    '''

    def filters(self):
        return {
            'by_role_weight': by_role_weight,
            'to_folder_name': to_folder_name,
        }
