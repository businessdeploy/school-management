<?php

defined('BASEPATH') or exit('No direct script access allowed');
// require_once APPPATH . 'third_party/stripe/init.php';

class Stripe extends Admin_Controller {

    var $setting;
    var $payment_method;

    public function __construct() {
        parent::__construct();

        $this->setting = $this->setting_model->get();
        $this->payment_method = $this->paymentsetting_model->get();
        $this->load->model('course_model');
        $this->load->library('notification_lib');
        $this->load->library('stripe_payment');
    }
 
    /*
    This is used to show payment detail page with payment gateway functionality and success reposnse status
    */
    public function index() {
        $error= array();
        $data = array();
        $pay_method = $this->paymentsetting_model->getActiveMethod();
        $data['publishable_key']=$pay_method->api_publishable_key;
         $session_params = $this->session->userdata('course_amount');
        
                    $total= convertBaseAmountCurrencyFormat($session_params['total_amount']);
                    $data['setting'] = $this->setting;
                     $data['error'] = array();
                    $data['session_params'] = $session_params;
        if ($pay_method->payment_type == "stripe") {           

            if ($this->session->has_userdata('course_amount')) {
                if ($pay_method->api_secret_key != "" && $pay_method->api_publishable_key != "") {                 
                  $this->load->view('course_payment/stripe/pay', $data);  
                }
            }
        } else {
            $this->session->set_flashdata('error', 'Oops! Something went wrong');
            $this->load->view('course_payment/course_payment/paymentfailed');
        }
    }

    function success(){
         $this->load->view('course_payment/paymentsuccess');
    }

    public function create_payment_intent()
    {
        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);
        $this->stripe_payment->PaymentIntent($jsonObj);
    }

    public function create_customer()
    {
        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);

        $user_detail = $this->session->userdata('course_amount');

        $jsonObj = new stdClass();
        $jsonObj->fullname=$user_detail['name'];
        $jsonObj->emai=$user_detail['email'];
       
        $this->stripe_payment->AddCustomer($jsonObj);
    }

    public function insert_payment()
    {
        $jsonStr = file_get_contents('php://input');
        $jsonObj = json_decode($jsonStr);
        $return_response = $this->stripe_payment->InsertTransaction($jsonObj);
        if ($return_response['status']) {
            $payment = $return_response['payment'];
            // If transaction was successful
            if (!empty($payment) && $payment->status == 'succeeded') {
                $params              = $this->session->userdata('course_amount');
                $data                =[];
                $data['description'] = ("online fees deposit");
                $data['currency']    = $params['currency_name'];
                // Retrieve transaction details
                $transaction_id = $payment->id;

                //=====================================

                $payment_data['transactionid'] = $transaction_id;         

				$params = $this->session->userdata('course_amount');							
									
                                    $payment_data = array(
                                        'date' => date('Y-m-d'),
                                        'student_id' => $params['student_id'],
                                        'online_courses_id' => $params['courseid'],
                                        'course_name' => $params['course_name'],
                                        'actual_price' => $params['actual_amount'],
                                        'paid_amount' => $params['total_amount'],
                                        'payment_type' => 'Online',
                                        'transaction_id' =>$transaction_id,
                                        'note' => "Online course fees deposit through Stripe Txn ID: " . $transaction_id,
                                        'payment_mode' => 'Stripe',
                                    );

                                    $this->course_model->add($payment_data);                     
       
                //=============================
          
                    echo json_encode(['status'=>1,'msg' => 'Transaction successful.','return_url'=>base_url("course_payment/paymentsuccess")]);

                //=====================================

            } else {
                http_response_code(500);
                echo json_encode(['status'=>0,'msg' => 'Transaction has been failed!','return_url'=>base_url('course_payment/course_payment/paymentfailed')]);
            }
        } else {
            http_response_code(500);
            echo json_encode(['status'=>0,'msg' => $return_response['error']]);
        }
    }
}