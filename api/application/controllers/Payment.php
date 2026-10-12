<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Payment extends Admin_Controller
{

    public $payment_method;
    public $school_name;
    public $school_setting;
    public $setting;

    public function __construct()
    {
        parent::__construct();
        
        // Load models first
        $this->load->model(array('auth_model','gateway_ins_model', 'student_model', 'studentfeemaster_model', 'feegrouptype_model', 'paymentsetting_model', 'feediscount_model'));
        $this->load->library('Customlib');
        
        // Then get settings
        $this->payment_method = $this->paymentsetting_model->getActiveMethod();
        $this->setting = $this->setting_model->get();
        $this->std_fine = 0;
        $this->sch_setting_detail = $this->setting_model->getSetting();
    }



    public function paymentfailed()
    {

        $data = array();
        $this->load->view('payment/paymentfailed', $data);
    }

    public function pay($session_id){
		
        $session_data=$this->gateway_ins_model->get_api_session($session_id);          
        $params= json_decode($session_data['params'],true);
        
        // Store session_id in params for callback (works for both single and multi-pay)
        $params['api_session_id'] = $session_id;
        
        // If single payment, convert to multi-pay structure for unified handling
        if (!isset($params['student_fees_master_array']) || empty($params['student_fees_master_array'])) {
            // Convert single payment to multi-pay structure
            $params['invoice'] = (object)$params['invoice'];
            $params['payment_detail'] = (object)$params['payment_detail'];
            
            // Determine fee category (transport or fees) - same logic as fees_pay
            $fee_category = "fees";
            if (isset($params['student_transport_fee_id']) && $params['student_transport_fee_id'] > 0 && 
                (!isset($params['student_fees_master_id']) || $params['student_fees_master_id'] == 0) &&
                (!isset($params['fee_groups_feetype_id']) || $params['fee_groups_feetype_id'] == 0)) {
                $fee_category = "transport";
            } else if (isset($params['fee_category'])) {
                $fee_category = $params['fee_category'];
            }
            
            // Create student_fees_master_array from single payment data
            $fee_record = array(
                'fee_category' => $fee_category,
                'student_transport_fee_id' => isset($params['student_transport_fee_id']) ? $params['student_transport_fee_id'] : 0,
                'fee_groups_feetype_id' => isset($params['fee_groups_feetype_id']) ? $params['fee_groups_feetype_id'] : 0,
                'student_fees_master_id' => isset($params['student_fees_master_id']) ? $params['student_fees_master_id'] : 0,
                'fee_group_name' => isset($params['payment_detail']->fee_group_name) ? $params['payment_detail']->fee_group_name : '',
                'fee_type_code' => isset($params['payment_detail']->code) ? $params['payment_detail']->code : '',
                'fees_type' => isset($params['payment_detail']->fees_type) ? $params['payment_detail']->fees_type : '',
                'is_system' => isset($params['payment_detail']->is_system) ? $params['payment_detail']->is_system : 0,
                'fine_balance' => isset($params['payment_detail']->fine_amount) ? $params['payment_detail']->fine_amount : 0,
                'amount_balance' => isset($params['total']) ? $params['total'] : 0
            );
            
            $params['student_fees_master_array'] = array($fee_record);
            $params['fine_amount_balance'] = isset($params['payment_detail']->fine_amount) ? $params['payment_detail']->fine_amount : 0;
        }
        
        // Ensure invoice is an object
        if (isset($params['invoice']) && is_array($params['invoice'])) {
            $params['invoice'] = (object)$params['invoice'];
        }
        
        $this->session->set_userdata("params", $params);
        $pay_method = $this->payment_method;
       
        $student_record = $this->student_model->get($params['student_id']);

            $page                = new stdClass();
            if (!empty($student_record->currency_id)) {
                $page->symbol        = $student_record->symbol;
                $page->currency_name = $student_record->currency_name;
                $student_currency['currency_base_price'] = $student_record->base_price;
                $student_currency['currency_symbol'] = $student_record->symbol;
            } else {
                $page->symbol        = $this->setting[0]['currency_symbol'];
                $page->currency_name = $this->setting[0]['short_name'];
                $student_currency['currency_base_price'] = $this->setting[0]['base_price'];
                $student_currency['currency_symbol'] = $this->setting[0]['currency_symbol'];
            }

            $this->session->set_userdata("student", $student_currency);
            $this->session->set_userdata("params", $params);
            $this->session->set_userdata('student_currency', array('currency_name' => $page->currency_name, 'currency_base_price' => $student_currency['currency_base_price'], 'currency_symbol' => $student_currency['currency_symbol']));
			$pay_method= $this->payment_method;
            
            if ($pay_method->payment_type == "stripe") {
                if ($pay_method->api_secret_key == "" || $pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Stripe settings not available');
                    $this->load->view('payment/error');
                } else {
                    redirect("gateway/stripe", 'refresh');
                }
            } else if ($pay_method->payment_type == "payu") {

                redirect("gateway/payu", 'refresh');
            } else if ($pay_method->payment_type == "paypal") {

                if ($pay_method->api_username == "" || $pay_method->api_password == "" || $pay_method->api_signature == "") {

                    $this->session->set_flashdata('error', 'Paypal settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/paypal", 'refresh');
                }
            } else if ($pay_method->payment_type == "instamojo") {

                if ($pay_method->api_secret_key == "" || $pay_method->salt == "" || $pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Instamojo settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/Instamojo", 'refresh');
                }
            } else if ($pay_method->payment_type == "razorpay") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Razorpay settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/Razorpay", 'refresh');
                }
            } else if ($pay_method->payment_type == "paystack") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Paystack settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/Paystack", 'refresh');
                }
            } else if ($pay_method->payment_type == "paytm") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'paytm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/Paytm", 'refresh');
                }
            } else if ($pay_method->payment_type == "midtrans") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'midtrans settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/midtrans", 'refresh');
                }
            } else if ($pay_method->payment_type == "pesapal") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'pesapal settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/pesapal", 'refresh');
                }
            } else if ($pay_method->payment_type == "flutterwave") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Flutterwave settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/flutterwave", 'refresh');
                }
            } else if ($pay_method->payment_type == "ipayafrica") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'iPayAfrica settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/ipayafrica", 'refresh');
                }
            } else if ($pay_method->payment_type == "jazzcash") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'iPayAfrica settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/jazzcash", 'refresh');
                }
            } else if ($pay_method->payment_type == "billplz") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Billplz settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/billplz", 'refresh');
                }
            } else if ($pay_method->payment_type == "ccavenue") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'CCAvenue settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/ccavenue", 'refresh');
                }
            } else if ($pay_method->payment_type == "sslcommerz") {

                if ($pay_method->api_password == "") {

                    $this->session->set_flashdata('error', 'Sslcommerz settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/sslcommerz", 'refresh');
                }
            } else if ($pay_method->payment_type == "walkingm") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/walkingm", 'refresh');
                }
            } else if ($pay_method->payment_type == "mollie") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/mollie", 'refresh');
                }
            } else if ($pay_method->payment_type == "cashfree") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/cashfree", 'refresh');
                }
            } else if ($pay_method->payment_type == "payfast") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/payfast", 'refresh');
                }
            } else if ($pay_method->payment_type == "toyyibpay") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Toyyibpay settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/toyyibpay", 'refresh');
                }
            } else if ($pay_method->payment_type == "twocheckout") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/twocheckout", 'refresh');
                }
            } else if ($pay_method->payment_type == "skrill") {

                if ($pay_method->api_email == "") {

                    $this->session->set_flashdata('error', 'Walkingm settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/skrill", 'refresh');
                }
            } else if ($pay_method->payment_type == "payhere") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'Payhere settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/payhere", 'refresh');
                }
            } else if ($pay_method->payment_type == "onepay") {

                if ($pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'Onepay settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/onepay", 'refresh');
                }
            } else if ($pay_method->payment_type == "dpopay") {

                if ($pay_method->api_secret_key == "") {

                    $this->session->set_flashdata('error', 'DPO Pay settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/dpopay", 'refresh');
                }
            } else if ($pay_method->payment_type == "momopay") {

                if ($pay_method->api_secret_key == "" || $pay_method->api_username == "" || $pay_method->api_publishable_key == "") {

                    $this->session->set_flashdata('error', 'MomoPay settings not available');
                    $this->load->view('payment/error');
                } else {

                    redirect("gateway/momopay", 'refresh');
                }
            } else {
                $this->session->set_flashdata('error', 'Oops! An error occurred with this payment, Please contact to administrator');
                $this->load->view('payment/error');
            }
    }    
    

    public function fees_pay() 
    {
        $method = $this->input->server('REQUEST_METHOD');
        
        if ($method != 'POST') {
            json_output(400, array('status' => 400, 'message' => 'Bad request.'));
        } else {
            $check_auth_client = $this->auth_model->check_auth_client();
            if ($check_auth_client == true) {
                $response = $this->auth_model->auth();
                if ($response['status'] == 200) {
                    $input = file_get_contents('php://input');
                    $params_request = json_decode($input, true);
                    
                    // Check JSON decode error
                    if (json_last_error() !== JSON_ERROR_NONE) {
                        json_output(400, array('status' => 400, 'message' => 'Invalid JSON: ' . json_last_error_msg()));
                        return;
                    }
                    
                    // Check if payments array exists
                    if (empty($params_request) || empty($params_request['payments']) || !is_array($params_request['payments'])) {
                        json_output(400, array('status' => 400, 'message' => 'Payments array is required.'));
                        return;
                    }
                    
                    $payments = $params_request['payments'];
                    
                    // Get student_id from first payment
                    $student_id = isset($payments[0]['student_id']) ? $payments[0]['student_id'] : 0;
                    if (empty($student_id)) {
                        json_output(400, array('status' => 400, 'message' => 'Student ID is required.'));
                        return;
                    }
                    
                    $student_record = $this->student_model->get($student_id);
                    if (!$student_record) {
                        json_output(400, array('status' => 400, 'message' => 'Student not found.'));
                        return;
                    }
                    
                    // Setup currency
                    $page = new stdClass();
                    if (!empty($student_record->currency_id)) {
                        $page->symbol = $student_record->symbol;
                        $page->currency_name = $student_record->currency_name;
                        $student_currency['currency_base_price'] = $student_record->base_price;
                        $student_currency['currency_symbol'] = $student_record->symbol;
                    } else {
                        $page->symbol = $this->setting[0]['currency_symbol'];
                        $page->currency_name = $this->setting[0]['short_name'];
                        $student_currency['currency_base_price'] = $this->setting[0]['base_price'];
                        $student_currency['currency_symbol'] = $this->setting[0]['currency_symbol'];
                    }
                    
                    $pay_method = $this->payment_method;
                    if (empty($pay_method)) {
                        json_output(400, array('status' => 400, 'message' => 'Payment method not configured.'));
                        return;
                    }
                    
                    // Unified payment flow - handles both single and multi payments
                    // Process all payments and create student_fees_master_array
                    $amount_paid = 0;
                    $amount_fine_paid = 0;
                    $amount_discount = 0;
                    $fee_record = array();
                    $fees_array = array();
                    $total_amount_balance = 0;
                    $total_fine_amount_balance = 0;
                    $fees_master_array = array();
                    
                    // Process all payments in unified flow - handles both single and multi payments
                    foreach ($payments as $payment) {
                            $fees_fine_amount = 0;
                            $fine_amount_paid = 0;
                            $fine_amount_balance = 0;
                            
                            $fee_groups_feetype_id = isset($payment['fee_groups_feetype_id']) ? $payment['fee_groups_feetype_id'] : 0;
                            $fee_master_id = isset($payment['student_fees_master_id']) ? $payment['student_fees_master_id'] : 0;
                            $payment_amount = isset($payment['amount']) ? floatval($payment['amount']) : 0;
                            $trans_fee_id = isset($payment['student_transport_fee_id']) ? $payment['student_transport_fee_id'] : 0;
                            
                            // Get fee_session_group_id from student_fees_master
                            $fee_session_group_id = 0;
                            if ($fee_master_id > 0) {
                                $this->db->select('fee_session_group_id');
                                $this->db->from('student_fees_master');
                                $this->db->where('id', $fee_master_id);
                                $this->db->limit(1);
                                $session_query = $this->db->get();
                                if ($session_query->num_rows() > 0) {
                                    $fee_session_group_id = $session_query->row()->fee_session_group_id;
                                }
                            }
                            
                            // Determine fee category
                            $fee_category = "fees";
                            if ($trans_fee_id > 0 && $fee_master_id == 0 && $fee_groups_feetype_id == 0) {
                                $fee_category = "transport";
                            }
                            
                            $fee_record = array();
                            $fee_record['fee_category'] = $fee_category;
                            $fee_record['student_transport_fee_id'] = $trans_fee_id;
                            $fee_record['fee_groups_feetype_id'] = $fee_groups_feetype_id;
                            $fee_record['student_fees_master_id'] = $fee_master_id;
                            $fee_record['fee_session_group_id'] = $fee_session_group_id;
                            $fee_record['fee_master_id'] = $fee_master_id;
                            $fee_record['trans_fee_id'] = $trans_fee_id;
                            
                            $amount_paid = 0;
                            $amount_discount = 0;
                            $amount_fine_paid = 0;
                            
                            if ($fee_category == "transport") {
                                $result = $this->studentfeemaster_model->studentTRansportDeposit($trans_fee_id);
                                $fee_record['fee_group_name'] = "Transport Fees";
                                $fee_record['fee_type_code'] = $result->month;
                                $fee_record['fees_type'] = "Transport Fees";
                                $fee_record['is_system'] = 0;
                                
                                $amount_detail = json_decode($result->amount_detail);
                                if (is_object($amount_detail)) {
                                    foreach ($amount_detail as $amount_detail_key => $amount_detail_value) {
                                        $amount_paid = $amount_paid + $amount_detail_value->amount;
                                        $amount_discount = $amount_discount + $amount_detail_value->amount_discount;
                                        $amount_fine_paid = $amount_fine_paid + $amount_detail_value->amount_fine;
                                    }
                                }
                                
                                $fees_balance = $result->fees - ($amount_paid + $amount_discount);
                                
                                if (($result->due_date != "0000-00-00" && $result->due_date != null) && (strtotime($result->due_date) < strtotime(date('Y-m-d'))) && $fees_balance > 0) {
                                    if (is_null($result->fine_percentage)) {
                                        $fine_amount_balance = $result->fine_amount;
                                    } else {
                                        $fine_amount_balance = ($result->fees * $result->fine_percentage) / 100;
                                    }
                                }
                            } elseif ($fee_category == "fees") {
                                $result = $this->studentfeemaster_model->studentDeposit($fee_record);						
								 
								 
                                $fee_record['fee_group_name'] = $result->fee_group_name;
                                $fee_record['fee_type_code'] = $result->fee_type_code;
                                $fee_record['fees_type'] = $result->fees_type;
                                $fee_record['is_system'] = $result->is_system;
                                
                                $amount_detail = json_decode($result->amount_detail);
                                if (is_object($amount_detail)) {
                                    foreach ($amount_detail as $amount_detail_key => $amount_detail_value) {
                                        $amount_paid = $amount_paid + $amount_detail_value->amount;
                                        $amount_discount = $amount_discount + $amount_detail_value->amount_discount;
                                        $amount_fine_paid = $amount_fine_paid + $amount_detail_value->amount_fine;
                                    }
                                }
                                
                                $fees_balance = $result->amount - ($amount_paid + $amount_discount);
                                if ($result->is_system) {
                                    $fees_balance = $result->student_fees_master_amount - ($amount_paid + $amount_discount);
                                }
                                
                                if (($result->due_date != "0000-00-00" && $result->due_date != null) && (strtotime($result->due_date) < strtotime(date('Y-m-d'))) && $fees_balance > 0) {
                                    if ($result->fine_type == 'cumulative') {
                                        $date1 = date_create("$result->due_date");
                                        $date2 = date_create(date('Y-m-d'));
                                        $diff = date_diff($date1, $date2);
                                        $due_days = $diff->format("%a");
                                        
                                        if ($this->customlib->get_cumulative_fine_amount($fee_groups_feetype_id, $due_days)) {
                                            $due_fine_amount = $this->customlib->get_cumulative_fine_amount($fee_groups_feetype_id, $due_days);
                                        } else {
                                            $due_fine_amount = 0;
                                        }
                                        $fine_amount_balance = $due_fine_amount;
                                    } else if ($result->fine_type == 'fix' || $result->fine_type == 'percentage') {
                                        $fine_amount_balance = $result->fine_amount;
                                    }
                                }
                            }
                            
                            // Use payment amount if provided, otherwise use balance
                            $fee_record['fine_balance'] = ($fine_amount_balance - $amount_fine_paid);
                            $fee_record['amount_balance'] = $payment_amount > 0 ? $payment_amount : $fees_balance;
                            
                            // Calculate discount amount for this fee (from discounts array in payment)
                            // Discount applies on payment amount, not fees balance
                            $fee_discount_amount = 0;
                             $has_fulldescount=false;
                            $fee_discount_details = array();
                            if (!empty($payment['discounts']) && is_array($payment['discounts'])) {
                                $discount_base_amount = $payment_amount > 0 ? $payment_amount : $fees_balance;
                                foreach ($payment['discounts'] as $discount) {
                                    $discount_amount = 0;
                                    if (isset($discount['type']) && $discount['type'] == 'percentage' && isset($discount['percentage'])) {
                                        // Percentage discount - calculate on payment amount
                                       
                                        if($discount['percentage']==100){
                                            $has_fulldescount=true;
                                        }
                                        $discount_amount = ($discount_base_amount * floatval($discount['percentage'])) / 100;
                                    } elseif (isset($discount['amount'])) {
                                        // Fixed discount
                                        $discount_amount = floatval($discount['amount']);
                                    }
                                    
                                    if ($discount_amount > 0) {
                                        $fee_discount_amount += $discount_amount;
                                        // Store only id and applied_amount (simplified array)
                                        $fee_discount_details[] = array(
                                            'id' => isset($discount['id']) ? $discount['id'] : '',
                                            'applied_amount' => $discount_amount
                                        );
                                    }
                                }
                            }
                            $fee_record['discount_amount'] = $fee_discount_amount; // Add discount amount to fee record
                            $fee_record['discount_details'] = $fee_discount_details; // Add discount details array (only id and applied_amount)
                            
                            $fees_master_array[] = $fee_record;
                            $total_fine_amount_balance += ($fine_amount_balance - $amount_fine_paid);
                            $total_amount_balance += $fee_record['amount_balance'];
                    }
                    
                    // Calculate total discount amount from all fees
                    $total_discount_amount = 0;
                    foreach ($fees_master_array as $fee_item) {
                        if (isset($fee_item['discount_amount'])) {
                            $total_discount_amount += $fee_item['discount_amount'];
                        }
                    }
                    $chargeamount=($total_amount_balance - $total_discount_amount + $total_fine_amount_balance);
                    // Gateway processing charge (calculated after all payments processed)
                    $gateway_processing_charge = 0;
                    if ($pay_method->charge_type == 'percentage') {
                        $gateway_processing_charge = (($chargeamount * $pay_method->charge_value) / 100);
                    } elseif ($pay_method->charge_type == 'fix') {
                        $gateway_processing_charge = $pay_method->charge_value;
                    }
                    
                    // Calculate final total amount (after discount, fine, and processing charge)
                    $final_total_amount = ($total_amount_balance - $total_discount_amount + $total_fine_amount_balance + $gateway_processing_charge);
                    
                    // If total amount is 0 or negative (100% discount), mark as paid directly without gateway
                    if ($has_fulldescount) {
                        // Prepare bulk fees data for direct payment
                        $bulk_fees = array();
                        $fee_discounts_array = array(); // For fee_deposit_bulk
                        
                        foreach ($fees_master_array as $fee_key => $fee_value) {
                            // Use individual discount amount for each fee
                            $fee_discount_amount = isset($fee_value['discount_amount']) ? $fee_value['discount_amount'] : 0;
                            
                            // Set description based on fee category
                            $description = "Online fees deposit through 100% Discount";
                            if ($fee_value['fee_category'] == "transport") {
                                $description = "Online transport fees deposit through 100% Discount";
                            }
                            
                            $json_array = array(
                                'amount' => $fee_value['amount_balance'],
                                'date' => date('Y-m-d'),
                                'amount_discount' => $fee_value['amount_balance'], // Full amount as discount
                                'processing_charge_type' => $pay_method->charge_type,
                                'gateway_processing_charge' => 0, // No gateway charge for 100% discount
                                'amount_fine' => $fee_value['fine_balance'],
                                'description' => $description,
                                'received_by' => '',
                                'payment_mode' => '',
                            );
                            
                            $insert_fee_data = array(
                                'fee_category' => $fee_value['fee_category'],
                                'student_transport_fee_id' => $fee_value['student_transport_fee_id'],
                                'student_fees_master_id' => $fee_value['student_fees_master_id'],
                                'fee_groups_feetype_id' => $fee_value['fee_groups_feetype_id'],
                                'amount_detail' => $json_array,
                            );
                            $bulk_fees[] = $insert_fee_data;
                            
                            // Collect discount IDs for this fee
                            // Need to convert fees_discount_id to student_fees_discount_id
                            $fee_discount_ids = array();
                            if (isset($fee_value['discount_details']) && is_array($fee_value['discount_details'])) {
                                foreach ($fee_value['discount_details'] as $disc) {
                                    if (isset($disc['id']) && !empty($disc['id'])) {
                                        // The 'id' from API is fees_discount_id, we need student_fees_discount_id
                                        // Query student_fees_discounts table to get the correct ID
                                        $fees_discount_id = $disc['id'];
                                        $this->db->select('id');
                                        $this->db->from('student_fees_discounts');
                                        $this->db->where('fees_discount_id', $fees_discount_id);
                                        $this->db->where('student_session_id', $student_record->student_session_id);
                                        $this->db->limit(1);
                                        $discount_query = $this->db->get();
                                        
                                        if ($discount_query->num_rows() > 0) {
                                            $student_fees_discount_id = $discount_query->row()->id;
                                            $fee_discount_ids[] = $student_fees_discount_id;
                                        }
                                    }
                                }
                            }
                            if (!empty($fee_discount_ids)) {
                                $fee_discounts_array = $fee_discount_ids;
                            } else {
                                $fee_discounts_array= array();
                            }
                        }
                     
                        // Call fee_deposit_bulk to mark fees as paid
                        $deposit_response = $this->studentfeemaster_model->fee_deposit_bulk($bulk_fees, $fee_discounts_array);
                        
                        if ($deposit_response) {
                            // Return success response
                            $success_response = array(
                                'status' => 200,
                                'message' => 'Payment successful. Fees marked as paid with 100% discount.',
                                'success' => true,
                                'data' => array(
                                    'total_amount' => $final_total_amount,
                                    'total_discount' => $total_discount_amount,
                                    'fees_count' => count($fees_master_array)
                                )
                            );
                            json_output(200, $success_response);
                        } else {
                            // Return error response if deposit failed
                            $error_response = array(
                                'status' => 400,
                                'message' => 'Failed to process payment. Please try again.',
                                'success' => false
                            );
                            json_output(400, $error_response);
                        }
                        return;
                    }
                    
                    $params = array(
                        'key' => $pay_method->api_secret_key,
                        'api_publishable_key' => $pay_method->api_publishable_key,
                        'invoice' => $page,
                        'total' => ($total_amount_balance),
                        'applied_fee_discount' => $total_discount_amount, // Total discount amount
                        'student_fees_discount_id' => null,
                        'fine_amount_balance' => ($total_fine_amount_balance),
                        'student_session_id' => $student_record->student_session_id,
                        'name' => $this->customlib->getFullName($student_record->firstname, $student_record->middlename, $student_record->lastname, $this->sch_setting_detail->middlename, $this->sch_setting_detail->lastname),
                        'guardian_phone' => $student_record->guardian_phone,
                        'mobileno' => $student_record->mobileno,
                        'guardian_email' => $student_record->guardian_email,
                        'address' => $student_record->permanent_address,
                        'student_fees_master_array' => $fees_master_array,
                        'student_id' => $student_id,
                        'processing_charge_type' => $pay_method->charge_type,
                        'gateway_processing_charge' => $gateway_processing_charge
                    );
                    
                    $session_data = $this->gateway_ins_model->add_api_session(array('params' => json_encode($params)));
                    $params['redirect_url'] = base_url("payment/pay/" . $session_data);
                    json_output($response['status'], $params);
                }
            }
        }
    }

    public function successinvoice($invoice_id=NULL, $sub_invoice_id=NULL)
    {
        $data                = array();
        // $data['title']       = 'Invoice';
        // $setting_result      = $this->setting_model->get();
        // $data['settinglist'] = $setting_result;
        // $studentfee          = $this->studentfeemaster_model->getFeeByInvoice($invoice_id, $sub_invoice_id);

        // $a                         = json_decode($studentfee->amount_detail);
        // $record                    = $a->{$sub_invoice_id};
        // $data['studentfee']        = $studentfee;
        // $data['studentfee_detail'] = $record;

        $this->load->view('payment/invoice', $data);
    }
}
