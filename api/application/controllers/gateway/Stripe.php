<?php

defined('BASEPATH') or exit('No direct script access allowed');
//require_once APPPATH . 'third_party/stripe/init.php';

class Stripe extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->library('stripe_payment');
        $this->load->model(array('gateway_ins_model'));
    }


    public function create_payment_intent()
    {
        // $params                        = $this->session->userdata('params');
        // $data                = $this->input->post();
        // $data['description'] = $this->lang->line("online_fees_deposit");
        // $data['currency']    = $params['invoice']->currency_name;

        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);
        
        $this->stripe_payment->PaymentIntent($jsonObj );
    }

    public function create_customer()
    {
        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);

        $user_detail = $this->session->userdata('params');
        $jsonObj = new stdClass();
        $jsonObj->fullname = $user_detail['name'];
        $jsonObj->email = isset($user_detail['guardian_email']) ? $user_detail['guardian_email'] : (isset($user_detail['email']) ? $user_detail['email'] : '');
       
        $this->stripe_payment->AddCustomer($jsonObj);
    }

     public function insert_payment()
    {

        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);
        $return_response = $this->stripe_payment->InsertTransaction($jsonObj);
        if ($return_response['status']) {
            $payment = $return_response['payment'];
            // If transaction was successful
            if (!empty($payment) && $payment->status == 'succeeded') {
                $params              = $this->session->userdata('params');
                $data                =[];
                $data['description'] = $this->lang->line("online_fees_deposit");
                // Handle invoice (can be object or array)
                if (is_array($params['invoice'])) {
                    $data['currency'] = $params['invoice']['currency_name'];
                } else {
                    $data['currency'] = $params['invoice']->currency_name;
                }
                // Retrieve transaction details
                $transaction_id = $payment->id;

                //=====================================


                $payment_data['transactionid'] = $transaction_id;
                $params = $this->session->userdata('params');
                $ref_id = $transaction_id;
                
                $bulk_fees = array();
                
                // Unified flow - handle both single and multi payments using student_fees_master_array
                if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                    echo json_encode(['status'=>0,'msg' => 'Invalid payment data.','return_url'=>base_url('payment/paymentfailed')]);
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
                        'description' => "Online fees deposit through Stripe TXN ID: " . $ref_id,
                        'received_by' => '',
                        'payment_mode' => 'Stripe',
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
                    echo json_encode(['status'=>1,'msg' => 'Transaction successful.','return_url'=>base_url("payment/successinvoice")]);
                } else {
                    echo json_encode(['status'=>0,'msg' => 'Failed to process payment.','return_url'=>base_url('payment/paymentfailed')]);
                }

                //=====================================



            } else {
                http_response_code(500);
                echo json_encode(['status'=>0,'msg' => 'Transaction has been failed!','return_url'=>base_url('payment/paymentfailed')]);
            }
        } else {
            http_response_code(500);
            echo json_encode(['status'=>0,'msg' => $return_response['error']]);
        }
    }

    public function index() {
        $error= array();
        $data = array();
        $session_params = $this->session->userdata('params');

        $pay_method = $this->paymentsetting_model->getActiveMethod();
        if ($pay_method->payment_type == "stripe") {
            $data = array();
            if ($this->session->has_userdata('params')) {
                if ($pay_method->api_secret_key != "" && $pay_method->api_publishable_key != "") {
                    // Unified flow - calculate total from student_fees_master_array
                    $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
                    $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
                    $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
                    $total = number_format((float)(convertBaseAmountCurrencyFormat($session_params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
                    
                    $data['setting'] = $this->setting;
                    $data['session_params'] = $session_params;
                    $data['params'] = $session_params;
                    $data['session_params']['api_publishable_key'] = $pay_method->api_publishable_key;
                   
                    $this->load->view('payment/stripe/pay', $data);
                }
            }
        } else {
            $this->session->set_flashdata('error', 'Oops! Something went wrong');
            $this->load->view('payment/error');
        }
    }

}
