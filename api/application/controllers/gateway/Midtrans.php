<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Midtrans extends Admin_Controller {

    var $setting;
    var $payment_method;
    var $api_config;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $this->load->library('Midtrans_lib');
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
        $data['id'] = $session_id; // Pass session_id to view for callback
        
        $enable_payments = array('credit_card');
        $transaction = array(
            'enabled_payments' => $enable_payments,
            'transaction_details' => array(
                'order_id' => time(),
                'gross_amount' => round(convertBaseAmountCurrencyFormat($total)), // no decimal allowed
            ),
        );
        
        try {
            $snapToken = $this->midtrans_lib->getSnapToken($transaction, $this->api_config->api_secret_key);
            $data['snap_Token'] = $snapToken;
            $data['api_error'] = array();
        } catch (Exception $e) {
            // Catch API errors and display them in the view
            $error_message = $e->getMessage();
            $data['snap_Token'] = '';
            $data['api_error'] = array('error' => $error_message);
        }
        
        $this->load->view('payment/midtrans/index', $data);
    }

    public function success() {
        $response = json_decode($_POST['result_data']);

        $payment_id = $response->transaction_id;
        $session_id = '';
        $params = array();
        
        // Get session_id from POST first (from form), then try session
        $session_id = isset($_POST['session_id']) ? $_POST['session_id'] : '';
        
        if (empty($session_id)) {
            if ($this->session->has_userdata('params')) {
                $session_params = $this->session->userdata('params');
                $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
            }
        }
        
        if (empty($session_id)) {
            echo json_encode(array('error' => 'Session ID not found'));
            return;
        }
        
        // Get session data (similar to Razorpay callback)
        $session_data = $this->gateway_ins_model->get_api_session($session_id);
        if (!$session_data) {
            echo json_encode(array('error' => 'Session data not found'));
            return;
        }
        
        $params = json_decode($session_data['params'], true);
        
        if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
            echo json_encode(array('error' => 'Fees data not found'));
            return;
        }
        
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
                'description' => "Online fees deposit through Midtrans TXN ID: " . $payment_id,
                'received_by' => '',
                'payment_mode' => 'midtrans',
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
        
        $response_result = $this->studentfeemaster_model->fee_deposit_bulk($bulk_fees, NULL);
        
        if ($response_result) {
            $this->gateway_ins_model->delete_api_session($session_id);
            // Return success response in JSON format for AJAX
            $invoice_detail = json_decode($response_result);
            echo json_encode(array(
                'success' => true,
                'invoice_id' => $invoice_detail->invoice_id,
                'sub_invoice_id' => $invoice_detail->sub_invoice_id
            ));
        } else {
            echo json_encode(array('error' => 'Payment processing failed'));
        }
    }

}
