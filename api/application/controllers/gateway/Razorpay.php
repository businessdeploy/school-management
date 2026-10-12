<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Razorpay extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
         $this->load->model(array('gateway_ins_model'));
    }

    public function index() {

        $razorpay = $this->paymentsetting_model->getActiveMethod();
        $pay_method = $this->paymentsetting_model->getActiveMethod();
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
        if ($this->session->has_userdata('params')) {
            $session_params = $this->session->userdata('params');
        } 
        
        // Unified flow - works for both single and multi-pay (multi-pay structure is always used)
        $session_id = isset($session_params['api_session_id']) ? $session_params['api_session_id'] : '';
        
        // Calculate total (works for both single and multi)
        $fine_amount = isset($session_params['fine_amount_balance']) ? $session_params['fine_amount_balance'] : 0;
        $total = number_format((float)($session_params['total'] + $fine_amount), 2, '.', '');
        
        $data['params'] = $session_params;
        $amount = $session_params['total'];
        $data['name'] = $session_params['name'];
        $data['merchant_order_id'] = time() . "01";
        $data['txnid'] = time() . "02";
        $data['title'] = 'Student Fee';
        $data['total'] = $total * 100;
        $data['amount'] = $total;
        $data['key_id'] = $pay_method->api_publishable_key;
        
        // Handle invoice (can be object or array)
        if (is_array($session_params['invoice'])) {
            $data['currency_code'] = $session_params['invoice']['currency_name'];
        } else {
            $data['currency_code'] = $session_params['invoice']->currency_name;
        }
        
        $data['id'] = $session_id; // Pass session_id to view for multi_callback
        
        $ch = curl_init();
        $order_data=array('amount'=>(int)$data['total'],'currency'=>$data['currency_code'],'receipt'=>'R#'.time() . "01");
        curl_setopt($ch, CURLOPT_URL, 'https://api.razorpay.com/v1/orders');
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_POST, 1);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($order_data));
        curl_setopt($ch, CURLOPT_USERPWD, $pay_method->api_publishable_key . ':' . $pay_method->api_secret_key);

        $headers = array();
        $headers[] = 'Content-Type: application/json';
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

        $result = curl_exec($ch);
        if (curl_errno($ch)) {
            echo 'Error:' . curl_error($ch);die;
        }
        curl_close($ch);

        $results=(array)json_decode($result);
        if(array_key_exists('error', $results)){
            $order_id="";
        }else{
           $order_id=json_decode($result)->id; 
        }

        $data['order_id']=$order_id;
        
        // Always use multi view (can handle both single and multi payments)
        $this->load->view('payment/razorpay/index', $data);
    }


   
    public function callback($session_id){
       $session_data=$this->gateway_ins_model->get_api_session($session_id);
    
     $params=json_decode($session_data['params'],true);
 
        if (isset($_POST['razorpay_payment_id']) && $_POST['razorpay_payment_id'] != '') {
            
          
                    $payment_id = $_POST['razorpay_payment_id'];
                    $bulk_fees=array();
                    
                 
                    foreach ($params['student_fees_master_array'] as $fee_key => $fee_value) {
                        // Use individual discount amount for each fee
                        $fee_discount_amount = isset($fee_value['discount_amount']) ? $fee_value['discount_amount'] : 0;
                   
                     $json_array = array(
                        'amount'          =>  $fee_value['amount_balance'],
                        'date'            => date('Y-m-d'),
                        'amount_discount' => $fee_discount_amount,
                        'processing_charge_type'=>isset($params['processing_charge_type']) ? $params['processing_charge_type'] : '',
                        'gateway_processing_charge'=>isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0,
                        'amount_fine'     => $fee_value['fine_balance'],
                        'description'     => $this->lang->line('online_fees_deposit_through_razorpay_txn_id') . $payment_id,
                        'received_by'     => '',
                        'payment_mode'    => 'Razorpay',
                    );

                    $insert_fee_data = array(
                        'fee_category'=>$fee_value['fee_category'],
                        'student_transport_fee_id'=>$fee_value['student_transport_fee_id'],
                        'student_fees_master_id' => $fee_value['student_fees_master_id'],
                        'fee_groups_feetype_id'  => $fee_value['fee_groups_feetype_id'],
                        'amount_detail'          => $json_array,
                    );                 
                   $bulk_fees[]=$insert_fee_data;
                    //========
                    }

                      $response = $this->studentfeemaster_model->fee_deposit_bulk($bulk_fees, NULL);
                      
                      if($response){
                        $this->gateway_ins_model->delete_api_session($session_id);
                        redirect("payment/successinvoice", "refresh");
                    }else{
                       redirect(base_url("payment/paymentfailed")); 
                    }
                  }
    }

}
