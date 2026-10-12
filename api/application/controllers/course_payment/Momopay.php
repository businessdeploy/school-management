<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Momopay extends Admin_Controller {

    var $setting;
    var $payment_method;
    public $api_config = "";

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $this->load->model(array('gateway_ins_model', 'course_model'));
    }
  
    public function index() {
        $data = array();
        if ($this->session->has_userdata('course_amount')) {
            $session_params = $this->session->userdata('course_amount');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        }
        
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $this->load->view('course_payment/momopay/index', $data);
    }    
    
    public function pay() {
        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required|xss_clean');   
        
        $data = array();
        if ($this->session->has_userdata('course_amount')) {
            $session_params = $this->session->userdata('course_amount');
        } else {
            $session_id = $this->uri->segment(3);
            if (!empty($session_id)) {
                $session_data = $this->gateway_ins_model->get_api_session($session_id);
                $session_params = json_decode($session_data['params'], true);
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        }
        $data['params'] = $session_params;
        $data['session_params'] = $session_params;
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        
        if ($this->form_validation->run() == false) {
            $this->load->view('course_payment/momopay/index', $data);
        } else {
            $params = $session_params;
            $apidetails = $this->paymentsetting_model->getActiveMethod();
            
            // Course payment flow - calculate total from course data
            $total_amount = isset($params['total_amount']) ? $params['total_amount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $amount = number_format((float)($total_amount + $gateway_charge), 2, '.', '');

            $subscriptionKey = $apidetails->api_secret_key;
            $userId = $apidetails->api_username;
            $apiKey = $apidetails->api_publishable_key;
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $url = "https://proxy.momodeveloper.mtn.com/collection/v1_0/requesttopay";
            $uuid = sprintf(
                '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000,
                mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );

            $headers = [
                "X-Reference-Id: $userId",
                "X-Target-Environment: sandbox",
                "Ocp-Apim-Subscription-Key: $subscriptionKey",
                "Authorization: Bearer ".$this->momo_getAccessToken(),
                "Content-Type: application/json",
                "X-Callback-Url: ".base_url('course_payment/momopay/handle_callback/' . $session_id),
            ];

            $payment_data = [
                "amount" => $amount,
                "currency" => isset($params['currency_name']) ? $params['currency_name'] : 'EUR',
                "externalId" => $uuid,
                "payer" => [
                    "partyIdType" => "MSISDN",
                    "partyId" => $_POST['phone'],
                ],
                "payerMessage" => "Course Payment",
                "payeeNote" => "Thanks"
            ];

            $ch = curl_init($url);
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payment_data));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            $response = curl_exec($ch);
            
            $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            
            // Store transaction details
            $params['transaction_id'] = $uuid;
            $params['momo_external_id'] = $uuid;
            $this->session->set_userdata("course_amount", $params);
            
            $ins_data = array(
                'unique_id' => $uuid,
                'parameter_details' => json_encode($payment_data),
                'gateway_name' => 'momopay',
                'module_type' => 'course',
                'payment_status' => 'processing',
            );
            $gateway_ins_id = $this->gateway_ins_model->add_gateway_ins($ins_data);
            
            // Parse the response to extract error information
            $response_data = json_decode($response, true);
            if ($http_code == 202 || ($response_data && !isset($response_data['error']))) {
                // Payment request accepted, show processing message
                $data['api_error'] = array();
                $data['trans_ref'] = $uuid;
                $data['processing'] = true;
                $this->load->view('course_payment/momopay/index', $data);
            } else {
                if ($response_data) {
                    $data['api_error'] = $response_data;
                } else {
                    $data['api_error'] = array(
                        'message' => 'Payment request failed',
                        'details' => $response
                    );
                }
                $this->load->view('course_payment/momopay/index', $data);
            }
        }
    }

    public function handle_callback($session_id = ''){
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        $response = json_decode(file_get_contents('php://input'), true);

        log_message('error', 'MomoPay Callback: ' . print_r($response, true));

        if (isset($response['externalId'])) {
            $status = $this->_check_payment_status($response['externalId'], $session_id);

            if ($status === 'SUCCESSFUL') {
                $this->success($response['externalId'], $session_id);
            } else {
                log_message('error', 'MomoPay Payment Failed or Pending: ' . $status);
                redirect(base_url('course_payment/course_payment/paymentfailed'));
            }
        } else {
            log_message('error', 'MomoPay Callback: Invalid response, missing externalId');
        }
    }

    private function _check_payment_status($reference_id, $session_id = '') {
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $url = "https://sandbox.momodeveloper.mtn.com/collection/v1_0/requesttopay/" . $reference_id;

        $headers = [
            "Ocp-Apim-Subscription-Key: " . $this->api_config->api_secret_key,
            "Authorization: Bearer " . $this->momo_getAccessToken(),
            "X-Target-Environment: sandbox",
        ];

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        curl_close($ch);

        $result = json_decode($response, true);
        
        log_message('error', 'MomoPay Status Check Response: ' . print_r($result, true));

        return isset($result['status']) ? $result['status'] : null;
    }

    function momo_getAccessToken() {
        $cached_token = $this->session->userdata('momo_access_token');
        if ($cached_token && (time() < $cached_token['expires_at'])) {
            return $cached_token['access_token'];
        }

        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $subscriptionKey = $this->api_config->api_secret_key;
        $userId = $this->api_config->api_username;
        $apiKey = $this->api_config->api_publishable_key;
        $url = "https://proxy.momodeveloper.mtn.com/collection/token/";

        $headers = [       
            "Authorization: Basic " . base64_encode($userId.':'.$apiKey),
            "Ocp-Apim-Subscription-Key: $subscriptionKey",
            'Cache-Control: no-cache',
            'Content-Length: 0',
        ];

        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

        $response = curl_exec($ch);
        curl_close($ch);

        $result = json_decode($response, true);
   
        if (isset($result['access_token'])) {
            $token_data = [
                'access_token' => $result['access_token'],
                'expires_at' => time() + $result['expires_in'] - 300 // 5 minutes buffer
            ];
            $this->session->set_userdata('momo_access_token', $token_data);
            return $result['access_token'];
        }

        return null;
    }

    public function success($TransRef, $session_id = '') {
        // Get session_id from URL parameter
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        // Get session data
        if (empty($session_id)) {
            if ($this->session->has_userdata('course_amount')) {
                $params = $this->session->userdata('course_amount');
            } else {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
        } else {
            $session_data = $this->gateway_ins_model->get_api_session($session_id);
            if (!$session_data) {
                redirect(base_url("course_payment/course_payment/paymentfailed"));
                return;
            }
            $params = json_decode($session_data['params'], true);
        }
        
        if (!isset($params['courseid']) || empty($params['courseid'])) {
            redirect(base_url("course_payment/course_payment/paymentfailed"));
            return;
        }
        
        // Course payment data structure
        $payment_data = array(
            'date' => date('Y-m-d'),
            'student_id' => $params['student_id'],
            'online_courses_id' => $params['courseid'],
            'course_name' => $params['course_name'],
            'actual_price' => $params['actual_amount'],
            'paid_amount' => $params['total_amount'],
            'payment_type' => 'Online',
            'transaction_id' => $TransRef,
            'note' => "Online course fees deposit through MomoPay Txn ID: " . $TransRef,
            'payment_mode' => 'MomoPay',
        );
        
        $response = $this->course_model->add($payment_data);
        
        if ($response) {
            // Clean up session if using api_session_id
            if (!empty($session_id)) {
                $this->gateway_ins_model->delete_api_session($session_id);
            }
            redirect("course_payment/course_payment/paymentsuccess", "refresh");
        } else {
            redirect(base_url("course_payment/course_payment/paymentfailed"));
        }
    }

}
