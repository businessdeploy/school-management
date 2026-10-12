<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

require_once APPPATH . "third_party/omnipay/vendor/autoload.php";

use chillerlan\QRCode\QRCode;
use chillerlan\QRCode\QROptions;
class QR_Code
{
    private $CI;
    public function __construct()
    {
           $this->CI = &get_instance();
    }

    //function crated for redering qr code
    public function generateQRCodeForCertificateDownload($text)
    {
        $options = new QROptions([
            'version' => 10,
            'eccLevel' => QRCode::ECC_H,
            'scale' => 5,
            'imageBase64' => false,
            'imageTransparent' => true,
            'foregroundColor' => '#000000',
            'backgroundColor' => '#ffffff',
            'outputType' => QRCode::OUTPUT_IMAGE_PNG
        ]);

        // Create the QR code
        $qrCode = new QRCode($options);

        // Set content type header to PNG
        // header('Content-Type: image/png');//commented by webfeb
        // Output directly to the browser
        echo $qrCode->render($text);
        // exit;
    }
}
