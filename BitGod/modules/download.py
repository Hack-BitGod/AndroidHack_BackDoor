import os

from ghost.lib.module import Module


class GhostModule(Module):
    def __init__(self):
        super().__init__()

        self.details.update({
            'Category': "manage",
            'Name': "download",
            'Authors': [
                'BitGod'
            ],
            'Description': "Download file from device.",
            'Usage': "download <remote_file> <local_path>",
            'MinArgs': 2,
            'NeedsRoot': False
        })

    def run(self, argc, argv):
        self.device.download(argv[1], argv[2])
