<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Paystack extends Admin_Controller {

    var $setting;
    var $payment_method;
    var $api_config;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
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
        
        // Unified flow - works for both single and multi-pay (multi-pay structure is always used)
        $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
        
        // Calculate total (works for both single and multi)
        $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
        $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
        $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
        $total = number_format((float)($session_params['total'] + $fine_amount - $applied_discount + $gateway_charge), 2, '.', '');
        
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $data['name'] = $session_params['name'];
        $data['total'] = $total;
        
        // Handle invoice (can be object or array)
        if (isset($session_params['invoice'])) {
            if (is_array($session_params['invoice'])) {
                $data['currency_code'] = $session_params['invoice']['currency_name'];
            } else {
                $data['currency_code'] = $session_params['invoice']->currency_name;
            }
        }
        
        $data['id'] = $session_id; // Pass session_id to view for callback
        
        $this->load->view('payment/paystack/index', $data);
    }

    public function paystack_pay() {
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
        
		$this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');
		
        if ($this->form_validation->run() == false) {
            $this->load->view('payment/paystack/index', $data);
        } else {
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $total = number_format((float)(convertBaseAmountCurrencyFormat($params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
            
            // Get session_id for callback (similar to Razorpay)
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $data = array();
            $data['total'] = $total * 100;
            $data['symbol'] = isset($params['invoice']->symbol) ? $params['invoice']->symbol : '';
            $data['currency_name'] = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';
            $data['name'] = $params['name'];
            $data['guardian_phone'] = isset($params['guardian_phone']) ? $params['guardian_phone'] : '';

            $result = array();
            $amount = $data['total'];
            $ref = time() . "02";
            // Include session_id in callback URL (similar to Razorpay approach)
            $callback_url = base_url() . 'gateway/paystack/verify_payment/' . $ref . '/' . $session_id;
            $postdata = array('email' => $_POST['email'], 'amount' => $data['total'], "reference" => $ref, "callback_url" => $callback_url);
            $url = "https://api.paystack.co/transaction/initialize";
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($postdata));  //Post Fields
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            //
            curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
            $headers = [
                'Authorization: Bearer ' . $this->api_config->api_secret_key,
                'Content-Type: application/json',
            ];
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            $request = curl_exec($ch);
            curl_close($ch);

            $result = array();
            if ($request) {
                $result = json_decode($request, true);
            }

            if (!empty($result) && isset($result['status']) && $result['status'] != '') {
                $redir = $result['data']['authorization_url'];
                header("Location: " . $redir);
            } else {
                $data = array();
                $data['params'] = $session_params;
                $data['setting'] = $this->setting;
                $data['student_data'] = $this->student_model->get($session_params['student_id']);
                $data['api_error'] = isset($result['message']) ? $result['message'] : 'Payment initialization failed';
                $this->session->set_flashdata('msg', json_encode($data['api_error']));
                redirect(base_url("gateway/paystack"));
            }
        }
    }

    public function verify_payment($ref, $session_id = '') {
        // Get session_id from URL parameter (similar to Razorpay callback approach)
        if (empty($session_id)) {
            $session_id = $this->uri->segment(4);
        }
        
        // If still no session_id, try to get from session or GET parameter
        if (empty($session_id)) {
            if ($this->session->has_userdata('params')) {
                $params = $this->session->userdata('params');
                $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            } else {
                $session_id = isset($_GET['session_id']) ? $_GET['session_id'] : '';
            }
        }
        
        // Verify payment with Paystack
        $result = array();
        $url = 'https://api.paystack.co/transaction/verify/' . $ref;
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Authorization: Bearer ' . $this->api_config->api_secret_key]);
        $request = curl_exec($ch);
        curl_close($ch);
        
        if ($request) {
            $result = json_decode($request, true);
            if ($result && isset($result['data']) && $result['data']['status'] == 'success') {
                // Get session data (similar to Razorpay callback)
                if (empty($session_id)) {
                    redirect(base_url("payment/paymentfailed"));
                    return;
                }
                
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                if (!$session_data) {
                    redirect(base_url("payment/paymentfailed"));
                    return;
                }
                
                $params = json_decode($session_data['params'], true);
                
                if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                    redirect(base_url("payment/paymentfailed"));
                    return;
                }
                
                $payment_id = $ref;
                $bulk_fees = array();
                
                foreach ($params['student_fees_master_array'] as $fee_key => $fee_value) {
                    // Use individual discount amount for each fee (similar to Razorpay)
                    $fee_discount_amount = isset($fee_value['discount_amount']) ? $fee_value['discount_amount'] : 0;
                    
                    $json_array = array(
                        'amount' => $fee_value['amount_balance'],
                        'date' => date('Y-m-d'),
                        'amount_discount' => $fee_discount_amount,
                        'processing_charge_type' => isset($params['processing_charge_type']) ? $params['processing_charge_type'] : '',
                        'gateway_processing_charge' => isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0,
                        'amount_fine' => $fee_value['fine_balance'],
                        'description' => "Online fees deposit through Paystack Ref ID: " . $payment_id,
                        'received_by' => '',
                        'payment_mode' => 'Paystack',
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
                    $this->gateway_ins_model->delete_api_session($session_id);
                    redirect("payment/successinvoice", "refresh");
                } else {
                    redirect(base_url("payment/paymentfailed"));
                }
            } else {
                // Transaction was not successful
                redirect(base_url("payment/paymentfailed"));
            }
        } else {
            // Failed to verify payment
            redirect(base_url("payment/paymentfailed"));
        }
    }

}
