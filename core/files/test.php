<?php

$ch = curl_init("https://api.github.com/repos/Bacon/BaconQrCode/zipball/8674e51bb65af933a5ffaf1c308a660387c35c22");
$fp = fopen("example_homepage.txt", "w");

curl_setopt($ch, CURLOPT_VERBOSE, true);
curl_setopt($ch, CURLOPT_STDERR, fopen('php://stderr', 'w'));
curl_setopt($ch, CURLOPT_FILE, $fp);
curl_setopt($ch, CURLOPT_HEADER, 0);
curl_setopt($ch, CURLOPT_USERAGENT, "Test SSL");
curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);

curl_exec($ch);
$httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
echo 'HTTP code: ' . $httpcode;

if(curl_error($ch)) {
    fwrite($fp, curl_error($ch));
}
curl_close($ch);
fclose($fp);
?>
