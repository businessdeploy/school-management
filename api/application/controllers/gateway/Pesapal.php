<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Pesapal extends Admin_Controller {

    var $setting;
    var $payment_method;
    var $api_config;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->api_config = $this->paymentsetting_model->getActiveMethod();
        $this->load->library('pesapal_lib');
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
        $data['student_data'] = $this->student_model->get($session_params['student_id']);
        $data['setting'] = $this->setting;
        $data['api_error'] = array();
     
        $this->load->view('payment/pesapal/index', $data);
    }
 
   public function pesapal_pay(){
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

        $this->form_validation->set_rules('phone', ('Phone'), 'trim|required|xss_clean');
        $this->form_validation->set_rules('email', ('Email'), 'trim|required|xss_clean');

        if ($this->form_validation->run()==false) {
            $this->load->view('payment/pesapal/index', $data);
        } else {
            $pesapal_details = $this->paymentsetting_model->getActiveMethod();
            $params = $session_params;
            
            // Unified flow - calculate total from student_fees_master_array
            $fine_amount = isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0;
            $applied_discount = isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0;
            $gateway_charge = isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0;
            $total = number_format((float)(convertBaseAmountCurrencyFormat($params['total'] + $fine_amount - $applied_discount + $gateway_charge)), 2, '.', '');
            
            // Get session_id for callback
            $session_id = isset($params['api_session_id']) ? $params['api_session_id'] : '';
            
            $data = array();
            $data['total'] = $total;
            $data['symbol'] = isset($params['invoice']->symbol) ? $params['invoice']->symbol : '';
            $data['currency_name'] = isset($params['invoice']->currency_name) ? $params['invoice']->currency_name : '';
            $data['name'] = $params['name'];
            $data['guardian_phone'] = isset($params['guardian_phone']) ? $params['guardian_phone'] : '';
            $data['id'] = $session_id; // Pass session_id for callback
            $amount = $data['total'];

        
        $token = $params = NULL;
        $consumer_key = $pesapal_details->api_publishable_key;;//Register a merchant account on
                           //demo.pesapal.com and use the merchant key for testing.
                           //When you are ready to go live make sure you change the key to the live account
                           //registered on www.pesapal.com!
        $consumer_secret = $pesapal_details->api_secret_key;;// Use the secret from your test
                           //account on demo.pesapal.com. When you are ready to go live make sure you 
                           //change the secret to the live account registered on www.pesapal.com!
        $signature_method = new OAuthSignatureMethod_HMAC_SHA1();
        $iframelink = 'https://www.pesapal.com/API/PostPesapalDirectOrderV4';//change to      
                           //https://www.pesapal.com/API/PostPesapalDirectOrderV4 when you are ready to go live!

        //get form details<br>$amount = $_POST['amount'];
        $amount = number_format($amount, 2);//format amount to 2 decimal places
        $desc = "Student Fee Payment";
        $type = 'MERCHANT'; //default value = MERCHANT
        $reference = time();//unique order id of the transaction, generated by merchant
        $first_name = $data['name']; //[optional]
        $last_name = ''; //[optional]
        $email = $_POST['email'];
        $phonenumber = $_POST['phone']; //ONE of email or phonenumber is required

        $callback_url = base_url('gateway/pesapal/pesapal_response/' . $session_id); //redirect url, the page that will handle the response from pesapal.
        $post_xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?><PesapalDirectOrderInfo xmlns:xsi=\"http://www.w3.org/2001/XMLSchemainstance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" Amount=\"".$amount."\" Description=\"".$desc."\" Type=\"".$type."\" Reference=\"".$reference."\" FirstName=\"".$first_name."\" LastName=\"".$last_name."\" Email=\"".$email."\" PhoneNumber=\"".$phonenumber."\" xmlns=\"http://www.pesapal.com\" />";
        $post_xml = htmlentities($post_xml);

        $consumer = new OAuthConsumer($consumer_key, $consumer_secret);
        //post transaction to pesapal

        $iframe_src = OAuthRequest::from_consumer_and_token($consumer, $token, "GET",
        $iframelink, $params);

        $iframe_src->set_parameter("oauth_callback", $callback_url);
        $iframe_src->set_parameter("pesapal_request_data", $post_xml);
        $iframe_src->sign_request($signature_method, $consumer, $token);

        $consumer = new OAuthConsumer($consumer_key, $consumer_secret);
        //post transaction to pesapal

        $iframe_src = OAuthRequest::from_consumer_and_token($consumer, $token, "GET",
        $iframelink, $params);
        $iframe_src->set_parameter("oauth_callback", $callback_url);
        $iframe_src->set_parameter("pesapal_request_data", $post_xml);
        $iframe_src->sign_request($signature_method, $consumer, $token);
        $data['iframe_src']=$iframe_src;
        $this->load->view('payment/pesapal/pay', $data);
        
        }
}
      

    public function pesapal_response($session_id = ''){
        $pesapal_details = $this->paymentsetting_model->getActiveMethod();
        
        // Get session_id from URL parameter (similar to Razorpay callback approach)
        if (empty($session_id)) {
            $session_id = $this->uri->segment(3);
        }
        
        $reference = null;
        $pesapal_tracking_id = null;

        if(isset($_GET['pesapal_merchant_reference'])){
            $reference = $_GET['pesapal_merchant_reference'];
        }

        if(isset($_GET['pesapal_transaction_tracking_id'])){
            $pesapal_tracking_id = $_GET['pesapal_transaction_tracking_id'];
        }

        $consumer_key = $pesapal_details->api_publishable_key;
        $consumer_secret = $pesapal_details->api_secret_key;
        $statusrequestAPI = 'https://www.pesapal.com/api/querypaymentstatus';

        $pesapalTrackingId = isset($_GET['pesapal_transaction_tracking_id']) ? $_GET['pesapal_transaction_tracking_id'] : '';
        $pesapal_merchant_reference = isset($_GET['pesapal_merchant_reference']) ? $_GET['pesapal_merchant_reference'] : '';

        if($pesapalTrackingId != '') {
            $token = $params = NULL;
            $consumer = new OAuthConsumer($consumer_key, $consumer_secret);
            $signature_method = new OAuthSignatureMethod_HMAC_SHA1();

            $request_status = OAuthRequest::from_consumer_and_token($consumer, $token, "GET", $statusrequestAPI, $params);
            $request_status->set_parameter("pesapal_merchant_reference", $pesapal_merchant_reference);
            $request_status->set_parameter("pesapal_transaction_tracking_id", $pesapalTrackingId);
            $request_status->sign_request($signature_method, $consumer, $token);

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $request_status);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch, CURLOPT_HEADER, 1);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
            
            if(defined('CURL_PROXY_REQUIRED')) if (CURL_PROXY_REQUIRED == 'True') {
                $proxy_tunnel_flag = (defined('CURL_PROXY_TUNNEL_FLAG') && strtoupper(CURL_PROXY_TUNNEL_FLAG) == 'FALSE') ? false : true;
                curl_setopt ($ch, CURLOPT_HTTPPROXYTUNNEL, $proxy_tunnel_flag);
                curl_setopt ($ch, CURLOPT_PROXYTYPE, CURLPROXY_HTTP);
                curl_setopt ($ch, CURLOPT_PROXY, CURL_PROXY_SERVER_DETAILS);
            }

            $response = curl_exec($ch);
            $header_size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
            $raw_header = substr($response, 0, $header_size - 4);
            $headerArray = explode("\r\n\r\n", $raw_header);
            $header = $headerArray[count($headerArray) - 1];

            $elements = preg_split("/=/", substr($response, $header_size));
            $status = isset($elements[1]) ? $elements[1] : '';
            curl_close($ch);

            if($status == 'COMPLETED') {
                // Get session data (similar to Razorpay callback)
                if (empty($session_id)) {
                    // Try to get from session
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
                        'description' => "Online fees deposit through Pesapal Txt ID: " . $pesapalTrackingId,
                        'received_by' => '',
                        'payment_mode' => 'Pesapal',
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
                redirect(base_url("payment/paymentfailed"));
            }
        } else {
            redirect(base_url("payment/paymentfailed"));
        }
    }
}
