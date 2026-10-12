<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Jazzcash extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->jazzcash_api=$this->paymentsetting_model->getActiveMethod();
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
        $this->load->view('payment/jazzcash/index', $data);
    }

    public function pay() {

    	date_default_timezone_set("Asia/Karachi");
        $data['ExpiryTime'] = date('YmdHis', strtotime("+3 hours"));
		$data['TxnDateTime'] = date('YmdHis', strtotime("+0 hours"));
		$data['TxnRefNumber'] = "T". date('YmdHis');
        $input_para["pp_Version"]="2.0";
        $input_para["pp_IsRegisteredCustomer"]="Yes";
        $input_para["pp_TxnType"]="MPAY";
        $input_para["pp_TokenizedCardNumber"]="";
        $input_para["pp_CustomerID"]=time();
        $input_para["pp_CustomerEmail"]="";
        $input_para["pp_CustomerMobile"]="";
        $input_para["pp_MerchantID"]=$this->jazzcash_api->api_secret_key;
        $input_para["pp_Language"]="EN";
        $input_para["pp_SubMerchantID"]="";
        $input_para["pp_Password"]=$this->jazzcash_api->api_password;
        $input_para["pp_TxnRefNo"]="T". date('YmdHis');
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
        
        // Unified flow - calculate total from student_fees_master_array
        $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
        $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
        $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
        $total = number_format((float)(convertBaseAmountCurrencyFormat($session_params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
        
        $input_para["pp_Amount"] = $total * 100;
        $input_para["pp_DiscountedAmount"]="";
        $input_para["pp_DiscountBank"]="";
        $input_para["pp_TxnCurrency"]="PKR";
        $input_para["pp_TxnDateTime"]=date('YmdHis', strtotime("+0 hours"));
        $input_para["pp_TxnExpiryDateTime"]=date('YmdHis', strtotime("+3 hours"));
        $input_para["pp_BillReference"]=time();
        $input_para["pp_Description"]='Student Fee';
        $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
        $input_para["pp_ReturnURL"]=base_url().'gateway/jazzcash/success/' . $session_id;
        $input_para["pp_SecureHash"]="0123456789";
        $input_para["ppmpf_1"]="1";
        $input_para["ppmpf_2"]="2";
        $input_para["ppmpf_3"]="3";
        $input_para["ppmpf_4"]="4";
        $input_para["ppmpf_5"]="5";
        $data['payment_data']=$input_para;
        $this->load->view('payment/jazzcash/pay', $data);

    }

    public function success($session_id = '') {
        date_default_timezone_set("Asia/Calcutta");
        
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }

        if(isset($_POST['pp_ResponseCode']) && $_POST['pp_ResponseCode']=='000'){
            $ref_id = isset($_POST['pp_TxnRefNo']) ? $_POST['pp_TxnRefNo'] : '';
            
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
                    'description' => "Online fees deposit through Jazzcash TXN ID: " . $ref_id,
                    'received_by' => '',
                    'payment_mode' => 'Jazzcash',
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
        } elseif(isset($_POST['pp_ResponseCode']) && $_POST['pp_ResponseCode']=='112'){
            redirect(base_url("payment/paymentfailed")); 
        } else {
            $this->session->set_flashdata('msg', isset($_POST['pp_ResponseMessage']) ? $_POST['pp_ResponseMessage'] : 'Payment failed');
            redirect(site_url('gateway/jazzcash'));
        }
    }

}
