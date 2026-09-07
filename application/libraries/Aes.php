<?php

if (!defined('BASEPATH'))
    exit('No direct script access allowed');


class Aes
{
    private $CI;
    public $ENCRYPTION_ALGORITHM = 'AES-256-CBC';

    public function __construct()
    {
        $this->CI = &get_instance();
    }

    function encrypt($plainText, $key)
    {
        $secretKey = $this->hextobin(md5($key));
        $initVector = pack("C*", 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f);
        $encrypted = openssl_encrypt($plainText, 'AES-128-CBC', $secretKey, OPENSSL_RAW_DATA, $initVector);
        return bin2hex($encrypted);
    }

    function decrypt($encryptedText, $key)
    {
        $secretKey = $this->hextobin(md5($key));
        $initVector = pack("C*", 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f);
        $raw = $this->hextobin($encryptedText);
        $decrypted = openssl_decrypt($raw, 'AES-128-CBC', $secretKey, OPENSSL_RAW_DATA, $initVector);
        return rtrim($decrypted, "\0");
    }

    //*********** Padding Function *********************

    function pkcs5_pad($plainText, $blockSize)
    {
        $pad = $blockSize - (strlen($plainText) % $blockSize);
        return $plainText . str_repeat(chr($pad), $pad);
    }

    //********** Hexadecimal to Binary function for php 4.0 version ********

    function hextobin($hexString)
    {
        $length = strlen($hexString);
        $binString = "";
        $count = 0;
        while ($count < $length) {
            $subString = substr($hexString, $count, 2);
            $packedString = pack("H*", $subString);
            if ($count == 0) {
                $binString = $packedString;
            } else {
                $binString .= $packedString;
            }

            $count += 2;
        }
        return $binString;
    }

    function validchk($action, $string)
    {
        $output = false;
        $encrypt_method = "AES-256-CBC";
        $secret_key = '4D617279206861642061206C6974746C65206C616D';
        $secret_iv = '4F505A5B5C5D5E5F60616A6B6C6D6E6F7A7D7';
        // hash
        $key = hash('sha256', $secret_key);

        // iv - encrypt method AES-256-CBC expects 16 bytes - else you will get a warning
        $iv = substr(hash('sha256', $secret_iv), 0, 16);
        if ($action == 'encrypt') {
            $output = openssl_encrypt($string, $encrypt_method, $key, 0, $iv);
            $output = base64_encode($output);
        } else if ($action == 'decrypt') {
            $output = openssl_decrypt(base64_decode($string), $encrypt_method, $key, 0, $iv);
        }
        return $output;
    }

    public function encode($string, $key)
    {
        $EncryptionKey        = base64_decode($key);
        $InitializationVector = openssl_random_pseudo_bytes(openssl_cipher_iv_length($this->ENCRYPTION_ALGORITHM));
        $EncryptedText        = openssl_encrypt($string, $this->ENCRYPTION_ALGORITHM, $EncryptionKey, 0, $InitializationVector);
        return base64_encode($EncryptedText . '::' . $InitializationVector);
    }

    public function decode($string, $key)
    {
        $EncryptionKey                               = base64_decode($key);
        list($Encrypted_Data, $InitializationVector) = array_pad(explode('::', base64_decode($string), 2), 2, null);
        return openssl_decrypt($Encrypted_Data, $this->ENCRYPTION_ALGORITHM, $EncryptionKey, 0, $InitializationVector);
    }
}
