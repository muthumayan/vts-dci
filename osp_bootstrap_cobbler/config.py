__author__ = 'brdemers'

import logging
import ConfigParser
import os

class Config(object):

    logger = logging.getLogger("config")

    def __init__(self, config_file, location='sj'):
        self.config = self._read_config(config_file, location)

    def get(self, key):
        return self.config.get(key)

    def _read_config(self, config_file, location):

        module_dir = os.path.dirname(os.path.abspath(__file__))
        common_conf_dir = os.path.join(module_dir, 'conf_common')
        location_conf = os.path.join(common_conf_dir, location + '.conf')
        base_conf = os.path.join(common_conf_dir, 'base.conf')
        user_conf = os.path.join(os.path.expanduser('~'), '.osp7-installer', 'osp7.conf')

        config_parser = ConfigParser.SafeConfigParser()
        config_files_to_read = [base_conf, location_conf, user_conf, config_file]
        actual_config_files = config_parser.read(config_files_to_read)
        self.logger.debug("Config loaded from files: " + str(actual_config_files))
        config = {}

        for section in config_parser.sections():
            options = config_parser.options(section)
            section_dict = {}
            for option in options:
                value = config_parser.get(section, option).strip()
                if value == "True":
                    value = True
                elif value == "False":
                    value = False
                elif value.isdigit():
                    value = int(value)
                elif value.startswith('[') or value.startswith('{'):
                    value = eval(value)

                section_dict[option] = value
            config[section] = section_dict

        self.logger.debug("config: {}".format(config))
        return config
