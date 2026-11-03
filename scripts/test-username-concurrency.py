#!/usr/bin/env python3
"""Race real transactions in the disposable local test database, never hosted data."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--container', help='Use psql inside this local Docker test container')
args = parser.parse_args()
psql = ['psql', '-h', 'localhost', '-U', 'postgres', '-Atq', '-v', 'ON_ERROR_STOP=1']
if args.container:
    psql = ['docker', 'exec', '-i', args.container, 'psql', '-U', 'postgres', '-Atq', '-v', 'ON_ERROR_STOP=1']


def query(sql):
    return subprocess.run(psql, input=sql, text=True, capture_output=True, check=True).stdout.strip()


ids = [f'00000000-0000-0000-0000-{i:012d}' for i in range(201, 209)]
actors = ','.join(f"'{actor}'" for actor in ids)
query(f'insert into auth.users(id) values ' + ','.join(f"('{actor}')" for actor in ids))


def create_profile(actor, name):
    return query(f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{actor}',true);
select public.command('save_profile',jsonb_build_object('name','{name}'),gen_random_uuid());
select pg_sleep(0.1);
commit;
select username from public.profiles where id='{actor}';""").splitlines()[-1]


try:
    with ThreadPoolExecutor(max_workers=6) as pool:
        handles = list(pool.map(lambda actor: create_profile(actor, 'Username Race Test'), ids[:6]))
    expected = {'username_race_test'} | {f'username_race_test{i}' for i in range(2, 7)}
    assert set(handles) == expected, handles

    create_profile(ids[6], 'Manual Chooser')
    # Reserve a handle without committing. The simultaneous sign-up must wait,
    # observe that committed manual claim, then receive the next free suffix.
    manual = subprocess.Popen(psql, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    manual.stdin.write(f"""begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{ids[6]}',true);
select public.command('set_username','{{"username":"manual_race_test"}}',gen_random_uuid());
select '__username_reserved__';
select pg_sleep(1);
commit;
""")
    manual.stdin.close()
    for line in manual.stdout:
        if line.strip() == '__username_reserved__':
            break
    else:
        raise AssertionError(manual.stderr.read())
    auto = create_profile(ids[7], 'Manual Race Test')
    assert manual.wait(timeout=15) == 0, manual.stderr.read()
    assert auto == 'manual_race_test2', auto
    print('Concurrent automatic sign-ups and manual-vs-automatic claims passed')
finally:
    query(f"delete from public.command_receipts where actor in ({actors}); delete from public.profiles where id in ({actors}); delete from auth.users where id in ({actors});")
