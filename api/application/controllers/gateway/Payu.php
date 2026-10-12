<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Payu extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
    }

    public function index() {

        $pay_method = $this->paymentsetting_model->getActiveMethod();

        if ($pay_method->payment_type == "payu") {
            $data = array();
            if ($this->session->has_userdata('params')) {
                if ($pay_method->api_secret_key != "" && $pay_method->salt != "") {

                    $data = array();
                    $session_params = $this->session->userdata('params');
                    
                    // Unified flow - calculate total from student_fees_master_array
                    $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
                    $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
                    $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
                    $total = number_format((float)(convertBaseAmountCurrencyFormat($session_params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
                    
                    // Build product info from student_fees_master_array
                    $product_info = 'Student Fees';
                    if (isset($session_params['student_fees_master_array']) && !empty($session_params['student_fees_master_array'])) {
                        $fee_names = array();
                        foreach ($session_params['student_fees_master_array'] as $fee) {
                            $fee_name = isset($fee['fee_group_name']) ? $fee['fee_group_name'] : '';
                            $fee_code = isset($fee['fee_type_code']) ? $fee['fee_type_code'] : '';
                            if ($fee_name && $fee_code) {
                                $fee_names[] = $fee_name . ' - ' . $fee_code;
                            }
                        }
                        if (!empty($fee_names)) {
                            $product_info = implode(', ', $fee_names);
                        }
                    }
                    
                    $data['product_info'] = $product_info;
                    $data['session_params'] = $session_params;
                    $data['params'] = $session_params;
                    $data['setting'] = $this->setting;
                    // Merchant key here as provided by Payu
                    $data['MERCHANT_KEY'] = $pay_method->api_secret_key;
                    // Merchant Salt as provided by Payu
                    $SALT = $pay_method->salt;
                    // End point - change to https://secure.payu.in for LIVE mode
                    $PAYU_BASE_URL = "https://secure.payu.in";
                    $data['action'] = '';
                    $data['surl'] = site_url('gateway/payu/success');
                    $data['furl'] = site_url('gateway/payu/success');

                    $posted = array();
                    if (!empty($_POST)) {

                        foreach ($_POST as $key => $value) {

                            $posted[$key] = $value;
                        }
                    }

                    $data['posted'] = $posted;
                    $data['formError'] = 0;
                    if (empty($posted['txnid'])) {
                        // Generate random transaction id
                        $data['txnid'] = substr(hash('sha256', mt_rand() . microtime()), 0, 20);
                    } else {
                        $data['txnid'] = $posted['txnid'];
                    }
                    $session_params['txn_id'] = $data['txnid'];
                    $this->session->set_userdata("params", $session_params);
                    $data['hash'] = '';
// Hash Sequence
                    $hashSequence = "key|txnid|amount|productinfo|firstname|email|udf1|udf2|udf3|udf4|udf5|udf6|udf7|udf8|udf9|udf10";
                    if (empty($posted['hash']) && sizeof($posted) > 0) {

                        if (
                                empty($posted['key']) || empty($posted['txnid']) || empty($posted['amount']) || empty($posted['firstname']) || empty($posted['email']) || empty($posted['phone']) || empty($posted['productinfo']) || empty($posted['surl']) || empty($posted['furl']) || empty($posted['service_provider'])
                        ) {
                            $formError = 1;
                        } else {

                            $hashVarsSeq = explode('|', $hashSequence);
                            $hash_string = '';
                            foreach ($hashVarsSeq as $hash_var) {
                                $hash_string .= isset($posted[$hash_var]) ? $posted[$hash_var] : '';
                                $hash_string .= '|';
                            }

                            $hash_string .= $SALT;

                            $data['hash'] = strtolower(hash('sha512', $hash_string));
                            $data['action'] = $PAYU_BASE_URL . '/_payment';
                        }

                    } elseif (!empty($posted['hash'])) {
                        $data['hash'] = $posted['hash'];
                        $data['action'] = $PAYU_BASE_URL . '/_payment';
                    }

                    $this->load->view('payment/payu/index', $data);
                }
            }
        } else {
            $this->session->set_flashdata('error', 'Oops! Something went wrong');
            $this->load->view('payment/error');
        }
    }

    public function success() {
        if ($this->input->server('REQUEST_METHOD') == 'POST') {
            if ($this->input->post('status') == "success") {
                $mihpayid = $this->input->post('mihpayid');
                $transactionid = $this->input->post('txnid');
                
                // Get params from session
                $params = $this->session->userdata('params');
                $txn_id = isset($params['txn_id']) ? $params['txn_id'] : '';

                if ($txn_id == $transactionid || empty($txn_id)) {
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
                            'description' => "Online fees deposit through PayU TXN ID: " . $transactionid . " PayU Ref ID: " . $mihpayid,
                            'received_by' => '',
                            'payment_mode' => 'PayU',
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
                        redirect("payment/successinvoice", "refresh");
                    } else {
                        redirect(base_url("payment/paymentfailed"));
                    }
                } else {
                    redirect('payment/paymentfailed', 'refresh');
                }
            } else {
                redirect('payment/paymentfailed', 'refresh');
            }
        }
    }

}
