<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Skrill extends Admin_Controller {

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
        $this->load->view('payment/skrill/index', $data);
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
            $this->load->view('payment/skrill/index', $data);
        } else {
            $pay_method = $this->paymentsetting_model->getActiveMethod();
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $total = convertBaseAmountCurrencyFormat($params['total'] + $fine_amount - $applied_discount + $gateway_charge);
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $payment_data['pay_to_email'] = $pay_method->api_email;
            $payment_data['transaction_id'] = 'A'.time();
            $payment_data['return_url'] = base_url().'gateway/skrill/success/' . $session_id;
            $payment_data['cancel_url'] = base_url().'gateway/skrill/cancel';
            $payment_data['status_url'] = trim(base_url(),'/api').'/gateway_ins/skrill';
            $payment_data['language'] = 'EN';
            $payment_data['merchant_fields'] = 'customer_number,session_id';
            $payment_data['customer_number'] = 'C'.time();
            $payment_data['session_ID'] = 'A3D'.time();
            $payment_data['pay_from_email'] = $_POST['email'];
            $payment_data['amount2_description'] = '';
            $payment_data['amount2'] = '';
            $payment_data['amount3_description'] = '';
            $payment_data['amount3'] = '';
            $payment_data['amount4_description'] = '';
            $payment_data['amount4'] = '';
            $payment_data['amount'] = $total;
            $payment_data['currency'] = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';
            $payment_data['firstname'] = $params['name'];
            $payment_data['lastname'] = '';
            $payment_data['address'] = '';
            $payment_data['postal_code'] = '';
            $payment_data['city'] = '';
            $payment_data['country'] = '';
            $payment_data['detail1_description'] = '';
            $payment_data['detail1_text'] = '';
            $payment_data['detail2_description'] = '';
            $payment_data['detail2_text'] = '';
            $payment_data['detail3_description'] = '';
            $payment_data['detail3_text'] = '';
            
            $data['form_fields'] = $payment_data;
            $params['transaction_id'] = $payment_data['transaction_id'];
            $payment_data['fee_discount_group'] = isset($params['fee_discount_group']) ? $params['fee_discount_group'] : '';
            $ins_data = array(
                'unique_id' => $payment_data['transaction_id'],
                'parameter_details' => json_encode($payment_data),
                'gateway_name' => 'skrill',
                'module_type' => 'fees',
                'payment_status' => 'processing',
            );
            $gateway_ins_id = $this->gateway_ins_model->add_gateway_ins($ins_data);
            $bulk_fees = array();
         
            // Process bulk fees from student_fees_master_array
            if (isset($params['student_fees_master_array']) && !empty($params['student_fees_master_array'])) {
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
                        'received_by' => '',
                        'description' => "Online fees deposit through Skrill TXN ID: " . $payment_data['transaction_id'],
                        'payment_mode' => 'Skrill',
                    );
                    
                    $insert_fee_data = array(
                        'gateway_ins_id' => $gateway_ins_id,
                        'fee_category' => $fee_value['fee_category'],
                        'student_fees_master_id' => $fee_value['student_fees_master_id'],
                        'fee_groups_feetype_id' => $fee_value['fee_groups_feetype_id'],
                        'amount_detail' => $json_array,
                    );
                    
                    // Only set student_transport_fee_id if it's a transport fee and has a valid value
                    if (isset($fee_value['fee_category']) && $fee_value['fee_category'] == 'transport' && !empty($fee_value['student_transport_fee_id'])) {
                        $insert_fee_data['student_transport_fee_id'] = $fee_value['student_transport_fee_id'];
                    } else {
                        $insert_fee_data['student_transport_fee_id'] = NULL;
                    }
                    
                    $bulk_fees[] = $insert_fee_data;
                }
            }
            
            $fee_processing = $this->gateway_ins_model->fee_processing($bulk_fees);
            $this->session->set_userdata("params", $params);
            $this->load->view('payment/skrill/pay', $data);
        }
    }    

    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        $transaction_id = isset($_GET['transaction_id']) ? $_GET['transaction_id'] : '';
        if (empty($transaction_id)) {
            redirect(base_url("payment/paymentfailed"));
            return;
        }
        
        // Get session data
        if (empty($session_id)) {
            if ($this->session->has_userdata('params')) {
                $params = $this->session->userdata('params');
            } else {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
        } else {
            $session_data = $this->gateway_ins_model->get_api_session($session_id);
            if (!$session_data) {
                redirect(base_url("payment/paymentfailed"));
                return;
            }
            $params = json_decode($session_data['params'], true);
        }
        
        $parameter_data = $this->gateway_ins_model->get_gateway_ins($transaction_id, 'skrill');
        
        if($parameter_data['payment_status'] == '2'){
            // Clean up session if using api_session_id
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            $this->load->view('payment/invoice');
        } elseif(($parameter_data['payment_status'] == '-1') || ($parameter_data['payment_status'] == '-2')){
            $this->gateway_ins_model->deleteBygateway_ins_id($parameter_data['id']); 
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            $this->load->view('payment/paymentfailed');
        } else {
            $this->load->view('payment/processing');
        }
    }

    public function cancel(){
        $this->load->view('payment/paymentfailed');
    }

}
