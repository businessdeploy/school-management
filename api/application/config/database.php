<?php

defined('BASEPATH') OR exit('No direct script access allowed');

$active_group = 'default';
$query_builder = TRUE;

$db_hostname = getenv('DB_HOST') ? getenv('DB_HOST') : (getenv('FLEET_DB_HOST') ? getenv('FLEET_DB_HOST') : (file_exists('/.dockerenv') ? 'smartschool-mariadb' : 'localhost'));
$db_username = getenv('DB_USER') ? getenv('DB_USER') : (getenv('FLEET_DB_USER') ? getenv('FLEET_DB_USER') : 'root');
$db_password = getenv('DB_PASS') !== false ? getenv('DB_PASS') : (getenv('FLEET_DB_PASSWORD') !== false ? getenv('FLEET_DB_PASSWORD') : 'SmartSchoolPass2026!');
$db_database = getenv('DB_NAME') ? getenv('DB_NAME') : 'smart_school';

// Dynamic Multi-Tenant Database Resolution
if (!empty($_SERVER['HTTP_X_TENANT_DB'])) {
    $db_database = preg_replace('/[^a-zA-Z0-9_-]/', '', $_SERVER['HTTP_X_TENANT_DB']);
} elseif (!empty($_SERVER['HTTP_X_TENANT_SLUG'])) {
    $clean_slug = preg_replace('/[^a-zA-Z0-9_-]/', '', $_SERVER['HTTP_X_TENANT_SLUG']);
    $db_database = 'ss_tenant_' . $clean_slug;
} elseif (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $host_parts = explode('.', strtolower(explode(':', $_SERVER['HTTP_X_FORWARDED_HOST'])[0]));
    if (count($host_parts) >= 3) {
        $sub = preg_replace('/[^a-zA-Z0-9_-]/', '', $host_parts[0]);
        if ($sub !== 'manage-school-crm' && $sub !== 'www' && $sub !== 'localhost') {
            $db_database = 'ss_tenant_' . $sub;
        }
    }
} elseif (isset($_SERVER['HTTP_HOST'])) {
    $host_parts = explode('.', strtolower(explode(':', $_SERVER['HTTP_HOST'])[0]));
    if (count($host_parts) >= 3) {
        $sub = preg_replace('/[^a-zA-Z0-9_-]/', '', $host_parts[0]);
        if ($sub !== 'manage-school-crm' && $sub !== 'www' && $sub !== 'localhost') {
            $db_database = 'ss_tenant_' . $sub;
        }
    }
}

$db['default'] = array(
    'dsn' => '',
    'hostname' => $db_hostname,
    'username' => $db_username,
    'password' => $db_password,
    'database' => $db_database,
    'dbdriver' => 'mysqli',
    'dbprefix' => '',
    'pconnect' => FALSE,
    'db_debug' => (ENVIRONMENT !== 'production'),
    'cache_on' => FALSE,
    'cachedir' => '',
    'char_set' => 'utf8mb4',
    'dbcollat' => 'utf8mb4_unicode_ci',
    'swap_pre' => '',
    'encrypt' => FALSE,
    'compress' => FALSE,
    'stricton' => FALSE,
    'failover' => array(),
    'save_queries' => FALSE
);
