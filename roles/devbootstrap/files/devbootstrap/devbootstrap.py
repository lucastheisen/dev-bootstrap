#!/usr/bin/python

import argparse
from functools import reduce
import sys
import config

command_config_edit = dict(
    description='open the current configuration in an editor',
    function=config.edit,
    name='edit')

command_config_set = dict(
    args=[
        dict(
            name='name',
            description='property name (ex: role.test.foo)',
            required=True),
        dict(
            name='value',
            description="property value (json string, '' results in delete, '\"\"' results in empty string)",
            required=True)
    ],
    description='set a configuration value',
    function=config.set_value,
    name='set')

command_config_view = dict(
    description='prints the current configuration',
    function=config.view,
    name='view')

command_config = dict(
    description='view/modify bootstrap configuration',
    name='config',
    subcommands=[command_config_edit, command_config_set, command_config_view])

command_update = dict(
    description='runs bootstrap update',
    name='update')

command_main = dict(
    description='manages bootstrap',
    name='devbootstrap.py',
    subcommands=[command_config, command_update])

def _parser(command, ancestors):
    parser = argparse.ArgumentParser(
        description=command.get('description', None),
        usage=_usage(command, ancestors))

    if 'subcommands' in command:
        parser.add_argument(
            'command',
            choices=[i['name'] for i in command['subcommands']],
            help="Subcommand")
    elif 'args' in command:
        for arg in command['args']:
            parser.add_argument(
                arg['name'],
                help=arg['description'])

    return parser

def _subcommand_usage(subcommands):
    usage = 'commands:\n'
    
    max_name_length = max([len(i['name']) for i in subcommands])
    for subcommand in subcommands:
        usage = '{}\n  {:<{}}  {}'.format(usage, subcommand['name'], max_name_length, subcommand['description'])

    return usage

def _usage(command, ancestors):
    usage = ' '.join([i['name'] for i in ancestors] + [command['name']])

    subcommand_usage = None
    if 'subcommands' in command:
        usage = usage + ' <command>'

        subcommand_usage = _subcommand_usage(command['subcommands'])

    if 'args' in command:
        for arg in command['args']:
            if 'required' in arg and arg['required']:
                usage = '%s <%s>' % (usage, arg['name'])
            else:
                usage = '%s [<%s>]' % (usage, arg['name'])

    if subcommand_usage:
        usage = '%s\n\n%s' % (usage, subcommand_usage)

    return usage

def _run(command, args, ancestors=[]):
    parser = _parser(command, ancestors)

    if 'subcommands' in command:
        parsed_args = parser.parse_args(args[0:1])
        subcommand = [i for i in command['subcommands'] if i['name'] == parsed_args.command]
        return _run(subcommand[0], args[1:], ancestors + [command])

    parsed_args = parser.parse_args(args)

    if 'function' in command:
        command['function'](parsed_args)
    else:
        parser.print_help()
        print("%s: error: undefined <function> for command [%s]" % (ancestors[0]['name'], command['name']))
        return 1

def main():
    exit_code = _run(command_main, sys.argv[1:])
    if exit_code:
        exit(exit_code)

if __name__ == '__main__':
    main()
