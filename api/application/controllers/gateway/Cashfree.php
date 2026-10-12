<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Cashfree extends Admin_Controller {

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
        $this->load->view('payment/cashfree/index', $data);
    }

    public function pay() {

        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');
        $data = array();
       
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
            $this->load->view('payment/cashfree/index', $data);
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
            
            $data['name'] = $params['name'];
            $amount = $total;
            $api = ' ' . $pay_method->api_publishable_key;
            $customer_id = "Student_id_" . $params['student_id'];
            $order_id = "order_" . time() . mt_rand(100,999);
            $currency = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';
            $redirectUrl = base_url()."gateway/cashfree/success/" . $session_id . "?order_id={order_id}&order_token={order_token}";

            $my_array=array(
            "order_id"=> $order_id,
            "order_amount"=> $amount,
            "order_currency"=> $currency,
            "customer_details"=> array(
            "customer_id"=> $customer_id,
            "customer_name"=> $data['name'],
            "customer_email"=> $_POST['email'],
            "customer_phone"=> $_POST['phone'],
            ),
            "order_meta"=> array(
            "return_url"=> $redirectUrl,
            "notify_url"=> base_url() .'webhooks/cashfree',
            "payment_methods"=> ""
            )
        );
        $new_arrya=(object)$my_array;
            $ch = curl_init();

            curl_setopt($ch, CURLOPT_URL, 'https://api.cashfree.com/pg/orders');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($new_arrya));

            $headers = array();
            $headers[] = 'Content-Type: application/json';
            $headers[] = 'X-Api-Version: 2021-05-21';
            $headers[] = 'X-Client-Id: '.$pay_method->api_publishable_key;
            $headers[] = 'X-Client-Secret: '.$pay_method->api_secret_key;
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

            $result = curl_exec($ch);
            if (curl_errno($ch)) {
                echo 'Error:' . curl_error($ch);
            }
            curl_close($ch);
            $json=json_decode($result);

            if (isset($json->order_status) && $json->order_status="ACTIVE") {
                $url = $json->payment_link;
               
                header("Location: $url");
            } else {
                $data['api_error'] = isset($json->message) ? $json->message : 'Payment initialization failed';
                $this->load->view('payment/cashfree/index', $data);
            }
        }
    }

    public function success($session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        $pay_method = $this->paymentsetting_model->getActiveMethod();
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, 'https://api.cashfree.com/pg/orders/'.$_GET['order_id']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'GET');
        $headers = array();
        $headers[] = 'Content-Type: application/json';
        $headers[] = 'X-Api-Version: 2021-05-21';
        $headers[] = 'X-Client-Id: '.$pay_method->api_publishable_key;
        $headers[] = 'X-Client-Secret: '.$pay_method->api_secret_key;
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            echo 'Error:' . curl_error($ch);
        }
        curl_close($ch);
        $payment_data = json_decode($result);
        
        if (isset($payment_data->order_status) && $payment_data->order_status=="PAID") {
            $payment_id = isset($_GET['order_id']) ? $_GET['order_id'] : '';
            
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
            
            $ref_id = $payment_id;
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
                    'description' => "Online fees deposit through Cashfree TXN ID: " . $ref_id,
                    'received_by' => '',
                    'payment_mode' => 'Cashfree',
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
        } else {
            redirect(base_url('payment/paymentfailed'));
        }
    }

}
