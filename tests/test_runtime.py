import argparse
import json
from pathlib import Path
import secrets
import subprocess
import time
import re
import tempfile

parser = argparse.ArgumentParser(description='Test an Odoo image against an isolated PostgreSQL service.')
parser.add_argument('--image', required=True)
parser.add_argument('--odoo-version', required=True, choices=['18.0', '19.0', '20.0'])
parser.add_argument('--native-tests', action='store_true')
args = parser.parse_args()
root = Path(tempfile.mkdtemp(prefix='dockerdoo-test-'))
repo = Path(__file__).resolve().parents[1]
print(f'Test logs: {root}', flush=True)
project = 'dockerdoo-test-' + secrets.token_hex(4)
passwords = [secrets.token_hex(12) + "'quote", secrets.token_hex(12)]
values = {}
for line in (repo / '.env.example').read_text().splitlines():
    if '=' in line and not line.startswith('#'):
        k, v = line.split('=', 1)
        values[k] = v
values.update(ODOO_VERSION=args.odoo_version, POSTGRES_USER='probe-app', POSTGRES_PASSWORD=passwords[0],
              POSTGRES_ADMIN_USER='probe-admin', POSTGRES_ADMIN_PASSWORD=passwords[1],
              DBNAME='probe_odoo', POSTGRES_DB='postgres', ADMIN_PASSWORD=secrets.token_hex(16), LIST_DB='False')
values['TEST_IMAGE'] = args.image
passwords.append(values['ADMIN_PASSWORD'])
env_file = root / 'test.env'
env_file.write_text('\n'.join(k + "='" + v.replace("'", "\\'") + "'" for k, v in values.items()) + '\n')
override = root / 'override.yaml'
override.write_text('''services:
  db:
    restart: "no"
    healthcheck:
      interval: 1s
      timeout: 5s
      retries: 15
  odoo:
    image: ${TEST_IMAGE}
    env_file: !reset []
    environment:
      DBNAME: probe_odoo
      TEST_DB: probe_odoo
      RUN_TESTS: '0'
      PIP_AUTO_INSTALL: '0'
    pull_policy: never
    restart: "no"
    healthcheck:
      interval: 1s
      timeout: 5s
      retries: 10
    ports: !reset []
    volumes: !override
      - odoo-data:/var/lib/odoo/data
      - odoo-testlogs:/var/lib/odoo/logs
      - odoo-modules:/mnt/extra-addons
''')
compose = ['docker', 'compose', '--project-directory', str(repo), '--project-name', project,
           '--env-file', str(env_file), '-f', str(repo/'docker-compose.yml'), '-f', str(override)]
result = {'project': project, 'image': args.image, 'odoo_version': args.odoo_version}
started = False

def redact(text):
    for p in passwords + [passwords[0].split(chr(39))[0]]:
        text = text.replace(p, '<REDACTED>')
    return text

def run(args, name, check=True, input=None, timeout=300):
    r = subprocess.run(args, text=True, capture_output=True, input=input, timeout=timeout)
    (root / (name + '.log')).write_text(redact(r.stdout + r.stderr))
    if check and r.returncode:
        raise RuntimeError(name + ': ' + redact((r.stdout+r.stderr)[-1800:]))
    return r

def sql(query, user='probe-app', check=True):
    return run(compose + ['exec', '-T', 'db', 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
                          '-U', user, '-d', 'postgres', '-At'], 'sql', check, query)

try:
    # Exercise addon discovery from a non-root cwd and across changing path sets.
    run(['docker', 'run', '--rm', '-i', '--network', 'none', '--entrypoint', 'python3',
         args.image, '-'], 'addon-paths', input=r"""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(tempfile.mkdtemp())
addons = root / 'addons'
conf = root / 'odoo.conf'
env = dict(os.environ, ODOO_RC=str(conf), ODOO_EXTRA_ADDONS=str(addons), PIP_AUTO_INSTALL='0')
base = env['ODOO_ADDONS_BASEPATH']

def add_module(repository):
    module = addons / repository / ('probe_' + repository)
    module.mkdir(parents=True)
    (module / '__init__.py').touch()
    (module / '__manifest__.py').write_text("{'name': 'Probe', 'installable': True}")

def apply():
    subprocess.run(['/entrypoint.sh', 'true'], cwd=root, env=env, check=True, capture_output=True)
    line = next(line for line in conf.read_text().splitlines() if line.startswith('addons_path ='))
    paths = [path.strip() for path in line.split('=', 1)[1].split(',')]
    assert len(paths) == len(set(paths)), paths
    assert paths == [*[str(path) for path in sorted(addons.iterdir())], base], paths

add_module('A')
conf.write_text('[options]\n; addons_path = ' + str(addons / 'A') + '\naddons_path = ' + base + '\n')
apply()
add_module('B')
apply()
apply()
conf.write_text('[options]\n')
apply()
print('Addon discovery and restart deduplication passed')
""")
    result['addon_paths'] = True
    conf = json.loads(run(compose+['config','--format','json'], 'config').stdout)
    result['admin_password_absent_in_app'] = conf['services']['odoo']['environment']['POSTGRES_ADMIN_PASSWORD'] == ''
    assert result['admin_password_absent_in_app']
    assert conf['services']['odoo']['environment']['PGUSER'] == 'probe-app'
    assert conf['services']['odoo']['environment']['PGPASSWORD'] == passwords[0]
    assert all(not v.get('external') and v['name'].startswith(project + '_') for v in conf.get('volumes', {}).values())
    assert all(not n.get('external') and n['name'].startswith(project + '_') for n in conf.get('networks', {}).values())
    started = True
    run(compose+['up','-d','--wait','--wait-timeout','90','db'], 'fresh-db')
    result['fresh_db_healthy'] = True
    role = sql("SELECT rolname,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls FROM pg_roles WHERE rolname=current_user;").stdout.strip()
    assert role == 'probe-app|f|t|f|f|f', role
    result['role'] = role
    copy = sql("CREATE TEMP TABLE probe(value text); COPY probe FROM PROGRAM 'printf harmless_probe';", check=False)
    assert copy.returncode != 0 and 'permission denied' in copy.stderr
    result['copy_program_denied'] = True
    demo = 'all' if args.odoo_version == '18.0' else 'True'
    # Health requests would interfere with Odoo's HTTP request-count tests.
    install_override = root / 'install.yaml'
    install_override.write_text('services:\n  odoo:\n    healthcheck:\n      disable: true\n')
    install = compose + ['-f', str(install_override), 'run', '--rm', '--no-deps', '-T']
    if args.native_tests:
        install += ['-e', 'RUN_TESTS=1', '-e', 'EXTRA_MODULES=base']
    install += ['odoo', 'odoo', '--without-demo=' + demo]
    if not args.native_tests:
        install += ['--stop-after-init', '-i', 'base', '--no-http']
    output = run(install, 'odoo-install', timeout=1200)
    if args.native_tests:
        summaries = re.findall(r'odoo\.tests\.result: (\d+) failed, (\d+) error\(s\) of (\d+) tests', output.stdout + output.stderr)
        assert summaries and int(summaries[-1][2]) > 0, 'No native tests ran'
        assert all(int(f) == 0 and int(e) == 0 for f, e, _ in summaries), summaries
        result['native_tests'] = int(summaries[-1][2])
    result['odoo_base_install'] = True
    run(compose+['up','-d','--no-deps','--no-build','odoo'], 'odoo-start')
    for _ in range(60):
        probe = run(compose+['exec','-T','odoo','curl','--fail','--silent','http://127.0.0.1:8069/web/health'], 'http', check=False)
        if probe.returncode == 0:
            result['http_health'] = json.loads(probe.stdout)
            break
        time.sleep(1)
    assert result.get('http_health', {}).get('status') == 'pass', 'Odoo did not respond with healthy status'
    app_id = run(compose+['ps', '-q', 'odoo'], 'app-id').stdout.strip()
    for _ in range(30):
        status = run(['docker', 'inspect', '--format', '{{.State.Health.Status}}', app_id], 'image-health').stdout.strip()
        if status == 'healthy':
            result['image_health'] = True
            break
        time.sleep(1)
    assert result.get('image_health'), 'Image healthcheck did not become healthy'
    run(compose+['stop','odoo'], 'stop-odoo')
    run(compose+['restart','db'], 'restart')
    run(compose+['up','-d','--wait','--wait-timeout','90','db'], 'restart-wait')
    result['restart_healthy'] = True
    sql('ALTER ROLE "probe-app" SUPERUSER;', user='probe-admin')
    db_id = run(compose+['ps','-q','db'], 'db-id').stdout.strip()
    for _ in range(30):
        status = run(['docker','inspect','--format','{{.State.Health.Status}}',db_id], 'legacy-health').stdout.strip()
        if status == 'unhealthy':
            result['elevated_role_unhealthy'] = True
            break
        time.sleep(1)
    assert result.get('elevated_role_unhealthy'), 'Elevated role was accepted'
    sql('ALTER ROLE "probe-app" NOSUPERUSER;', user='probe-admin')
    run(compose+['up','-d','--wait','--wait-timeout','90','db'], 'restored-safe-role')
except Exception as e:
    result['error'] = str(e)
    run(compose+['logs','--no-color'], 'failure-containers', check=False)
finally:
    if started:
        cleanup = run(compose+['down','--volumes','--remove-orphans'], 'cleanup', check=False)
        result['cleanup_exit'] = cleanup.returncode
        if cleanup.returncode:
            result['error'] = result.get('error', 'Cleanup failed')
    env_file.unlink(missing_ok=True)
    (root/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if 'error' in result:
        raise SystemExit(1)
