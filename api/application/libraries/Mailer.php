<?php

if (!defined('BASEPATH')) {

    exit('No direct script access allowed');
}


use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require_once(APPPATH.'third_party/PHPMailer/src/Exception.php');
require_once(APPPATH.'third_party/PHPMailer/src/PHPMailer.php');
require_once(APPPATH.'third_party/PHPMailer/src/SMTP.php');

class Mailer {

    public $mail_config;
    private $sch_setting;
    private $CI;

    public function __construct() {     

        $this->CI = &get_instance();

        $this->CI->load->model('emailconfig_model');

        $this->CI->mail_config = $this->CI->emailconfig_model->getActiveEmail();

        $this->CI->load->model('setting_model');

        $this->sch_setting = $this->CI->setting_model->get();
    }
	
	public function send_mail($toemail, $subject, $body)
	{
		$mail          = new PHPMailer();
		$mail->CharSet = 'UTF-8';

		$school_name  = $this->sch_setting[0]['name'];
		$school_email = $this->sch_setting[0]['email'];

		/* ================= AWS SES ================= */
		if ($this->CI->mail_config->email_type == "aws_ses") {

			$this->CI->load->library("aws_mail");

			$mail->setFrom($this->CI->mail_config->smtp_username, $school_name);
			$mail->addAddress($toemail);
			$mail->Subject = $subject;
			$mail->Body    = $body;
			$mail->AltBody = strip_tags($body);			

			if (!$mail->preSend()) {
				return false;
			}

			$message = $mail->getSentMIMEMessage();
			$status  = $this->CI->aws_mail->sendRawMail($message);

			return $status['status'] ? true : false;
		}

		/* ================= SMTP ================= */
		if ($this->CI->mail_config->email_type == "smtp") {

			$mail->isSMTP();
			$mail->SMTPAuth   = true;
			$mail->SMTPSecure = $this->CI->mail_config->ssl_tls;
			$mail->Host       = $this->CI->mail_config->smtp_server;
			$mail->Port       = $this->CI->mail_config->smtp_port;
			$mail->Username   = $this->CI->mail_config->smtp_username;
			$mail->Password   = $this->CI->mail_config->smtp_password;

			$mail->setFrom($this->CI->mail_config->smtp_username, $school_name);
			$mail->addReplyTo($this->CI->mail_config->smtp_username, $school_name);

		} else {
			// PHP mail()
			$mail->setFrom($school_email, $school_name);
		}

		/* ================= COMMON ================= */
		$mail->isHTML(true);
		$mail->Subject = $subject;
		$mail->Body    = $body;
		$mail->AltBody = strip_tags($body);
		$mail->addAddress($toemail);		

		return $mail->send() ? true : false;
	}


} 
