<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Ccavenue extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->library('Ccavenue_crypto');
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
        $this->load->view('payment/ccavenue/index', $data);
    }

    public function pay() {
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
            $this->load->view('payment/ccavenue/index', $data);
        } else {
            $pay_method = $this->paymentsetting_model->getActiveMethod();
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
            $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
            $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
            $total = convertBaseAmountCurrencyFormat($session_params['total'] + $fine_amount - $applied_discount + $gateway_charge);
            
            $details['tid']=abs(crc32(uniqid()));
            $details['merchant_id']=$pay_method->api_secret_key;
            $details['order_id']=abs(crc32(uniqid()));
            $details['amount']=$total;
            $details['currency']='INR';
            $details['redirect_url']=base_url('gateway/ccavenue/success'); 
            $details['cancel_url']=base_url('gateway/ccavenue/cancel');
            $details['language'] = "EN";
            $details['billing_name']     = $session_params['name'];
            $details['billing_email']= $_POST['email'];
            $details['billing_tel']= $_POST['phone'];
            $merchant_data="";
            foreach ($details as $key => $value){
            $merchant_data.=$key.'='.$value.'&';
            } 
           $data['encRequest'] = $this->ccavenue_crypto->encrypt($merchant_data,$pay_method->salt);
           $data['access_code'] = $pay_method->api_publishable_key;

            $this->load->view('payment/ccavenue/pay', $data);
        }
    }

    public function success() {
        $pay_method = $this->paymentsetting_model->getActiveMethod();
        $encResponse=$_POST["encResp"];  
        $rcvdString=$this->ccavenue_crypto->decrypt($encResponse,$pay_method->salt);  
        
        $session_id = '';
        if ($this->session->has_userdata('params')) {
            $params = $this->session->userdata('params');
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
        } else {
            $session_id = isset($_GET['session_id']) ? $_GET['session_id'] : '';
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
        }
        
        $order_status=array();
        $decryptValues=explode('&', $rcvdString);
        $dataSize=sizeof($decryptValues);
        for($i = 0; $i < $dataSize; $i++) 
        {
            $information=explode('=',$decryptValues[$i]);
            $status[$information[0]]=$information[1];
        }
        if($status['order_status']=="Success")
        { 
            $tracking_id = $status['tracking_id'];
            $bank_ref_no = $status['bank_ref_no'];
            $bulk_fees = array();
            
            if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
            
            foreach ($params['student_fees_master_array'] as $fee_key => $fee_value) {
                $fee_discount_amount = isset($fee_value['discount_amount']) ? $fee_value['discount_amount'] : 0;
                
                $json_array = array(
                    'amount' => $fee_value['amount_balance'],
                    'date' => date('Y-m-d'),
                    'amount_discount' => $fee_discount_amount,
                    'processing_charge_type' => isset($params['processing_charge_type']) ? $params['processing_charge_type'] : '',
                    'gateway_processing_charge' => isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0,
                    'amount_fine' => $fee_value['fine_balance'],
                    'description' => "Online fees deposit through CCAvenue. TXN ID: " . $tracking_id . " Bank Ref. No.: " . $bank_ref_no,
                    'received_by' => '',
                    'payment_mode' => 'Ccavenue',
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
                if (isset($session_id) && !empty($session_id)) {
                    $this->gateway_ins_model->delete_api_session($session_id);
                }
                redirect("payment/successinvoice", "refresh");
            } else {
                redirect(base_url("payment/paymentfailed"));
            }
        }else if($status['order_status']==="Aborted"){
            echo "<br>We will keep you posted regarding the status of your order through e-mail";
        }else if($status['order_status']==="Failure"){
            redirect(base_url("payment/paymentfailed"));
        }else{
            echo "<br>Security Error. Illegal access detected";
        }
    }
}
