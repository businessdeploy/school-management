<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class Customlib {

    // api ver: 3.5

    public $CI;

    public function __construct() {
        $this->CI = &get_instance();
        $this->CI->load->model('Setting_model');
    }
    
    public function getSchoolCurrencyPrice()
    {
       
            $student = $this->CI->session->userdata('student_currency');
            return $student['currency_base_price'];

       
    }

    public function getCurrencySymbol()
    {
           
            $student = $this->CI->session->userdata('student_currency');            
            return $student['currency_symbol'];

       
    }
    
    
    public function getMonthList($month = 0) {
        $months = array(
            0 => '',
            1 => 'january',
            2 => 'february',
            3 => 'march',
            4 => 'april',
            5 => 'may',
            6 => 'june',
            7 => 'july',
            8 => 'august',
            9 => 'september',
            10 => 'october',
            11 => 'november',
            12 => 'decmber');

        return $months[$month];
    }

    public function getDaysname() {
        $status = array();
        $status['Monday'] = 'Monday';
        $status['Tuesday'] = 'Tuesday';
        $status['Wednesday'] = 'Wednesday';
        $status['Thursday'] = 'Thursday';
        $status['Friday'] = 'Friday';
        $status['Saturday'] = 'Saturday';
        $status['Sunday'] = 'Sunday';
        return $status;
    }

    public function getSchoolName() {
        $admin = $this->CI->Setting_model->getSetting();
        return $admin->name;
    }

    public function getGender() {
        $gender = array();
        $gender['Male'] = 'male';
        $gender['Female'] = 'female';
        return $gender;
    } 

    public function getFullName($firstname, $middlename, $lastname, $is_middlename,$is_lastname)
    {
        $name="";
        if ($is_middlename) {
            $name= ($middlename == "") ? $firstname : $firstname . " " . $middlename;
        } else {
            $name= $firstname;
        }

       if ($is_lastname) {
            $name= ($lastname == "") ? $name : $name . " " . $lastname;
        } 

        return $name;
    }

    public function getCourseThumbnailPath($course_thumbnail){
       $web_path= trim(base_url(), "api/");
       return $web_path."/uploads/course/course_thumbnail/".$course_thumbnail;

    }
    
    public function uniqueFileName($prefix = "", $name = "")
    {
        if (!empty($_FILES)) {
            $newFileName = uniqid($prefix, true) . '.' . strtolower(pathinfo($name, PATHINFO_EXTENSION));
            return $newFileName;
        }
        return false;
    }
    
    public function getCurrencyFormat()
    {
        $admin = $this->CI->Setting_model->getSetting();
        return $admin->currency_format;             
    }
	
	//fees master  fees collect //
    public function get_cumulative_fine_amount($fee_groups_feetype_id,$due_days){
       
        $this->CI->load->model('studentfeemaster_model');
        $get_cumulative_data = $this->CI->studentfeemaster_model->get_cumulative_fine_amount($fee_groups_feetype_id);
        $due_fine_amount=0;
        $due_fine_amount1=0;
		$day = 0;
        if(count($get_cumulative_data)>0){
            foreach($get_cumulative_data as $key=>$value){
                if($value->fine_per_day==1){
                    //fine will multiply after due days to fine amount
					if ($due_days > $value->overdue_day) {
						
						// Case where the next cumulative data exists
						if (!empty($get_cumulative_data[$key + 1]->overdue_day)) {
							
							// If the next overdue day is less than the due days, calculate fine based on the difference
							if ($get_cumulative_data[$key + 1]->overdue_day < $due_days) {
								$day = $get_cumulative_data[$key + 1]->overdue_day - $value->overdue_day;
								$due_fine_amount1 = $value->fine_amount * $day;
							} else {
								// Otherwise, calculate the fine based on the difference between due days and current overdue day
								$overduedays = $due_days - $value->overdue_day;
								$due_fine_amount1 = $value->fine_amount * $overduedays;
							}
							
						} else {
							// Case where there is no next cumulative data
							$overduedays = $due_days - $value->overdue_day;
							$due_fine_amount1 = $value->fine_amount * $overduedays;
						}
						
						// Add the calculated fine amount to the total due fine
						$due_fine_amount += $due_fine_amount1;
					 
				   }				 
					
                }else{ 
                    //fine will after due date
                    if($due_days > $value->overdue_day){
                        $due_fine_amount= $value->fine_amount;
                    }
                }
            }
            return $due_fine_amount;
        }else{
            return false;
        }

        return false;
    }


    public function get_online_course_curriculam_status($fieldname){
        $this->CI->load->model('Course_model');
        $course_setting             = $this->CI->course_model->getOnlineCourseSettings();
        $active_curriculam_status   = "" ;
       
        if($course_setting->course_curriculum_settings==null){
            return $active_curriculam_status="hide"; 
        }else{
            $course_curriculum_settings = json_decode($course_setting->course_curriculum_settings); 
            if(!empty($course_setting->course_curriculum_settings) && in_array("$fieldname",$course_curriculum_settings)){ 
                return $active_curriculam_status="";
            }else{
                return $active_curriculam_status="hide";
            }
        }
    }
    
  
    public function getFolderPath()
    {         
        $setting_result = $this->CI->setting_model->get();
           
        $folder_path = $setting_result[0]["folder_path"];
         

        if ($folder_path == "") {
            $folder_path = null;
        }
        return $folder_path;
    }

    public function getSchoolDateFormat($date_only = true, $time = false)
    {
        $setting_result     = $this->CI->setting_model->get();
        return $date_format = $setting_result[0]['date_format'];
    }

}
