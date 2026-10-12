<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Sslcommerz extends Admin_Controller {

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
        $this->load->view('payment/sslcommerz/index', $data);
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
            $this->load->view('payment/sslcommerz/index', $data);
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
            
            $requestData = array();
            $CURLOPT_POSTFIELDS = array(
                'store_id'         => $pay_method->api_publishable_key,
                'store_passwd'     => $pay_method->api_password,
                'total_amount'     => $total,
                'currency'         => isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '',
                'tran_id'          => abs(crc32(uniqid())),
                'success_url'      => base_url() . 'gateway/sslcommerz/success/' . $session_id,
                'fail_url'         => base_url() . 'gateway/sslcommerz/fail',
                'cancel_url'       => base_url() . 'gateway/sslcommerz/cancel',
                'cus_name'         => $params['name'],
                'cus_email'        => !empty($_POST['email']) ? $_POST['email'] : "example@email.com",
                'cus_add1'         =>  "Dhaka",
                'cus_phone'        => !empty($_POST['phone']) ? $_POST['phone'] : "01711111111",
                'cus_city'         => '',
                'cus_country'      => '',
                'multi_card_name'  => 'mastercard,visacard,amexcard,internetbank,mobilebank,othercard ',
                'shipping_method'  => 'NO',
                'product_name'     => 'test',
                'product_category' => 'Electronic',
                'product_profile'  => 'general',
            );
        $string = "";
        foreach ($CURLOPT_POSTFIELDS as $key => $value) {
            $string .= $key . '=' . $value . "&";
            if ($key == 'product_profile') {
                $string .= $key . '=' . $value;
            }
        }

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://sandbox.sslcommerz.com/gwprocess/v4/api.php');//for sand box https://sandbox.sslcommerz.com/gwprocess/v4/api.php
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_POST, 1);
        curl_setopt($ch, CURLOPT_POSTFIELDS, "$string");

        $headers   = array();
        $headers[] = 'Content-Type: application/x-www-form-urlencoded';
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            echo 'Error:' . curl_error($ch);
        }
        curl_close($ch);
        $response = json_decode($result);
       
            if($response->status=='FAILED'){
                $data['api_error'] = isset($response->failedreason) ? $response->failedreason : 'Payment failed';
                $this->load->view('payment/sslcommerz/index', $data);
            } else {
                header("Location: $response->GatewayPageURL");
            }
        }
    }
 
    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        if (isset($_POST['status']) && $_POST['status'] == 'VALID') {
            $payment_id = isset($_POST['val_id']) ? $_POST['val_id'] : '';
            if ($payment_id) {
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
                        'description' => "Online fees deposit through Sslcommerz TXN ID: " . $payment_id,
                        'received_by' => '',
                        'payment_mode' => 'Sslcommerz',
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
