<?php
// FiveOS status endpoint for the landing page.
// Only returns what the FiveM server already publishes on port 30120
// (dynamic.json, info.json, players.json) plus the installed build.

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

const FX = 'http://127.0.0.1:30120';

function fx_json(string $path)
{
    $ctx = stream_context_create(['http' => ['timeout' => 1.5, 'ignore_errors' => false]]);
    $raw = @file_get_contents(FX . $path, false, $ctx);
    if ($raw === false) {
        return null;
    }
    $data = json_decode($raw, true);
    return is_array($data) ? $data : null;
}

function conf_value(string $key): ?string
{
    $conf = @file_get_contents('/etc/fiveos/fiveos.conf');
    if ($conf !== false && preg_match('/^' . preg_quote($key, '/') . '="(.*)"$/m', $conf, $m)) {
        return $m[1];
    }
    return null;
}

function fiveos_version(): ?string
{
    $lib = @file_get_contents('/usr/local/lib/fiveos/lib.sh');
    if ($lib !== false && preg_match('/^FIVEOS_VERSION="([^"]+)"/m', $lib, $m)) {
        return $m[1];
    }
    return null;
}

// FiveM color codes (^1, ^2, ...) are not shown on the page
function clean(string $s): string
{
    return trim(preg_replace('/\^[0-9]/', '', $s));
}

// host the visitor used, so the connect address works for them
$host = parse_url('http://' . ($_SERVER['HTTP_HOST'] ?? ''), PHP_URL_HOST) ?: ($_SERVER['SERVER_ADDR'] ?? '');
if (!preg_match('/^[A-Za-z0-9.\-:\[\]]+$/', $host)) {
    $host = $_SERVER['SERVER_ADDR'] ?? '';
}

$dynamic = fx_json('/dynamic.json');
$info = $dynamic ? fx_json('/info.json') : null;
$players = $dynamic ? fx_json('/players.json') : null;

$list = [];
foreach ($players ?? [] as $p) {
    $list[] = [
        'id' => (int)($p['id'] ?? 0),
        'name' => clean((string)($p['name'] ?? '')),
        'ping' => (int)($p['ping'] ?? 0),
    ];
}
usort($list, fn($a, $b) => $a['id'] <=> $b['id']);

echo json_encode([
    'online' => $dynamic !== null,
    'hostname' => $dynamic ? clean((string)($dynamic['hostname'] ?? '')) : null,
    'clients' => $dynamic ? (int)($dynamic['clients'] ?? 0) : 0,
    'maxClients' => $dynamic ? (int)($dynamic['sv_maxclients'] ?? 0) : null,
    'players' => $list,
    'resources' => $info ? count($info['resources'] ?? []) : null,
    'onesync' => $info ? ($info['vars']['onesync_enabled'] ?? null) === 'true' : null,
    'build' => conf_value('FXSERVER_BUILD'),
    'host' => $host,
    'port' => 30120,
    'fiveos' => fiveos_version(),
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
