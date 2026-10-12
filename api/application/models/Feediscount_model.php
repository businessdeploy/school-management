<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class Feediscount_model extends CI_Model
{
    public $current_session;

    public function __construct()
    {
        parent::__construct();
        $this->current_session = $this->setting_model->getCurrentSession();
    }

    public function getStudentFeesDiscount($student_session_id = null)
    {
        $this->db->select('student_fees_discounts.id ,student_fees_discounts.student_session_id,student_fees_discounts.status,IFNULL(student_fees_discounts.payment_id, "") as `payment_id`,student_fees_discounts.description as `student_fees_discount_description`, student_fees_discounts.fees_discount_id, fees_discounts.name,fees_discounts.code,fees_discounts.amount,fees_discounts.description,fees_discounts.session_id,IFNULL(fees_discounts.percentage, "") as percentage ,IFNULL(fees_discounts.type, "fix") as type')->from('student_fees_discounts');
        $this->db->join('fees_discounts', 'fees_discounts.id = student_fees_discounts.fees_discount_id');
        $this->db->where('student_fees_discounts.student_session_id', $student_session_id);
        $this->db->order_by('student_fees_discounts.id');
        $query = $this->db->get();
        return $query->result_array();
    }

    public function getDiscountNotApplied($student_session_id = null)
    {
        $query = "SELECT * FROM (SELECT student_fees_discounts.*, fees_discounts.name, fees_discounts.code, fees_discounts.type, fees_discounts.percentage, fees_discounts.amount, fees_discounts.discount_limit, IFNULL(applied_fees.total_assigned, 0) AS total_assigned, fees_discounts.discount_limit - IFNULL(applied_fees.total_assigned, 0) AS remaining_discount_limit, fees_discounts.expire_date FROM `student_fees_discounts` INNER JOIN fees_discounts ON fees_discounts.id = student_fees_discounts.fees_discount_id LEFT JOIN (SELECT COUNT(*) AS total_assigned, student_fees_discount_id FROM `student_applied_discounts` GROUP BY student_fees_discount_id) AS applied_fees ON applied_fees.student_fees_discount_id = student_fees_discounts.id WHERE student_fees_discounts.student_session_id = $student_session_id and (fees_discounts.expire_date >=CURDATE() or fees_discounts.expire_date is NULL) ) AS subquery WHERE remaining_discount_limit > 0;";
       
        $query = $this->db->query($query);
        return $query->result();
    }
}
