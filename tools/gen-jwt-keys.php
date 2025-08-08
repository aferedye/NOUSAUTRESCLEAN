<?php
declare(strict_types=1);

$dir = __DIR__ . '/../config/jwt';
if (!is_dir($dir)) { mkdir($dir, 0777, true); }

$conf = [
    'private_key_bits' => 4096,
    'private_key_type' => OPENSSL_KEYTYPE_RSA,
];

$priv = openssl_pkey_new($conf);
if ($priv === false) {
    $e = openssl_error_string();
    fwrite(STDERR, "openssl_pkey_new failed: " . ($e ?: 'unknown') . PHP_EOL);
    exit(1);
}

$privPem = '';
if (!openssl_pkey_export($priv, $privPem)) {
    $e = openssl_error_string();
    fwrite(STDERR, "openssl_pkey_export failed: " . ($e ?: 'unknown') . PHP_EOL);
    exit(1);
}

$details = openssl_pkey_get_details($priv);
if ($details === false || empty($details['key'])) {
    fwrite(STDERR, "openssl_pkey_get_details failed" . PHP_EOL);
    exit(1);
}
$pubPem = $details['key'];

file_put_contents($dir . '/private.pem', $privPem);
file_put_contents($dir . '/public.pem',  $pubPem);

echo "JWT keys generated:\n- $dir/private.pem\n- $dir/public.pem\n";