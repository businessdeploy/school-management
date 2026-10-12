<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Instamojo extends Admin_Controller {

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
        $data['params'] = $this->session->userdata('params');
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($data['params']['student_id']);

        $this->load->view('payment/instamojo/index', $data);
    }

    public function insta_pay() {
		
			$data = array();
            $data['params'] = $this->session->userdata('params');
            $data['setting'] = $this->setting;
            $data['api_error'] = array();
        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');
		$data['student_data'] = $this->student_model->get($data['params']['student_id']);
        if ($this->form_validation->run() == false) {
            
            $this->load->view('payment/instamojo/index', $data);
        } else {

            $instamojo = $this->paymentsetting_model->getActiveMethod();

            
            if ($this->session->has_userdata('params')) {
                $session_params = $this->session->userdata('params');
                $data['session_params'] = $session_params;
            }

            $amount = $data['session_params']['total'];
            $insta_apikey = $instamojo->api_secret_key;
            $insta_authtoken = $instamojo->api_publishable_key;

            if ($instamojo->payment_type == "instamojo") { 
                $ch = curl_init();
                curl_setopt($ch, CURLOPT_URL, 'https://www.instamojo.com/api/1.1/payment-requests/'); // for live https://www.instamojo.com/api/1.1/payment-requests/
                curl_setopt($ch, CURLOPT_HEADER, FALSE);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, TRUE);
                curl_setopt($ch, CURLOPT_HTTPHEADER, array("X-Api-Key:$insta_apikey",
                    "X-Auth-Token:$insta_authtoken"));
                // Unified flow - calculate total from student_fees_master_array
                $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
                $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
                $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
                $total_amount = $session_params['total'] + $fine_amount - $applied_discount + $gateway_charge;
                
                $payload = Array(
                    'purpose' => 'Student Fees',
                    'amount' => number_format((float)(convertBaseAmountCurrencyFormat($total_amount)), 2, '.', ''),
                    'phone' => $_POST['phone'],
                    'buyer_name' => $data['session_params']['name'],
                    'redirect_url' => base_url() . 'gateway/instamojo/success',
                    'send_email' => false,
                    'webhook' => base_url() . 'webhooks/insta_webhook',
                    'send_sms' => false,
                    'email' => $_POST['email'],
                    'allow_repeated_payments' => false
                ); 

                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($payload));
                $response = curl_exec($ch);
				
			 
                curl_close($ch);
                $json = json_decode($response, true);
                if ($json['success']) {
                    $url = $json['payment_request']['longurl'];
                    header("Location: $url");
                } else {
                    $data = array();
                    $data['params'] = $this->session->userdata('params');
                    $data['setting'] = $this->setting;
                    $json = json_decode($response, true);
                   
                    $data['api_error'] = $json['message'];
                    $data['student_data'] = $this->student_model->get($data['params']['student_id']);
                    $this->load->view('payment/instamojo/index', $data);
                }
            } else {
                $this->session->set_flashdata('error', 'Oops! Something went wrong');
                $this->load->view('payment/error');
            }
        }
    }

    public function success() {
        if ($_GET['payment_status'] == 'Credit') {
            $purchaseId = $_GET['payment_id'];
            if ($purchaseId) {
                // Get params from session or API session
                if ($this->session->has_userdata('params')) {
                    $params = $this->session->userdata('params');
                } else {
                    // Try to get from API session if available
                    $session_id = isset($_GET['session_id']) ? $_GET['session_id'] : '';
                    if (!empty($session_id)) {
                        $session_data = $this->gateway_ins_model->get_api_session($session_id);
                        $params = json_decode($session_data['params'], true);
                    } else {
                        redirect(base_url("payment/paymentfailed"));
                        return;
                    }
                }
                
                $ref_id = $purchaseId;
                $bulk_fees = array();
                
                // Unified flow - handle both single and multi payments using student_fees_master_array
                if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                    redirect(base_url("payment/paymentfailed"));
                    return;
                }
                
                // Process all fees using unified structure
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
                        'description' => "Online fees deposit through Instamojo TXN ID: " . $ref_id,
                        'received_by' => '',
                        'payment_mode' => 'Instamojo',
                    );
                    
                    $insert_fee_data = array(
                        'fee_category' => $fee_value['fee_category'],
                        'student_transport_fee_id' => $fee_value['student_transport_fee_id'],
                        'student_fees_master_id' => $fee_value['student_fees_master_id'],
                        'fee_groups_feetype_id' => $fee_value['fee_groups_feetype_id'],
                        'amount_detail' => $json_array,
                    );
                    $bulk_fees[] = $insert_fee_data;
                }
                
                $response = $this->studentfeemaster_model->fee_deposit_bulk($bulk_fees, NULL);
                
                if ($response) {
                    // Delete API session if exists
                    if (isset($session_id) && !empty($session_id)) {
                        $this->gateway_ins_model->delete_api_session($session_id);
                    }
                    redirect("payment/successinvoice", "refresh");
                } else {
                    redirect(base_url("payment/paymentfailed"));
                }
            }
        } else {
            redirect(base_url("payment/paymentfailed"));
        }
    }

}
