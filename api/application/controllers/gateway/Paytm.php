<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Paytm extends Admin_Controller {

    var $setting;
    var $payment_method;
    var $api_config;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $this->load->library('Paytm_lib');
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
                $data['symbol'] = $session_params['invoice']['symbol'];
                $data['currency_name'] = $session_params['invoice']['currency_name'];
            } else {
                $data['symbol'] = $session_params['invoice']->symbol;
                $data['currency_name'] = $session_params['invoice']->currency_name;
            }
        }
        
        $data['id'] = $session_id; // Pass session_id to view for callback
        
        $ORDER_ID = time();
        $paytmParams = array();

        $paytmParams = array(
            "MID" => $this->api_config->api_publishable_key,
            "WEBSITE" => $this->api_config->paytm_website,
            "INDUSTRY_TYPE_ID" => $this->api_config->paytm_industrytype,
            "CHANNEL_ID" => "WEB",
            "ORDER_ID" => $ORDER_ID,
            "CUST_ID" => $session_params['student_id'],
            "TXN_AMOUNT" => convertBaseAmountCurrencyFormat($total),
            "CALLBACK_URL" => base_url() . "gateway/Paytm/paytm_response/" . $session_id,
        );

        $paytmChecksum = $this->paytm_lib->getChecksumFromArray($paytmParams, $this->api_config->api_secret_key);
        $paytmParams["CHECKSUMHASH"] = $paytmChecksum;

        //$transactionURL = 'https://securegw-stage.paytm.in/order/process';
        $transactionURL = 'https://securegw.paytm.in/order/process';

        $data['paytmParams'] = $paytmParams;
        $data['transactionURL'] = $transactionURL;

        $this->load->view('payment/paytm/index', $data);
    }

 

    public function paytm_response($session_id = '') {
        // Get session_id from URL parameter (similar to Razorpay callback approach)
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        // If still no session_id, try to get from session
        if (empty($session_id)) {
            if ($this->session->has_userdata('params')) {
                $params = $this->session->userdata('params');
                $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            }
        }
        
        $paytmChecksum = "";
        $paramList = array();
        $isValidChecksum = "FALSE";

        $paramList = $_POST;
        $paytmChecksum = isset($_POST["CHECKSUMHASH"]) ? $_POST["CHECKSUMHASH"] : "";

        $isValidChecksum = $this->paytm_lib->verifychecksum_e($paramList, $this->api_config->api_secret_key, $paytmChecksum);

        if ($isValidChecksum == "TRUE") {
            if ($_POST["STATUS"] == "TXN_SUCCESS") {
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
                
                $payment_id = $_POST['TXNID'];
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
                        'description' => "Online fees deposit through Paytm Txn ID: " . $payment_id,
                        'received_by' => '',
                        'payment_mode' => 'Paytm',
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
                redirect(base_url("payment/paymentfailed"));
            }
        } else {
            redirect(base_url("payment/paymentfailed"));
        }
    }

}
