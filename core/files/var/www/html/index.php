<?php
$proto = (isset($_SERVER['SERVER_PROTOCOL']))?($_SERVER['SERVER_PROTOCOL']):('HTTP/1.1');
header($proto.' 503 Service Unavailable', true);
header('cache-control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0');
header('retry-after: 30');
header('refresh: 30');
?>
<html>
MISP is loading...
</html>