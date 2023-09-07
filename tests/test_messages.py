script: str = "/app/libs/messages.sh"


def test_show_message(bash):
    assert bash.run_script(script, ['show_message', 'test']) == 'test'


def test_show_confirm_message(bash):
    assert bash.run_script(script, ['show_confirm_message', 'test', 'y', 'y']) == 'y'
