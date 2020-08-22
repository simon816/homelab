import imaplib
import re
from imapclient.response_parser import parse_fetch_response
from io import BytesIO

class EnvelopeReader(imaplib.IMAP4):

    def __init__(self):
        self._mode_utf8()
        self.tagre = re.compile(br'(?P<tag>\d+) (?P<type>[A-Z]+) (?P<data>.*)', re.ASCII)
        self.untagged_responses = {}
        self.tagged_commands = {}
        self._cmd_log_len = 10
        self._cmd_log_idx = 0
        self._cmd_log = {}
        self.debug = 0

    def read_envelope(self, env, normalise_times=True):
        tag = b'001'
        msg_id = b'1'
        self.tagged_commands[tag] = None
        self.file = self.readfile = BytesIO(b'* ' + msg_id + b' FETCH ( ENVELOPE (' + env + b'))\r\n' + tag + b' OK FETCH completed\r\n')
        typ, data = self._command_complete('FETCH', tag)
        typ, data = self._untagged_response(typ, data, 'FETCH')
        resp = parse_fetch_response(data, normalise_times, True)
        return resp[int(msg_id)][b'ENVELOPE']
