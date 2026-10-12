<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Paypal extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();
        $this->load->library('paypal_payment');
        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->model(array('course_model', 'gateway_ins_model'));
    }

    public function index() {

        $pay_method = $this->paymentsetting_model->getActiveMethod();
        if ($pay_method->payment_type == "paypal") {
            $data = array();
            if ($this->session->has_userdata('params')) {
                if ($pay_method->api_username != "" && $pay_method->api_password != "" && $pay_method->api_signature != "") {
                    $session_params = $this->session->userdata('params');
                    $data['session_params'] = $session_params;
                    $data['params'] = $session_params;
                    $data['setting'] = $this->setting;
                    $this->load->view('payment/paypal/index', $data);
                }
            }
        } else {
            $this->session->set_flashdata('error', 'Oops! Something went wrong');
            $this->load->view('payment/error');
        }
    }

    public function pay() {
        if ($this->input->server('REQUEST_METHOD') == 'POST') {
            $session_params = $this->session->userdata('params');
            
            // Handle invoice (can be object or array)
            if (is_array($session_params['invoice'])) {
                $invoice_array = (object)$session_params['invoice'];
            } else {
                $invoice_array = $session_params['invoice'];
            }
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
            $applied_discount = isset($session_params['applied_fee_discount']) ? $session_params['applied_fee_discount'] : 0;
            $gateway_charge = isset($session_params['gateway_processing_charge']) ? $session_params['gateway_processing_charge'] : 0;
            $total_amount = $session_params['total'] + $fine_amount - $applied_discount + $gateway_charge;
            
            $data = array();
            $data['total'] = convertBaseAmountCurrencyFormat($total_amount);
            $data['symbol'] = $invoice_array->symbol;
            $data['currency_name'] = $invoice_array->currency_name;
            $data['name'] = $session_params['name'];
            $data['student_id'] = $session_params['student_id'];
            $data['guardian_phone'] = $session_params['guardian_phone'];
            $payment = array(
            'cancelUrl' => site_url('gateway/paypal/getsuccesspayment'),
            'returnUrl' => site_url('gateway/paypal/getsuccesspayment'),
            'guardian_phone' => $data['guardian_phone'],
            'name' => $data['name'],
            'description' => 'Student Fees',
            'amount' => $data['total'],
            'currency' => $data['currency_name'],
            );

            $response = $this->paypal_payment->payment($payment);

            if ($response->isSuccessful()) {
                
            } elseif ($response->isRedirect()) {
                $response->redirect();
            } else {
                echo $response->getMessage();
            }
        }
    }

    //paypal successpayment
    public function getsuccesspayment() {
            $session_params = $this->session->userdata('params');
            
            // Handle invoice (can be object or array)
            if (is_array($session_params['invoice'])) {
                $invoice_array = (object)$session_params['invoice'];
            } else {
                $invoice_array = $session_params['invoice'];
            }
            
            $data = array();
            $data['total'] = $session_params['total'];
            $data['symbol'] = $invoice_array->symbol;
            $data['currency_name'] = $invoice_array->currency_name;
            $data['name'] = $session_params['name'];
            $data['student_id'] = $session_params['student_id'];
            $data['guardian_phone'] = $session_params['guardian_phone'];
            $success_params = array(
            'cancelUrl' => site_url('gateway/paypal/getsuccesspayment'),
            'returnUrl' => site_url('gateway/paypal/getsuccesspayment'),
            'guardian_phone' => $data['guardian_phone'],
            'name' => $data['name'],
            'description' => 'Student Fees',
            'amount' => $data['total'],
            'currency' => $data['currency_name'],
            );


        $response = $this->paypal_payment->success($success_params);

        $paypalResponse = $response->getData();
        if ($response->isSuccessful()) {
            $purchaseId = $_GET['PayerID'];

            if (isset($paypalResponse['PAYMENTINFO_0_ACK']) && $paypalResponse['PAYMENTINFO_0_ACK'] === 'Success') {
                if ($purchaseId) {
                    $params = $this->session->userdata('params');
                    $ref_id = $paypalResponse['PAYMENTINFO_0_TRANSACTIONID'];
                    
                    $bulk_fees = array();
                    
                    // Unified flow - handle both single and multi payments using student_fees_master_array
                    if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
                        redirect(base_url("payment/paymentfailed"));
                        return;
                    }
                    
                    // Process all fees using unified structure
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
                            'description' => "Online fees deposit through Paypal Ref ID: " . $ref_id,
                            'received_by' => '',
                            'payment_mode' => 'Paypal',
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
                        redirect("payment/successinvoice", "refresh");
                    } else {
                        redirect(base_url("payment/paymentfailed"));
                    }
                }
            }
        } elseif ($response->isRedirect()) {
            $response->redirect();
        } else {
            redirect('payment/paymentfailed', 'refresh');
        }
    }

}
