from subprocess import check_output
import shlex

def doveadm(*args):
    print(' '.join(shlex.quote(a.decode('utf8') if type(a) is bytes else str(a)) for a in args))
    return check_output(['doveadm'] + list(args))

def fetch(fields, search):
    result = doveadm('fetch', '-u', 'simon', fields, *search)
    nfields = fields.count(' ')
    for record in result.split(b'\x0c'):
        if not record:
            continue
        values = record.strip().split(b'\n', nfields)
        rdict = {}
        for item in values:
            idx = item.index(b':')
            key, value = item[:idx], item[idx + 2:] # skip space too
            rdict[key.decode('utf8')] = value
        yield rdict

def search(search):
    result = doveadm('search', '-u', 'simon', *search)
    for line in result.split(b'\n'):
        if not line:
            continue
        idx = line.index(b' ')
        mailbox = line[:idx].decode('utf8')
        uid = int(line[idx + 1:])
        yield (mailbox, uid)

def delete(search):
    doveadm('expunge', '-u', 'simon', *search)

def move(mailbox, search):
    doveadm('move', '-u', 'simon', mailbox, *search)

def copy(mailbox, search):
    doveadm('copy', '-u', 'simon', mailbox, *search)

def status(fields, *mailboxes):
    result = doveadm('-f', 'pager', 'mailbox', 'status', '-u', 'simon', fields, *mailboxes)
    results = {}
    for record in result.split(b'\x0c'):
        if not record:
            continue
        mailbox, *items = record.decode('utf8').strip().split('\n')
        info = {}
        for item in items:
            key, value = item.split(': ', 2)
            if key != 'guid':
                value = int(value)
            info[key] = value
        results[mailbox] = info
    return results

def get_mailboxes(*mbfilter):
    result = doveadm('mailbox', 'list', '-u', 'simon', *mbfilter)
    return result.strip().decode('utf8').split('\n')

def create_mailbox(name, guid=None):
    args = ['-g', guid] if guid else []
    doveadm('mailbox', 'create', '-u', 'simon', *args, '-s', name)

def delete_mailbox(*names):
    doveadm('mailbox', 'delete', '-u', 'simon', '-s', *names)

def search_or(*clauses):
    search = ['(']
    for i, clause in enumerate(clauses):
        search.extend(['(', *clause, ')'])
        if i != len(clauses) - 1:
            search.append('OR')
    search.append(')')
    return search

