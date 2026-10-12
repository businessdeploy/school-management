<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Dpopay extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->model(array('gateway_ins_model', 'course_model'));
    }

    public function index() {
        $data = array();
        if ($this->session->has_userdata('course_amount')) {
            $session_params = $this->session->userdata('course_amount');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        }
        
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $this->load->view('course_payment/dpopay/index', $data);
    }	 
	
    public function pay() {
        $this->form_validation->set_rules('creditcardnumber', ('Credit Card Number'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('creditcardexpiry', ('Credit Card Expiry'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('creditcardcvv', ('Credit Card CVV'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('cardholdername', ('Card Holder Name'), 'trim|required|xss_clean');	
		
        $data = array();
        if ($this->session->has_userdata('course_amount')) {
            $session_params = $this->session->userdata('course_amount');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        }
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        
        if ($this->form_validation->run() == false) {
            $this->load->view('course_payment/dpopay/index', $data);
        } else {
            $params = $session_params;
            
            // Course payment flow - calculate total from course data
            $total_amount = isset($params['total_amount']) ? $params['total_amount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $amount = number_format((float)($total_amount + $gateway_charge), 2, '.', '');
            
            $instadetails = $this->paymentsetting_model->getActiveMethod();
            $CompanyToken = $instadetails->api_secret_key;
            $PaymentCurrency = isset($params['currency_name']) ? $params['currency_name'] : '';
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $ch = curl_init();
			curl_setopt($ch, CURLOPT_URL, 'https://secure.3gdirectpay.com/API/v6/');   
			curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
			curl_setopt($ch, CURLOPT_POST, 1);
			curl_setopt($ch, CURLOPT_POSTFIELDS, "<?xml version='1.0' encoding='utf-8'?><API3G><CompanyToken>".$CompanyToken."</CompanyToken><Request>createToken</Request><Transaction><PaymentAmount>".$amount."</PaymentAmount><PaymentCurrency>".$PaymentCurrency."</PaymentCurrency><CompanyRef>".time().rand(99,999)."</CompanyRef><RedirectURL>".base_url('course_payment/dpopay/success/' . $session_id)."</RedirectURL><BackURL>".base_url('course_payment/dpopay')."</BackURL><CompanyRefUnique>0</CompanyRefUnique><PTL>5</PTL></Transaction><Services><Service><ServiceType>86280</ServiceType><ServiceDescription>Course Payment</ServiceDescription><ServiceDate>".date('Y-m-d')."</ServiceDate></Service></Services></API3G>");
			$headers = array();
			$headers[] = 'Content-Type: application/xml';
			$headers[] = 'Accept: application/xml';
			curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
			$result = curl_exec($ch);
			if (curl_errno($ch)) {
				$data['api_error'] = array('message' => 'cURL Error: ' . curl_error($ch));
				$this->load->view('course_payment/dpopay/index', $data);
				curl_close($ch);
				return;
			}
			$xml = simplexml_load_string($result);
			$array = json_decode(json_encode($xml), true);
			$TransToken = "";
            curl_close($ch);
          
            if(isset($array['Result']) && $array['Result']=='000'){
              $TransToken = $array['TransToken'];  
              $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, 'https://secure.3gdirectpay.com/API/v6/');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, '<?xml version="1.0" encoding="utf-8"?><API3G><CompanyToken>'.$CompanyToken.'</CompanyToken><Request>chargeTokenCreditCard</Request><TransactionToken>'.$TransToken.'</TransactionToken><CreditCardNumber>'.$_POST['creditcardnumber'].'</CreditCardNumber><CreditCardExpiry>'.$_POST['creditcardexpiry'].'</CreditCardExpiry><CreditCardCVV>'.$_POST['creditcardcvv'].'</CreditCardCVV><CardHolderName>'.$_POST['cardholdername'].'</CardHolderName><ChargeType></ChargeType></API3G>');
            $headers = array();
            $headers[] = 'Content-Type: application/xml';
            $headers[] = 'Accept: application/xml';
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
             
            $result1 = curl_exec($ch);       
            
            if (curl_errno($ch)) {
                $data['api_error'] = array('message' => 'cURL Error: ' . curl_error($ch));
                $this->load->view('course_payment/dpopay/index', $data);
                curl_close($ch);
                return;
            }
            $xml = simplexml_load_string($result1);         
             
            $json = json_decode(json_encode($xml), true);
            
            curl_close($ch);
            if (isset($json['ResultExplanation']) && $json['ResultExplanation'] == 'Transaction Charged') {
                $this->success($array['TransRef'], $session_id);
            } else {
                $data['api_error'] = $json;  
                $this->load->view('course_payment/dpopay/index', $data);  
            }
          } else {
            $data['api_error'] = $array;  
            $this->load->view('course_payment/dpopay/index', $data); 
          }
        }
    }

    public function success($TransRef, $session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        // Get session data
        if (empty($session_id)) {
            if ($this->session->has_userdata('course_amount')) {
                $params = $this->session->userdata('course_amount');
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        } else {
            $session_data = $this->gateway_ins_model->get_api_session($session_id);
            if (!$session_data) {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
            $params = json_decode($session_data['params'], true);
        }
        
        if (!isset($params['courseid']) || empty($params['courseid'])) {
            redirect(base_url("course_payment/course_payment/paymentfailed"));
            return;
        }
        
        // Course payment data structure
        $payment_data = array(
            'date' => date('Y-m-d'),
            'student_id' => $params['student_id'],
            'online_courses_id' => $params['courseid'],
            'course_name' => $params['course_name'],
            'actual_price' => $params['actual_amount'],
            'paid_amount' => $params['total_amount'],
            'payment_type' => 'Online',
            'transaction_id' => $TransRef,
            'note' => "Online course fees deposit through DPO Txn ID: " . $TransRef,
            'payment_mode' => 'DPO',
        );
        
        $response = $this->course_model->add($payment_data);
        
        if ($response) {
            // Clean up session if using api_session_id
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            redirect("course_payment/course_payment/successinvoice", "refresh");
        } else {
            redirect(base_url("course_payment/course_payment/paymentfailed"));
        }
    }

}
