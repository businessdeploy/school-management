<?php

defined('BASEPATH') or exit('No direct script access allowed');

class Payment_request extends CI_Controller
{

    public function __construct()
    {
        parent::__construct();
        $this->load->helper('url');
        $this->load->database();
        $this->load->model(array('student_model', 'studentfeemaster_model', 'setting_model', 'feediscount_model'));
    }

    public function index()
    {
        // Get list of users with student data for dropdown
        $data['users_list'] = $this->getUsersWithStudentData();
        $this->load->view('payment/api_tester', $data);
    }

    private function getUsersWithStudentData()
    {
        // Get current session from school settings
        $current_session_id = null;
        $setting_result = $this->setting_model->get();
        if (!empty($setting_result) && isset($setting_result[0]['session_id'])) {
            $current_session_id = $setting_result[0]['session_id'];
        }
        
        $this->db->select('users.id, users.username, users.user_id as student_id, students.admission_no, CONCAT(IFNULL(students.firstname, ""), " ", IFNULL(students.lastname, "")) as student_name');
        $this->db->from('users');
        $this->db->join('students', 'students.id = users.user_id', 'inner');
        
        // Join with student_session to filter by current session
        if (!empty($current_session_id)) {
            $this->db->join('student_session', 'student_session.student_id = students.id AND student_session.session_id = ' . (int)$current_session_id, 'inner');
        }
        
        $this->db->where('users.role', 'student');
        $this->db->where('users.is_active', 'yes');
        $this->db->where('students.is_active', 'yes');
        $this->db->where('users.user_id IS NOT NULL');
        $this->db->where('users.user_id !=', '');
        $this->db->order_by('students.firstname', 'asc');
        $query = $this->db->get();
        
        $users = array();
        if ($query->num_rows() > 0) {
            foreach ($query->result() as $row) {
                // Verify student_id exists and is valid
                // Since main query already filters by current session, no need for double verification
                if (!empty($row->student_id) && is_numeric($row->student_id)) {
                    $display_name = trim($row->student_name) ?: 'Unknown';
                    $users[$row->id] = $row->username . ' (ID: ' . $row->id . ') - ' . $display_name . ' [' . ($row->admission_no ?: 'N/A') . ']';
                }
            }
        }
        
        return $users;
    }

    public function get_student_id()
    {
        header('Content-Type: application/json');
        
        $user_id = $this->input->post('user_id');
        $student_id = $this->getStudentIdFromUserId($user_id);
        
        if ($student_id) {
            echo json_encode(array(
                'success' => true,
                'student_id' => $student_id,
                'message' => 'Student ID found'
            ));
        } else {
            echo json_encode(array(
                'success' => false,
                'message' => 'Student ID not found for this User-ID'
            ));
        }
    }

    public function make_request()
    {
        header('Content-Type: application/json');
        
        // Get JSON input if sent as raw JSON
        $input = file_get_contents('php://input');
        if (!empty($input)) {
            $json_input = json_decode($input, true);
            if ($json_input) {
                $_POST = array_merge($_POST, $json_input);
            }
        }
        
        $result = $this->makeApiRequest();
        print_r($result);die;
        if (isset($result['error'])) {
            echo json_encode(array(
                'success' => false,
                'error' => $result['error']
            ));
        } else {
            // Try to parse the response as JSON to extract redirect_url
            $response_data = $result['response'];
            $parsed_response = json_decode($response_data, true);
            
            $output = array(
                'success' => true,
                'response' => $response_data,
                'http_code' => $result['http_code'],
                'response_time' => $result['response_time']
            );
            
            // If response is valid JSON and contains redirect_url, add it to output
            if (json_last_error() === JSON_ERROR_NONE && is_array($parsed_response)) {
                if (isset($parsed_response['redirect_url'])) {
                    $output['redirect_url'] = $parsed_response['redirect_url'];
                }
                // Also include other important fields from the response
                if (isset($parsed_response['status'])) {
                    $output['status'] = $parsed_response['status'];
                }
            }
            
            echo json_encode($output);
        }
    }

    private function makeApiRequest()
    {
        $api_url = $this->input->post('api_url') ?: base_url('payment/paymentrequest');
        $method = $this->input->post('method') ?: 'POST';
        $headers = array();
        $post_data = '';

        // Get headers
        $auth_token = $this->input->post('auth_token') ?: 'NQNANwOQNQ';
        $auth_key = $this->input->post('auth_key') ?: 'schoolAdmin@';
        $client_service = $this->input->post('client_service') ?: 'smartschool';
        $user_id = $this->input->post('user_id') ?: '1';
        $content_type = $this->input->post('content_type') ?: 'application/json';

        $headers[] = 'Authorization: ' . $auth_token;
        $headers[] = 'Auth-Key: ' . $auth_key;
        $headers[] = 'Client-Service: ' . $client_service;
        $headers[] = 'Content-Type: ' . $content_type;
        $headers[] = 'User-ID: ' . $user_id;

        // Get POST body
        $post_body = $this->input->post('post_body');
        
        // If post_body is empty, use default JSON
        if (empty($post_body)) {
            // Get student_id from user_id if not provided
            $student_id_from_user = $this->getStudentIdFromUserId($user_id);
            $post_data = json_encode(array(
                'student_fees_master_id' => '1',
                'fee_groups_feetype_id' => '1',
                'student_id' => $student_id_from_user ?: '1',
                'student_transport_fee_id' => '',
                'fee_discount_group' => '[{0:2}]'
            ));
        } else {
            // Try to parse as JSON
            $json_data = json_decode($post_body, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                // If student_id is not set or empty, get it from user_id
                if (empty($json_data['student_id'])) {
                    $student_id_from_user = $this->getStudentIdFromUserId($user_id);
                    if ($student_id_from_user) {
                        $json_data['student_id'] = $student_id_from_user;
                    }
                }
                $post_data = json_encode($json_data);
            } else {
                $post_data = $post_body;
            }
        }

        $start_time = microtime(true);

        $ch = curl_init();
        curl_setopt_array($ch, array(
            CURLOPT_URL => $api_url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_ENCODING => '',
            CURLOPT_MAXREDIRS => 10,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_POSTFIELDS => $post_data,
            CURLOPT_HTTPHEADER => $headers,
        ));

        $response = curl_exec($ch);
        $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curl_error = curl_error($ch);
        $response_time = round((microtime(true) - $start_time) * 1000, 2); // in milliseconds
        curl_close($ch);

        if ($curl_error) {
            return array('error' => "Connection Error: " . $curl_error);
        } else {
            return array(
                'response' => $response,
                'http_code' => $http_code,
                'response_time' => $response_time
            );
        }
    }

    /**
     * Get student_id from user_id (users.id)
     * Relationship: users.user_id = students.id
     * Uses same logic as getUsersWithStudentData() - filters by current session
     */
    private function getStudentIdFromUserId($user_id)
    {
        if (empty($user_id)) {
            return null;
        }

        // Get current session from school settings
        $current_session_id = null;
        $setting_result = $this->setting_model->get();
        if (!empty($setting_result) && isset($setting_result[0]['session_id'])) {
            $current_session_id = $setting_result[0]['session_id'];
        }

        // Use same query structure as getUsersWithStudentData() for consistency
        $this->db->select('users.user_id as student_id');
        $this->db->from('users');
        $this->db->join('students', 'students.id = users.user_id', 'inner');
        
        // Join with student_session to filter by current session (same as dropdown)
        if (!empty($current_session_id)) {
            $this->db->join('student_session', 'student_session.student_id = students.id AND student_session.session_id = ' . (int)$current_session_id, 'inner');
        }
        
        $this->db->where('users.id', $user_id);
        $this->db->where('users.role', 'student');
        $this->db->where('users.is_active', 'yes');
        $this->db->where('students.is_active', 'yes');
        $this->db->where('users.user_id IS NOT NULL');
        $this->db->where('users.user_id !=', '');
        $this->db->limit(1);
        
        $query = $this->db->get();
        
        if ($query->num_rows() > 0) {
            $result = $query->row();
            return $result->student_id;
        }
        
        return null;
    }

    public function get_student_details()
    {
        header('Content-Type: application/json');
        
        $user_id = $this->input->post('user_id');
        $student_id = $this->input->post('student_id');
        
        // If student_id not provided, get from user_id
        if (empty($student_id) && !empty($user_id)) {
            $student_id = $this->getStudentIdFromUserId($user_id);
        }
        
        if (empty($student_id)) {
            echo json_encode(array(
                'success' => false,
                'message' => 'Student ID not found'
            ));
            return;
        }
        
        // Get current session from school settings
        $current_session_id = null;
        $setting_result = $this->setting_model->get();
        if (!empty($setting_result) && isset($setting_result[0]['session_id'])) {
            $current_session_id = $setting_result[0]['session_id'];
        }
        
        // Get student details - try model first, then direct query
        $student = $this->student_model->get($student_id);
        
        // If not found, try direct query with current session filter
        if (!$student || empty($student)) {
            $this->db->select('students.id, students.admission_no, students.firstname, students.middlename, students.lastname, students.email, students.mobileno, students.guardian_name, students.guardian_phone, student_session.id as student_session_id, classes.class, sections.section');
            $this->db->from('students');
            $this->db->join('student_session', 'student_session.student_id = students.id', 'left');
            $this->db->join('classes', 'student_session.class_id = classes.id', 'left');
            $this->db->join('sections', 'student_session.section_id = sections.id', 'left');
            $this->db->where('students.id', $student_id);
            $this->db->where('students.is_active', 'yes');
            
            // Filter by current session if available
            if (!empty($current_session_id)) {
                $this->db->where('student_session.session_id', $current_session_id);
            }
            
            $this->db->order_by('student_session.id', 'desc');
            $this->db->limit(1);
            $query = $this->db->get();
            $student = $query->row();
        }
        
        if (!$student) {
            echo json_encode(array(
                'success' => false,
                'message' => 'Student not found with ID: ' . $student_id . '. Please check if student exists and is active.'
            ));
            return;
        }
        
        // Get student fees - need student_session_id
        $student_session_id = isset($student->student_session_id) ? $student->student_session_id : null;
        
        if (empty($student_session_id)) {
            // Try to get current session for this student
            $this->db->select('id');
            $this->db->from('student_session');
            $this->db->where('student_id', $student_id);
            
            // Filter by current session if available
            if (!empty($current_session_id)) {
                $this->db->where('session_id', $current_session_id);
            }
            
            $this->db->order_by('id', 'desc');
            $this->db->limit(1);
            $session_query = $this->db->get();
            if ($session_query->num_rows() > 0) {
                $student_session_id = $session_query->row()->id;
            }
        }
        
        // Get available discounts for this student using student_session_id (same logic as student login)
        $available_discounts = array();
        if (!empty($student_session_id)) {
            // Use feediscount_model to get discounts assigned to this student session
            $discounts_list = $this->feediscount_model->getDiscountNotApplied($student_session_id);
            
            if (!empty($discounts_list)) {
                foreach ($discounts_list as $discount) {
                    $available_discounts[] = array(
                        'id' => isset($discount->fees_discount_id) ? $discount->fees_discount_id : (isset($discount->id) ? $discount->id : ''),
                        'name' => isset($discount->name) ? $discount->name : '',
                        'code' => isset($discount->code) ? $discount->code : '',
                        'amount' => isset($discount->amount) ? floatval($discount->amount) : 0,
                        'percentage' => isset($discount->percentage) ? floatval($discount->percentage) : 0,
                        'type' => isset($discount->type) ? $discount->type : 'fix'
                    );
                }
            }
        }
        
        // Get student fees only if we have session_id
        $student_due_fee = array();
        if (!empty($student_session_id)) {
            $student_due_fee = $this->getStudentFees($student_session_id);
            
            // Get session information for each fee group
            $this->db->select('student_session.session_id, sessions.session');
            $this->db->from('student_session');
            $this->db->join('sessions', 'sessions.id = student_session.session_id', 'left');
            $this->db->where('student_session.id', $student_session_id);
            $this->db->limit(1);
            $session_query = $this->db->get();
            $session_info = $session_query->row();
            
            // Add session info to each fee group
            if ($session_info) {
                foreach ($student_due_fee as $fee_group) {
                    $fee_group->session_id = $session_info->session_id;
                    $fee_group->session = $session_info->session;
                }
            }
        }
        
        // Format fees data similar to getfees.php view
        $fees_data = array();
        $sessions_data = array();
        
        if (!empty($student_due_fee)) {
            foreach ($student_due_fee as $fee_group_key => $fee_group_value) {
                $session_id = isset($fee_group_value->session_id) ? $fee_group_value->session_id : 0;
                $session_name = isset($fee_group_value->session) ? $fee_group_value->session : 'Unknown Session';
                
                if (!isset($sessions_data[$session_id])) {
                    $sessions_data[$session_id] = array(
                        'session_id' => $session_id,
                        'session_name' => $session_name,
                        'fee_groups' => array()
                    );
                }
                
                $fee_group_data = array(
                    'fee_group_name' => isset($fee_group_value->name) ? $fee_group_value->name : '',
                    'fee_group_id' => isset($fee_group_value->fee_session_group_id) ? $fee_group_value->fee_session_group_id : '',
                    'fees' => array()
                );
                
                foreach ($fee_group_value->fees as $fee_key => $fee_value) {
                    // Calculate paid, discount, fine from amount_detail (same as getfees.php)
                    $fee_paid = 0;
                    $fee_discount = 0;
                    $fee_fine = 0;
                    $payment_history = array();
                    
                    if (!empty($fee_value->amount_detail)) {
                        $fee_deposits = json_decode($fee_value->amount_detail);
                        
                        if (is_array($fee_deposits) || is_object($fee_deposits)) {
                            foreach ($fee_deposits as $fee_deposits_key => $fee_deposits_value) {
                                $deposit_obj = is_object($fee_deposits_value) ? $fee_deposits_value : (object)$fee_deposits_value;
                                $fee_paid += isset($deposit_obj->amount) ? floatval($deposit_obj->amount) : 0;
                                $fee_discount += isset($deposit_obj->amount_discount) ? floatval($deposit_obj->amount_discount) : 0;
                                $fee_fine += isset($deposit_obj->amount_fine) ? floatval($deposit_obj->amount_fine) : 0;
                                
                                // Payment history
                                $payment_history[] = array(
                                    'payment_id' => isset($deposit_obj->id) ? $deposit_obj->id : '',
                                    'payment_mode' => isset($deposit_obj->payment_mode) ? $deposit_obj->payment_mode : '',
                                    'date' => isset($deposit_obj->date) ? $deposit_obj->date : '',
                                    'amount' => isset($deposit_obj->amount) ? floatval($deposit_obj->amount) : 0,
                                    'discount' => isset($deposit_obj->amount_discount) ? floatval($deposit_obj->amount_discount) : 0,
                                    'fine' => isset($deposit_obj->amount_fine) ? floatval($deposit_obj->amount_fine) : 0
                                );
                            }
                        }
                    }
                    
                    // Calculate fine for overdue fees
                    $fees_fine_amount = 0;
                    if (($fee_value->due_date != "0000-00-00" && $fee_value->due_date != null) && (strtotime($fee_value->due_date) < strtotime(date('Y-m-d')))) {
                        if (isset($fee_value->fine_type) && $fee_value->fine_type == 'cumulative') {
                            $date1 = date_create($fee_value->due_date);
                            $date2 = date_create(date('Y-m-d'));
                            $diff = date_diff($date1, $date2);
                            $due_days = $diff->format("%a");
                            // Note: Would need customlib for cumulative fine calculation
                            $fees_fine_amount = isset($fee_value->fine_amount) ? floatval($fee_value->fine_amount) : 0;
                        } else if (isset($fee_value->fine_type) && ($fee_value->fine_type == 'fix' || $fee_value->fine_type == 'percentage')) {
                            $fees_fine_amount = isset($fee_value->fine_amount) ? floatval($fee_value->fine_amount) : 0;
                        }
                    }
                    
                    $feetype_balance = floatval($fee_value->amount) - ($fee_paid + $fee_discount);
                    if ($feetype_balance < 0) {
                        $feetype_balance = 0;
                    }
                    
                    // Determine status
                    $status = 'unpaid';
                    if ($feetype_balance == 0) {
                        $status = 'paid';
                    } else if (!empty($fee_value->amount_detail)) {
                        $status = 'partial';
                    }
                    
                    $fee_group_data['fees'][] = array(
                        'id' => isset($fee_value->id) ? $fee_value->id : '',
                        'fee_type_code' => isset($fee_value->code) ? $fee_value->code : '',
                        'fee_type_name' => isset($fee_value->type) ? $fee_value->type : '',
                        'is_system' => isset($fee_value->is_system) ? $fee_value->is_system : 0,
                        'amount' => isset($fee_value->amount) ? floatval($fee_value->amount) : 0,
                        'due_date' => isset($fee_value->due_date) && $fee_value->due_date != '0000-00-00' && $fee_value->due_date != 'null' ? $fee_value->due_date : '',
                        'paid' => $fee_paid,
                        'discount' => $fee_discount,
                        'fine' => $fee_fine + $fees_fine_amount,
                        'balance' => $feetype_balance,
                        'status' => $status,
                        'student_fees_master_id' => isset($fee_group_value->id) ? $fee_group_value->id : '',
                        'fee_groups_feetype_id' => isset($fee_value->fee_groups_feetype_id) ? $fee_value->fee_groups_feetype_id : '',
                        'payment_history' => $payment_history
                    );
                }
                
                $sessions_data[$session_id]['fee_groups'][] = $fee_group_data;
            }
        }
        
        // Convert sessions_data to indexed array
        $fees_data = array_values($sessions_data);
        
        echo json_encode(array(
            'success' => true,
            'student' => array(
                'id' => $student->id,
                'admission_no' => $student->admission_no,
                'name' => trim($student->firstname . ' ' . ($student->middlename ?? '') . ' ' . ($student->lastname ?? '')),
                'class' => $student->class,
                'section' => $student->section,
                'email' => $student->email,
                'mobileno' => $student->mobileno,
                'guardian_name' => $student->guardian_name,
                'guardian_phone' => $student->guardian_phone
            ),
            'fees' => $fees_data,
            'available_discounts' => $available_discounts
        ));
    }

    public function getStudentFees($student_session_id)
    {
        $sql    = "SELECT `student_fees_master`.*,fee_groups.name FROM `student_fees_master` INNER JOIN fee_session_groups on student_fees_master.fee_session_group_id=fee_session_groups.id INNER JOIN fee_groups on fee_groups.id=fee_session_groups.fee_groups_id  WHERE `student_session_id` = " . $student_session_id . " ORDER BY `student_fees_master`.`id`";
        $query  = $this->db->query($sql);
        $result = $query->result();

        if (!empty($result)) {
            foreach ($result as $result_key => $result_value) {
                $fee_session_group_id   = $result_value->fee_session_group_id;
                $student_fees_master_id = $result_value->id;
                $result_value->fees     = $this->getDueFeeByFeeSessionGroup($fee_session_group_id, $student_fees_master_id);
              if(isset($result_value->fees[$result_key])){
if ($result_value->is_system != 0) {
                    $result_value->fees[$result_key]->amount = $result_value->amount;
                }

                if ($result_value->fees[$result_key]->due_date == 'null' || $result_value->fees[$result_key]->due_date == '') {
                    $result_value->fees[$result_key]->due_date = '';
                }
              }
                
             
            }
        }

        return $result;
    }  

    
    public function getDueFeeByFeeSessionGroup($fee_session_groups_id, $student_fees_master_id) 
    {
        $sql = "SELECT student_fees_master.*,fee_groups_feetype.fine_type,fee_groups_feetype.id as `fee_groups_feetype_id`,`fee_groups_feetype`.`fine_amount`,IFNULL(fee_groups_feetype.amount,0) as `amount`
        ,IFNULL(fee_groups_feetype.due_date,'') as `due_date`,fee_groups_feetype.fee_groups_id,fee_groups.name,fee_groups_feetype.feetype_id,feetype.code,feetype.type, IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_fees_master` INNER JOIN fee_session_groups on fee_session_groups.id = student_fees_master.fee_session_group_id INNER JOIN fee_groups_feetype on  fee_groups_feetype.fee_session_group_id = fee_session_groups.id  INNER JOIN fee_groups on fee_groups.id=fee_groups_feetype.fee_groups_id INNER JOIN feetype on feetype.id=fee_groups_feetype.feetype_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_fees_master_id=student_fees_master.id and student_fees_deposite.fee_groups_feetype_id=fee_groups_feetype.id WHERE student_fees_master.fee_session_group_id =" . $fee_session_groups_id . " and student_fees_master.id=" . $student_fees_master_id . " order by fee_groups_feetype.due_date asc";

        $query = $this->db->query($sql);
        return $query->result();
    }
}
