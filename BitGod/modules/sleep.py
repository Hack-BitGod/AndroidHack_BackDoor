from ghost.lib.module import Module


class GhostModule(Module):
    def __init__(self):
        super().__init__()

        self.details.update({
            'Category': "manage",
            'Name': "sleep",
            'Authors': [
                'BitGod'
            ],
            'Description': "Put device into sleep mode.",
            'Usage': "sleep",
            'MinArgs': 0,
            'NeedsRoot': False
        })

    def run(self, argc, argv):
        self.device.send_command("input keyevent 26")
