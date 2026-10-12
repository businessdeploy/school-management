<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Toyyibpay extends Admin_Controller {

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
        $this->load->view('payment/toyyibpay/index', $data);
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
        $result = "";
        
        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');
        
        if ($this->form_validation->run() == false) {
            $this->load->view('payment/toyyibpay/index', $data);
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
            
            $payment_data = array(
                'userSecretKey' => $pay_method->api_secret_key,
                'categoryCode' => $pay_method->api_signature,
                'billName' => 'Fees',
                'billDescription' => 'Student Fees',
                'billPriceSetting' => 1,
                'billPayorInfo' => 1,
                'billAmount' => $total,
                'billReturnUrl' => base_url().'gateway/toyyibpay/success/' . $session_id,
                'billCallbackUrl' => trim(base_url(),'/api').'/gateway_ins/toyyibpay',
                'billExternalReferenceNo' => time().rand(99,999),
                'billTo' => $params['name'],
                'billEmail' => $_POST['email'],
                'billPhone' => $_POST['phone'],
                'billSplitPayment' => 0,
                'billSplitPaymentArgs' => '',
                'billPaymentChannel' => '0',
                'billContentEmail' => 'Thank you for fees submission!',
                'billChargeToCustomer' => 1
            );  
           
            $curl = curl_init();
            curl_setopt($curl, CURLOPT_POST, 1);
            curl_setopt($curl, CURLOPT_URL, 'https://toyyibpay.com/index.php/api/createBill');  
            curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($curl, CURLOPT_POSTFIELDS, $payment_data);

            $result = curl_exec($curl);
            $info = curl_getinfo($curl);  
            curl_close($curl);
            $obj = json_decode($result);

            if (!empty($obj)) {
                $params['transaction_id'] = $payment_data['billExternalReferenceNo'];
                $this->session->set_userdata("params", $params);
                $payment_data['fee_discount_group'] = isset($params['fee_discount_group']) ? $params['fee_discount_group'] : '';
                $ins_data = array(
                    'unique_id' => $payment_data['billExternalReferenceNo'],
                    'parameter_details' => json_encode($payment_data),
                    'gateway_name' => 'toyyibpay',
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
                            'description' => "Online fees deposit through Toyyibpay TXN ID: " . $payment_data['billExternalReferenceNo'],
                            'payment_mode' => 'Toyyibpay',
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

                if((isset($obj->status) && $obj->status=='error')){
                    $result = $obj->msg;  
                    $data['api_error'] = $result;
                    $this->load->view('payment/toyyibpay/index', $data);
                } else {
                    $url = "https://toyyibpay.com/".$obj[0]->BillCode;
                    header("Location: $url");
                }
            } else {
                $data['api_error'] = "Payment initialization failed";
                $this->load->view('payment/toyyibpay/index', $data);
            }
        }
    }
    

    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
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
        
        $transaction_id = isset($params['transaction_id']) ? $params['transaction_id'] : '';
        if (empty($transaction_id)) {
            redirect(base_url("payment/paymentfailed"));
            return;
        }
        
        $parameter_data = $this->gateway_ins_model->get_gateway_ins($transaction_id, 'toyyibpay');
        
        if($parameter_data['payment_status'] == '1'){
            // Clean up session if using api_session_id
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            $this->load->view('payment/invoice');
        } elseif($parameter_data['payment_status'] == '3'){
            $this->gateway_ins_model->deleteBygateway_ins_id($parameter_data['id']); 
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            $this->load->view('payment/paymentfailed');
        } else {
            $this->load->view('payment/processing');
        }
    }

}
