<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Ipayafrica extends Admin_Controller {

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
        $this->load->view('payment/ipayafrica/index', $data);
    }

    public function pay() {

        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');

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
            $this->load->view('payment/ipayafrica/index', $data);
        } else {
            $pay_method = $this->paymentsetting_model->getActiveMethod();
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $total = number_format((float)(convertBaseAmountCurrencyFormat($params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $fields = array("live"=> "1",
                    "oid"=> uniqid(),
                    "inv"=> time(),
                    "ttl"=> $total,
                    "tel"=> $_POST['phone'],
                    "eml"=> $_POST['email'],
                    "vid"=> ($pay_method->api_publishable_key),
                    "curr"=> isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '',
                    "p1"=> "airtel",
                    "p2"=> "",
                    "p3"=> "",
                    "p4"=> $params['total'],
                    "cbk"=> base_url().'gateway/ipayafrica/success/' . $session_id,
                    "cst"=> "1",
                    "crl"=> "2"
                    );
             
            $datastring =  $fields['live'].$fields['oid'].$fields['inv'].$fields['ttl'].$fields['tel'].$fields['eml'].$fields['vid'].$fields['curr'].$fields['p1'].$fields['p2'].$fields['p3'].$fields['p4'].$fields['cbk'].$fields['cst'].$fields['crl'];

            $hashkey =($pay_method->api_secret_key);
            $generated_hash = hash_hmac('sha1',$datastring , $hashkey);
            $data['fields']=$fields;
            $data['generated_hash']=$generated_hash;
            $this->load->view('payment/ipayafrica/pay', $data);

        
        }
    }

    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        if (!empty($_GET['status'])) {
            $purchaseId = isset($_GET['txncd']) ? $_GET['txncd'] : '';
            if ($purchaseId) {
                // Get session data
                if (empty($session_id)) {
                    if ($this->session->has_userdata('params')) {
                        $session_params = $this->session->userdata('params');
                        $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
                    }
                }
                
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
                
                $ref_id = $purchaseId;
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
                        'description' => "Online fees deposit through iPayafrica TXN ID: " . $ref_id,
                        'received_by' => '',
                        'payment_mode' => 'Ipayafrica',
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
