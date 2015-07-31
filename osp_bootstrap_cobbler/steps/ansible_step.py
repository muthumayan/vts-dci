__author__ = 'brdemers'

import step
import ansible.runner
import ansible.inventory
import ansible.constants
from ansible.playbook import PlayBook
from ansible import callbacks
from ansible import utils

class AnsibleStep(step.Step):



    def execute(self, kargs):
        hosts = [kargs["director_node_ssh_ip"]]

        # ansible.constants.DEFAULT_HOST_LIST = hosts
        ansible.constants.HOST_KEY_CHECKING = False


        inventory = ansible.inventory.Inventory(hosts)

        stats = callbacks.AggregateStats()
        # utils.VERBOSITY = 3
        playbook_cb = callbacks.PlaybookCallbacks(verbose=utils.VERBOSITY)
        runner_cb = callbacks.PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)

        extra_vars = {}
        extra_vars.update(kargs)
        # extra_vars["proxy_env"] = { "ftp_proxy": kargs["ftp_proxy"],
        #                             "http_proxy": kargs["http_proxy"],  # added to support BXB, not tested in SJ
        #                             "https_proxy": kargs["https_proxy"]  # added to support BXB, not tested in SJ
        #                           }

        pb = ansible.playbook.PlayBook(
            playbook="ansible/osp-director.yml",
            remote_user=kargs["director_node_ssh_username"],
            stats=stats,
            callbacks=playbook_cb,
            runner_callbacks=runner_cb,
            inventory=inventory,
            extra_vars= extra_vars
        )

        result = pb.run()
        print result


        