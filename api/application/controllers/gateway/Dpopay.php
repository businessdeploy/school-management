<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Dpopay extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->model(array('gateway_ins_model'));
    }

    public function index() {
        $data = array();
        if ($this->session->has_userdata('params')) {
            $session_params = $this->session->userdata('params');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
        }
        
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $this->load->view('payment/dpopay/index', $data);
    }	 
	
    public function pay() {
        $this->form_validation->set_rules('creditcardnumber', ('Credit Card Number'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('creditcardexpiry', ('Credit Card Expiry'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('creditcardcvv', ('Credit Card CVV'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('cardholdername', ('Card Holder Name'), 'trim|required|xss_clean');	
		
        $data = array();
        if ($this->session->has_userdata('params')) {
            $session_params = $this->session->userdata('params');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
        }
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        
        if ($this->form_validation->run() == false) {
            $this->load->view('payment/dpopay/index', $data);
        } else {
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $amount = number_format((float)($params['total'] + $fine_amount - $applied_discount + $gateway_charge), 2, '.', '');
            
            $instadetails = $this->paymentsetting_model->getActiveMethod();
            $CompanyToken = $instadetails->api_secret_key;
            $PaymentCurrency = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $ch = curl_init();
			curl_setopt($ch, CURLOPT_URL, 'https://secure.3gdirectpay.com/API/v6/');   
			curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
			curl_setopt($ch, CURLOPT_POST, 1);
			curl_setopt($ch, CURLOPT_POSTFIELDS, "<?xml version='1.0' encoding='utf-8'?><API3G><CompanyToken>".$CompanyToken."</CompanyToken><Request>createToken</Request><Transaction><PaymentAmount>".$amount."</PaymentAmount><PaymentCurrency>".$PaymentCurrency."</PaymentCurrency><CompanyRef>".time().rand(99,999)."</CompanyRef><RedirectURL>".base_url('gateway/dpopay/success/' . $session_id)."</RedirectURL><BackURL>".base_url('gateway/dpopay')."</BackURL><CompanyRefUnique>0</CompanyRefUnique><PTL>5</PTL></Transaction><Services><Service><ServiceType>86280</ServiceType><ServiceDescription>Student Fees</ServiceDescription><ServiceDate>".date('Y-m-d')."</ServiceDate></Service></Services></API3G>");
			$headers = array();
			$headers[] = 'Content-Type: application/xml';
			$headers[] = 'Accept: application/xml';
			curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
			$result = curl_exec($ch);
			if (curl_errno($ch)) {
				$data['api_error'] = array('message' => 'cURL Error: ' . curl_error($ch));
				$this->load->view('payment/dpopay/index', $data);
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
                $this->load->view('payment/dpopay/index', $data);
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
                $this->load->view('payment/dpopay/index', $data);  
            }
          } else {
            $data['api_error'] = $array;  
            $this->load->view('payment/dpopay/index', $data); 
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
            if ($this->session->has_userdata('params')) {
                $params = $this->session->userdata('params');
            } else {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
        } else {
            $session_data = $this->gateway_ins_model->get_api_session($session_id);
            if (!$session_data) {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
            $params = json_decode($session_data['params'], true);
        }
        
        if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
            redirect(base_url("payment/paymentfailed"));
            return;
        }
        
        $bulk_fees = array();
        
        foreach ($params['student_fees_master_array'] as $fee_key => $fee_value) {
            // Use individual discount amount for each fee
            $fee_discount_amount = isset($fee_value['discount_amount']) ? $fee_value['discount_amount'] : 0;
            
            $json_array = array(
                'amount' => $fee_value['amount_balance'],
                'date' => date('Y-m-d'),
                'amount_discount' => $fee_discount_amount,
                'processing_charge_type' => isset($params['processing_charge_type']) ? $params['processing_charge_type'] : '',
                'gateway_processing_charge' => isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0,
                'amount_fine' => $fee_value['fine_balance'],
                'description' => "Online fees deposit through DPO TXN ID: " . $TransRef,
                'received_by' => '',
                'payment_mode' => 'DPO',
            );

            $insert_fee_data = array(
                'fee_category' => $fee_value['fee_category'],
                'student_fees_master_id' => $fee_value['student_fees_master_id'],
                'fee_groups_feetype_id' => $fee_value['fee_groups_feetype_id'],
                'amount_detail' => $json_array,
            );
            
            // Only set student_transport_fee_id if it's a transport fee and has a valid value
            if (isset($fee_value['fee_category']) && $fee_value['fee_category'] == 'transport' && !empty($fee_value['student_transport_fee_id'])) {
                $insert_fee_data['student_transport_fee_id'] = $fee_value['student_transport_fee_id'];
            } else {
                $insert_fee_data['student_transport_fee_id'] = NULL;
            }
            
            $bulk_fees[] = $insert_fee_data;
        }
        
        $response = $this->studentfeemaster_model->fee_deposit_bulk($bulk_fees, isset($params['fee_discount_group']) ? $params['fee_discount_group'] : NULL);
        
        if ($response) {
            // Clean up session if using api_session_id
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            redirect("payment/successinvoice", "refresh");
        } else {
            redirect(base_url("payment/paymentfailed"));
        }
    }

}

