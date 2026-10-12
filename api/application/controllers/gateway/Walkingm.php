<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Walkingm extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();
        $this->load->library('Walkingm_lib');
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
        $data['api_error'] = "";
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $this->load->view('payment/walkingm/index', $data);
    }

    public function pay() {

        
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');
        $this->form_validation->set_rules('password', ('Password'), 'trim|required');
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
            $this->load->view('payment/walkingm/index', $data);
        } else {
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $total = number_format((float)(convertBaseAmountCurrencyFormat($params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $payment_array['payer'] = "Walkingm";
            $payment_array['amount'] = $total;
            $payment_array['currency'] = $this->setting[0]['currency'];
            $payment_array['successUrl'] = base_url()."gateway/walkingm/success/" . $session_id;
            $payment_array['cancelUrl'] = base_url()."gateway/walkingm/cancel";
            $responce = $this->walkingm_lib->walkingm_login($_POST['email'], $_POST['password'], $payment_array);

            if($responce != ""){
                $data['api_error'] = $responce;
                $this->load->view('payment/walkingm/index', $data);
            }
        } 
        }
    

    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        $responce = base64_decode($_SERVER["QUERY_STRING"]);
        $payment_responce = json_decode($responce);
        
        if ($responce != '' && isset($payment_responce->status) && $payment_responce->status == 200) {
            $transaction_id = isset($payment_responce->transaction_id) ? $payment_responce->transaction_id : '';
            if ($transaction_id) {
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
                
                $ref_id = $transaction_id;
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
                        'description' => "Online fees deposit through Walkingm TXN ID: " . $ref_id,
                        'received_by' => '',
                        'payment_mode' => 'Walkingm',
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

      public function cancel() {
        redirect(base_url("payment/paymentfailed"));
      }

}
