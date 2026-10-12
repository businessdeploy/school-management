<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Flutterwave extends Admin_Controller {

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
        $this->load->view('payment/flutterwave/index', $data);
    }

    public function pay() {

        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required');

            if ($this->form_validation->run() == false) {
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
            $this->load->view('payment/flutterwave/index', $data);
        } else {

           
       

            $pay_method = $this->paymentsetting_model->getActiveMethod();
            if ($this->session->has_userdata('params')) {
                $session_params = $this->session->userdata('params');
                $data['session_params'] = $session_params;
            }

            $amount = $data['session_params']['total'];
            $secret_key = $pay_method->api_secret_key;
            $public_key = $pay_method->api_publishable_key;
            $data['currency_code'] = $session_params['invoice']->currency_name;
           
            $curl = curl_init();
            $customer_email = $_POST['email'];
            $currency = $data['currency_code'];
            $txref = "rave" . uniqid();
            $PBFPubKey = $public_key; 
            $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
            $redirect_url = base_url() . 'gateway/flutterwave/success/' . $session_id;
            curl_setopt_array($curl, array(
              CURLOPT_URL => "https://api.ravepay.co/flwv3-pug/getpaidx/api/v2/hosted/pay",
              CURLOPT_RETURNTRANSFER => true,
              CURLOPT_CUSTOMREQUEST => "POST",
              CURLOPT_POSTFIELDS => json_encode([
                'amount' => number_format((float)(convertBaseAmountCurrencyFormat((isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0) + $session_params['total'] - (isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0) + (isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0))), 2, '.', ''),
                'customer_email'=>$customer_email,
                'currency'=>$currency,
                'txref'=>$txref,
                'PBFPubKey'=>$PBFPubKey,
                'redirect_url'=>$redirect_url,
              ]),
              CURLOPT_HTTPHEADER => [
                "content-type: application/json",
                "cache-control: no-cache"
              ],
            ));

            $response = curl_exec($curl);
            $err = curl_error($curl);

            if($err){
                $data = array();
                $data['params'] = $session_params;
                $data['session_params'] = $session_params;
                $data['setting'] = $this->setting;
                $data['api_error'] = array('error' => 'Curl returned error: ' . $err);
                $data['student_data'] = $this->student_model->get($session_params['student_id']);
                $this->load->view('payment/flutterwave/index', $data);
                return;
            }

            $transaction = json_decode($response);

            if(!$transaction->data || !isset($transaction->data->link)){
                $data = array();
                $data['params'] = $session_params;
                $data['session_params'] = $session_params;
                $data['setting'] = $this->setting;
                $data['api_error'] = array('error' => 'API returned error: ' . (isset($transaction->message) ? $transaction->message : 'Unknown error'));
                $data['student_data'] = $this->student_model->get($session_params['student_id']);
                $this->load->view('payment/flutterwave/index', $data);
                return;
            }

           

            header('Location: ' . $transaction->data->link);
            

           
        }
    }

    
    public function success($session_id = '') {
        $pay_method = $this->paymentsetting_model->getActiveMethod();
        $secret_key = $pay_method->api_secret_key;
        
        // Get session_id from URL parameter (similar to Razorpay callback approach)
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        if (isset($_GET['txref'])) {
            $ref = $_GET['txref'];
            
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
            $amount = $params['total'];
            $currency = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';

            $query = array(
                "SECKEY" => $secret_key,
                "txref" => $ref
            );

            $data_string = json_encode($query);
                    
            $ch = curl_init('https://api.ravepay.co/flwv3-pug/getpaidx/api/v2/verify');                                                                      
            curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
            curl_setopt($ch, CURLOPT_POSTFIELDS, $data_string);                                              
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));

            $response = curl_exec($ch);
            curl_close($ch); 

            $resp = json_decode($response, true);

            if (isset($resp['data'])) {
                $paymentStatus = $resp['data']['status'];
                $chargeResponsecode = $resp['data']['chargecode'];
                $chargeAmount = $resp['data']['amount'];
                $chargeCurrency = $resp['data']['currency'];
                $txid = $resp['data']['txref'];
                
                if (($chargeResponsecode == "00" || $chargeResponsecode == "0") && ($chargeAmount == $amount) && ($chargeCurrency == $currency)) {
                    if ($txid) {
                        if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                            redirect(base_url("payment/paymentfailed"));
                            return;
                        }
                        
                        $ref_id = $txid;
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
                                'description' => "Online fees deposit through Flutterwave TXN ID: " . $ref_id,
                                'received_by' => '',
                                'payment_mode' => 'Flutterwave',
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
            } else {
                redirect(base_url("payment/paymentfailed"));
            }
        } else {
            redirect(base_url("payment/paymentfailed"));
        }
    }

}
