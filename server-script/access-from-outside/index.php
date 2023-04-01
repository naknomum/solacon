<?php

################################################################################
# CONSTANTS
################################################################################

const RX_3D_HEX = '/^#?([a-f\d])([a-f\d])([a-f\d])$/i';
const RX_6D_8D_HEX = '/^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})?$/i';
const RX_RGB = '/^(rgba?\()?\s*([\d]{1,3})\s*,\s*([\d]{1,3})\s*,\s*([\d]{1,3})(\s*,\s*([\d]{1,3}))?\)?$/i';

################################################################################
# VARIABLES
################################################################################

$conf = [
	'solacon_path' => realpath(__DIR__ . '/../solacon.sh'),
];

# For custom configuration, rename the file `index.conf.php.tpl` to `index.conf.php` and change values.
$custom_conf_file = realpath(__DIR__ . '/../index.conf.php');

if (file_exists($custom_conf_file)) {
	$custom_conf = parse_ini_file($custom_conf_file);

	if (is_array($custom_conf)) {
		$conf = array_merge($conf, $custom_conf);
	}
}

################################################################################
# SCRIPT
################################################################################

if (file_exists($conf['solacon_path'])) {
	$args = [$conf['solacon_path'], '-r', 'name+b64'];

	if (isset($_GET['background']) && ($_GET['background'] == 'colored' || $_GET['background'] == 'white')) {
		$args[] = '-b';
		$args[] = escapeshellarg($_GET['background']);
	}

	if (
		isset($_GET['color']) &&
		(preg_match(RX_3D_HEX, $_GET['color']) || preg_match(RX_6D_8D_HEX, $_GET['color']) || preg_match(RX_RGB, $_GET['color']))
	) {
		$args[] = '-c';
		$args[] = escapeshellarg($_GET['color']);
	}

	if (isset($_GET['download']) && ($_GET['download'] == 'png' || $_GET['download'] == 'svg')) {
		$args[] = '-f';
		$args[] = escapeshellarg($_GET['download']);
	}

	if (isset($_GET['size']) && preg_match('/^[1-9][0-9]*$/', $_GET['size'])) {
		$args[] = '-s';
		$args[] = escapeshellarg($_GET['size']);
	}

	if (isset($_GET['string'])) {
		$args[] = '-t';
		$args[] = escapeshellarg($_GET['string']);
	}

	$exec_return = shell_exec(implode(' ', $args));

	if (is_string($exec_return)) {
		$img_data = explode("\n", $exec_return);

		if (!empty($img_data[0]) && !empty($img_data[1])) {
			$img_name = $img_data[0];
			$img_content = base64_decode($img_data[1], true);

			if ($img_content !== false) {
				header('Content-Type: application/octet-stream');
				header('Content-Transfer-Encoding: Binary');
				header('Content-Disposition: attachment; filename="' . str_replace('"', '\"', $img_name) . '"');
				header('Content-Length: ' . strlen($img_content));

				echo $img_content;

				exit();
			}
		}
	}
}
