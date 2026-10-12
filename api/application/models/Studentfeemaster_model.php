<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}
 
class Studentfeemaster_model extends CI_Model
{

    protected $balance_group;
    protected $balance_type;
    public $current_session;

    public function __construct()
    {
        parent::__construct();
        $this->load->config('ci-blog');
        $this->balance_group   = $this->config->item('ci_balance_group');
        $this->balance_type    = $this->config->item('ci_balance_type');
        $this->current_session = $this->setting_model->getCurrentSession();
    }
    
    public function get_discount_amount($discount_id_array){
		
        		
		foreach ($discount_id_array as $item) {
			foreach ($item as $value) {
				$discountIds[] = (int)$value; // Ensure numeric values
			}
		}

		// Build the IN clause
		$inClause = implode(',', $discountIds);
		
        $sql = "select fees_discounts.* from student_fees_discounts 
        left join fees_discounts on student_fees_discounts.fees_discount_id = fees_discounts.id
        where student_fees_discounts.id in ($inClause)";
        $query = $this->db->query($sql);
        return $query->result_array();
    }
    
    public function getStudentFees_old($student_session_id)
    {
        $sql    = "SELECT `student_fees_master`.*,fee_groups.name FROM `student_fees_master` INNER JOIN fee_session_groups on student_fees_master.fee_session_group_id=fee_session_groups.id INNER JOIN fee_groups on fee_groups.id=fee_session_groups.fee_groups_id  WHERE `student_session_id` = " . $student_session_id . " ORDER BY `student_fees_master`.`id`";
        $query  = $this->db->query($sql);
        $result = $query->result();

        if (!empty($result)) {
            foreach ($result as $result_key => $result_value) {
                $fee_session_group_id   = $result_value->fee_session_group_id;
                $student_fees_master_id = $result_value->id;
                $result_value->fees     = $this->getDueFeeByFeeSessionGroup($fee_session_group_id, $student_fees_master_id);
              
                if ($result_value->is_system != 0) {
                    $result_value->fees[0]->amount = $result_value->amount;
                }

                if ($result_value->fees[0]->due_date == 'null' || $result_value->fees[0]->due_date == '') {
                    $result_value->fees[0]->due_date = '';
                }
            }
        }

        return $result;
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

                if ($result_value->is_system != 0) {
                    $result_value->fees[0]->amount = $result_value->amount;
                }
            }
        }

        return $result;
    }
	
	public function getStudentTransportFees($student_session_id, $route_pickup_point_id)
    {
		$date               = date('Y-m-d');
        if ($student_session_id != NULL && $route_pickup_point_id != NULL) {
            $sql = "SELECT student_transport_fees.*,transport_feemaster.month,transport_feemaster.due_date ,route_pickup_point.fees,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_transport_fee_id=student_transport_fees.id INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id  where student_transport_fees.student_session_id=" . $student_session_id . " and student_transport_fees.route_pickup_point_id=" . $route_pickup_point_id . " and transport_feemaster.due_date <=" . $this->db->escape($date) . " ORDER BY student_transport_fees.id asc";
            $query = $this->db->query($sql);
            return $query->result();
        }
        return false;
    }
	
	public function getStudentTransportFeesByStudentSessionId($student_session_id, $route_pickup_point_id)
    {		 
        if ($student_session_id != NULL && $route_pickup_point_id != NULL) {
            $sql = "SELECT student_transport_fees.*,transport_feemaster.month,transport_feemaster.due_date ,route_pickup_point.fees,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_transport_fee_id=student_transport_fees.id INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id  where student_transport_fees.student_session_id=" . $student_session_id . " and student_transport_fees.route_pickup_point_id=" . $route_pickup_point_id . " ORDER BY student_transport_fees.id asc";
            $query = $this->db->query($sql);
            return $query->result();
        }
        return false;
    }

    public function getDueFeeByFeeSessionGroup($fee_session_groups_id, $student_fees_master_id) 
    {
        $sql = "SELECT student_fees_master.*,fee_groups_feetype.fine_type,fee_groups_feetype.id as `fee_groups_feetype_id`,`fee_groups_feetype`.`fine_amount`,IFNULL(fee_groups_feetype.amount,0) as `amount`
        ,IFNULL(fee_groups_feetype.due_date,'') as `due_date`,fee_groups_feetype.fee_groups_id,fee_groups.name,fee_groups_feetype.feetype_id,feetype.code,feetype.type, IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_fees_master` INNER JOIN fee_session_groups on fee_session_groups.id = student_fees_master.fee_session_group_id INNER JOIN fee_groups_feetype on  fee_groups_feetype.fee_session_group_id = fee_session_groups.id  INNER JOIN fee_groups on fee_groups.id=fee_groups_feetype.fee_groups_id INNER JOIN feetype on feetype.id=fee_groups_feetype.feetype_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_fees_master_id=student_fees_master.id and student_fees_deposite.fee_groups_feetype_id=fee_groups_feetype.id WHERE student_fees_master.fee_session_group_id =" . $fee_session_groups_id . " and student_fees_master.id=" . $student_fees_master_id . " order by fee_groups_feetype.due_date asc";

        $query = $this->db->query($sql);
        return $query->result();
    }

    public function studentDeposit($data)
    {
        $sql = "SELECT fee_groups_feetype.fine_type,fee_groups.is_system,student_fees_master.amount as `student_fees_master_amount`, fee_groups.name as `fee_group_name`,feetype.code as `fee_type_code`,feetype.type as `fees_type`,fee_groups_feetype.amount,fee_groups_feetype.due_date,`fee_groups_feetype`.`fine_amount`,IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` from student_fees_master
               INNER JOIN fee_session_groups on fee_session_groups.id=student_fees_master.fee_session_group_id
              INNER JOIN fee_groups_feetype on fee_groups_feetype.fee_groups_id=fee_session_groups.fee_groups_id
              INNER JOIN fee_groups on fee_groups_feetype.fee_groups_id=fee_groups.id
              INNER JOIN feetype on fee_groups_feetype.feetype_id=feetype.id
         LEFT JOIN student_fees_deposite on student_fees_deposite.student_fees_master_id=student_fees_master.id and student_fees_deposite.fee_groups_feetype_id=fee_groups_feetype.id WHERE student_fees_master.id =" . $data['student_fees_master_id'] . " and fee_groups_feetype.id =" . $data['fee_groups_feetype_id'];
        $query = $this->db->query($sql);
        return $query->row();
    }
    
     public function fee_deposit_bulk($bulk_data, $fee_discounts = null)
    {
        $this->db->trans_start();
        $fees_return = array();
        $date=date("Y-m-d");
        foreach ($bulk_data as $fee_key => $fee_data) {

            if ($fee_data['fee_category'] == "fees") {

                $fee_data['student_transport_fee_id'] = NULL;
                $this->db->where('student_fees_master_id', $fee_data['student_fees_master_id']);
                $this->db->where('fee_groups_feetype_id', $fee_data['fee_groups_feetype_id']);
            } elseif ($fee_data['student_transport_fee_id'] > 0 && $fee_data['fee_category'] == "transport") {

                $fee_data['student_fees_master_id'] = NULL;
                $fee_data['fee_groups_feetype_id'] = NULL;
                $this->db->where('student_transport_fee_id', $fee_data['student_transport_fee_id']);
            }

            $fee_category = $fee_data['fee_category'];
            unset($fee_data['fee_category']);

            $q = $this->db->get('student_fees_deposite');

            if ($q->num_rows() > 0) {
                $desc = $fee_data['amount_detail']['description'];
                $row  = $q->row();
                $this->db->where('id', $row->id);
                $a                                   = json_decode($row->amount_detail, true);
                $inv_no                              = max(array_keys($a)) + 1;
                $fee_data['amount_detail']['inv_no'] = $inv_no;
                $a[$inv_no]                          = $fee_data['amount_detail'];
                $fee_data['amount_detail']           = json_encode($a);
                $this->db->update('student_fees_deposite', $fee_data);               

                if(!empty($fee_discounts)){
                    $fee_discounts=$fee_discounts;
                    $discount_array_bulk=[];
                    foreach ($fee_discounts as $fee_discount_key => $fee_discount_value) {
                        $discount_array_bulk[]=array('student_fees_deposite_id'=>$row->id,'student_fees_discount_id'=>$fee_discount_value,'date'=>$date,'invoice_id' => $row->id, 'sub_invoice_id' => $inv_no);
                    }
                    $this->db->insert_batch('student_applied_discounts', $discount_array_bulk);
                }

                $fees_return[] = array(
                    'invoice_id' => $row->id,
                    'sub_invoice_id' => $inv_no,
                    'fee_groups_feetype_id' => $fee_data['fee_groups_feetype_id'],
                    'student_transport_fee_id' => $fee_data['student_transport_fee_id'],
                    'fee_category' => $fee_category
                );
            } else {
                $fee_data['amount_detail']['inv_no'] = 1;
                $desc                                = $fee_data['amount_detail']['description'];
                $fee_data['amount_detail']           = json_encode(array('1' => $fee_data['amount_detail']));
                $this->db->insert('student_fees_deposite', $fee_data);
                $inserted_id = $this->db->insert_id();
                $message = "Insert On student fees deposite id " . $inserted_id;
                $action = "Insert";
                $record_id = $inserted_id;                

                $inserted_id = $this->db->insert_id();
                if (!empty($fee_discounts)) {
                    $discount_array_bulk=[];
                    $fee_discounts=$fee_discounts;
                   
                    foreach ($fee_discounts as $fee_discount_key => $fee_discount_value) {
                        $discount_array_bulk[]=array('student_fees_deposite_id'=>$inserted_id,'student_fees_discount_id'=>$fee_discount_value,'date'=>$date,'invoice_id' => $inserted_id, 'sub_invoice_id' => 1);
                    }
                   
                    $this->db->insert_batch('student_applied_discounts', $discount_array_bulk);
                }

                $fees_return[] = array(
                    'invoice_id' => $inserted_id,
                    'sub_invoice_id' => 1,
                    'fee_groups_feetype_id' => $fee_data['fee_groups_feetype_id'],
                    'student_transport_fee_id' => $fee_data['student_transport_fee_id'],
                    'fee_category' => $fee_category
                );
            }
        }

        $this->db->trans_complete();
        if ($this->db->trans_status() === false) {
            $this->db->trans_rollback();
            return false;
        } else {
            $this->db->trans_commit();
            return $fees_return;
        }
    }

    public function studentTransportDeposit($student_transport_fee_id)
    {
        $sql = "SELECT student_transport_fees.*,transport_feemaster.month,transport_feemaster.due_date ,route_pickup_point.fees,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id  LEFT JOIN student_fees_deposite on student_fees_deposite.student_transport_fee_id=student_transport_fees.id INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id  where student_transport_fees.id=".$this->db->escape($student_transport_fee_id);    
        $query = $this->db->query($sql);
        return $query->row();
    }
    
    public function fee_deposit($data,  $fee_discounts = null)
    {

		$date=date("Y-m-d");
        if(isset($data['student_transport_fee_id']) && !empty($data['student_transport_fee_id']) ){
            $this->db->where('student_transport_fee_id', $data['student_transport_fee_id']);
        
        }else{
            $this->db->where('student_fees_master_id', $data['student_fees_master_id']);
        $this->db->where('fee_groups_feetype_id', $data['fee_groups_feetype_id']);
        }
        unset($data['fee_category']);
        $q = $this->db->get('student_fees_deposite');
        if ($q->num_rows() > 0) {

            $desc = $data['amount_detail']['description'];
            $this->db->trans_start(); // Query will be rolled back
            $row = $q->row();
            $this->db->where('id', $row->id);
            $a                               = json_decode($row->amount_detail, true);
            $inv_no                          = max(array_keys($a)) + 1;
            $data['amount_detail']['inv_no'] = $inv_no;
            $a[$inv_no]                      = $data['amount_detail'];
            $data['amount_detail']           = json_encode($a);
            $this->db->update('student_fees_deposite', $data);

             if(!empty($fee_discounts)){
                    $discount_array_bulk=[];
                      $fee_discounts=$fee_discounts[0];
                    foreach ($fee_discounts as $fee_discount_key => $fee_discount_value) {
                        $discount_array_bulk[]=array('student_fees_deposite_id'=>$row->id,'student_fees_discount_id'=>$fee_discount_value,'date'=>$date,'invoice_id' => $row->id, 'sub_invoice_id' => $inv_no);
                    }
                    $this->db->insert_batch('student_applied_discounts', $discount_array_bulk);
                }

            $this->db->trans_complete();
            if ($this->db->trans_status() === false) {
                $this->db->trans_rollback();

                return false;
            } else {
                $this->db->trans_commit();
                return json_encode(array('invoice_id' => $row->id, 'sub_invoice_id' => $inv_no));
            }
        } else {

            $this->db->trans_start(); // Query will be rolled back
            $data['amount_detail']['inv_no'] = 1;
            $desc                            = $data['amount_detail']['description'];
            $data['amount_detail']           = json_encode(array('1' => $data['amount_detail']));
            $this->db->insert('student_fees_deposite', $data);
            $inserted_id = $this->db->insert_id();
            if (!empty($fee_discounts)) {
                    $discount_array_bulk=[];
                    $fee_discounts=$fee_discounts[0];
                    foreach ($fee_discounts as $fee_discount_key => $fee_discount_value) {
                        $discount_array_bulk[]=array('student_fees_deposite_id'=>$inserted_id,'student_fees_discount_id'=>$fee_discount_value,'date'=>$date,'invoice_id' => $inserted_id, 'sub_invoice_id' => 1);
						
                    }
                    $this->db->insert_batch('student_applied_discounts', $discount_array_bulk);
                }

            $this->db->trans_complete(); # Completing transaction

            if ($this->db->trans_status() === false) {
                $this->db->trans_rollback();
                return false;
            } else {
                $this->db->trans_commit();
                return json_encode(array('invoice_id' => $inserted_id, 'sub_invoice_id' => 1));
            }
        }
    }

    public function getFeeByInvoice($invoice_id, $sub_invoice_id)
    {
        $this->db->select('`student_fees_deposite`.*,students.firstname,students.lastname,student_session.class_id,classes.class,sections.section,student_session.section_id,student_session.student_id,`fee_groups`.`name`, `feetype`.`type`, `feetype`.`code`,student_fees_master.student_session_id')->from('student_fees_deposite');
        $this->db->join('fee_groups_feetype', 'fee_groups_feetype.id = student_fees_deposite.fee_groups_feetype_id');
        $this->db->join('fee_groups', 'fee_groups.id = fee_groups_feetype.fee_groups_id');
        $this->db->join('feetype', 'feetype.id = fee_groups_feetype.feetype_id');
        $this->db->join('student_fees_master', 'student_fees_master.id=student_fees_deposite.student_fees_master_id');
        $this->db->join('student_session', 'student_session.id= student_fees_master.student_session_id');
        $this->db->join('classes', 'classes.id= student_session.class_id');
        $this->db->join('sections', 'sections.id= student_session.section_id');
        $this->db->join('students', 'students.id=student_session.student_id');
        $this->db->where('student_fees_deposite.id', $invoice_id);
        $q = $this->db->get();

        if ($q->num_rows() > 0) {
            $result = $q->row();
            $res    = json_decode($result->amount_detail);
            $a      = (array) $res;

            foreach ($a as $key => $value) {
                if ($key == $sub_invoice_id) {

                    return $result;
                }
            }
        }

        return false;
    }

    public function getDueFeesByStudent($student_session_id, $date)
    {
        $sql = "SELECT student_fees_master.*,fee_session_groups.fee_groups_id,fee_session_groups.session_id,fee_groups.name,fee_groups.is_system,fee_groups_feetype.amount as `fee_amount`,fee_groups_feetype.id as fee_groups_feetype_id,fee_groups_feetype.fine_type,fee_groups_feetype.due_date,fee_groups_feetype.fine_percentage,fee_groups_feetype.fine_amount,IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail`,students.is_active,classes.class,sections.section,feetype.type,feetype.code FROM `student_fees_master` INNER JOIN fee_session_groups on fee_session_groups.id=student_fees_master.fee_session_group_id INNER JOIN student_session on student_session.id=student_fees_master.student_session_id INNER JOIN students on students.id=student_session.student_id inner join classes on student_session.class_id=classes.id INNER JOIN sections on sections.id=student_session.section_id  INNER JOIN fee_groups_feetype on student_fees_master.fee_session_group_id=fee_groups_feetype.fee_session_group_id inner join fee_groups on fee_groups.id=fee_session_groups.fee_groups_id  INNER JOIN feetype on feetype.id= fee_groups_feetype.feetype_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_fees_master_id=student_fees_master.id and student_fees_deposite.fee_groups_feetype_id=fee_groups_feetype.id WHERE student_fees_master.student_session_id='" . $student_session_id . "' AND student_session.session_id='" . $this->current_session . "' and  fee_session_groups.session_id='" . $this->current_session . "'  and fee_groups_feetype.due_date <  '".$date."' ORDER BY `student_fees_master`.`id` DESC";

        $query = $this->db->query($sql);
        return $query->result();
    }

    public function getDueTransportFeeByStudent($student_session_id, $route_pickup_point_id, $date)
    {
        if($student_session_id != NULL && $route_pickup_point_id != NULL){

        $sql = "SELECT student_transport_fees.*,transport_feemaster.month,transport_feemaster.due_date ,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` ,route_pickup_point.fees FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_transport_fee_id=student_transport_fees.id  INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id where student_transport_fees.student_session_id=".$student_session_id." and student_transport_fees.route_pickup_point_id=".$route_pickup_point_id." and transport_feemaster.due_date < '".$date."' ORDER BY student_transport_fees.id asc";
        
        $query = $this->db->query($sql);

        return $query->result();

        }
        return false;
    }

    public function getStudentProcessingFees($student_session_id)
    {
        $sql = "SELECT student_fees_processing.*,student_fees_master.student_session_id,fee_groups.id as fee_group_id,fee_groups.name,feetype.type,feetype.code,gateway_ins.unique_id,fee_groups_feetype.due_date FROM `student_fees_processing` inner join student_fees_master on student_fees_master.id=student_fees_processing.student_fees_master_id INNER JOIN fee_groups_feetype on fee_groups_feetype.id=student_fees_processing.fee_groups_feetype_id and fee_groups_feetype.fee_session_group_id=student_fees_master.fee_session_group_id INNER join feetype on feetype.id=fee_groups_feetype.feetype_id  inner join fee_session_groups on fee_session_groups.id=student_fees_master.fee_session_group_id INNER join fee_groups on fee_groups.id =fee_session_groups.fee_groups_id  inner join gateway_ins on gateway_ins.id=student_fees_processing.gateway_ins_id where student_fees_master.student_session_id=" . $student_session_id. " order by student_fees_processing.id asc";

        $query = $this->db->query($sql);
        return $query->result();
    }

    public function getProcessingTransportFees($student_session_id, $route_pickup_point_id)
    {
        $sql = "SELECT student_transport_fees.*, 'Transport Fees' as `transport_fee` ,transport_feemaster.month,transport_feemaster.due_date ,route_pickup_point.fees,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,student_fees_processing.student_transport_fee_id,IFNULL(student_fees_processing.id,0) as `student_fees_processing_id`, IFNULL(student_fees_processing.amount_detail,0) as `amount_detail`,gateway_ins.unique_id
        FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id INNER JOIN student_fees_processing on student_fees_processing.student_transport_fee_id=student_transport_fees.id INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id inner join gateway_ins on gateway_ins.id=student_fees_processing.gateway_ins_id where student_transport_fees.student_session_id=".$student_session_id." and student_transport_fees.route_pickup_point_id=".$route_pickup_point_id." ORDER BY student_transport_fees.id asc";

        $query = $this->db->query($sql);
        return $query->result();
    }
    
    public function getProcessingFeeByFeeSessionGroup1($fee_session_groups_id, $student_fees_master_id)
    {
        $sql = "SELECT student_fees_master.*,fee_groups_feetype.id as `fee_groups_feetype_id`,fee_groups_feetype.amount,fee_groups_feetype.due_date,fee_groups_feetype.fine_amount,fee_groups_feetype.fee_groups_id,fee_groups.name,fee_groups_feetype.feetype_id,feetype.code,feetype.type, IFNULL(student_fees_processing.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_processing.amount_detail,0) as `amount_detail`,gateway_ins.unique_id FROM `student_fees_master` INNER JOIN fee_session_groups on fee_session_groups.id = student_fees_master.fee_session_group_id INNER JOIN fee_groups_feetype on  fee_groups_feetype.fee_session_group_id = fee_session_groups.id  INNER JOIN fee_groups on fee_groups.id=fee_groups_feetype.fee_groups_id INNER JOIN feetype on feetype.id=fee_groups_feetype.feetype_id LEFT JOIN student_fees_processing on student_fees_processing.student_fees_master_id=student_fees_master.id and student_fees_processing.fee_groups_feetype_id=fee_groups_feetype.id inner join gateway_ins on gateway_ins.id=student_fees_processing.gateway_ins_id WHERE student_fees_master.fee_session_group_id =" . $fee_session_groups_id . " and student_fees_master.id=" . $student_fees_master_id . " order by fee_groups_feetype.due_date ASC";

        $query = $this->db->query($sql);
        return $query->result();
    }
	
	// fees master fees collectiion
    public function get_cumulative_fine_amount($fee_groups_feetype_id)
    {
        $query  = $this->db->query("SELECT cumulative_fine.*,fee_groups_feetype.fine_per_day FROM `cumulative_fine` 
            left join fee_groups_feetype on fee_groups_feetype.id=cumulative_fine.fee_groups_feetype_id
            WHERE `fee_groups_feetype_id`=$fee_groups_feetype_id");
        $result = $query->result();
        return $result;
    }
	
	public function getTransportFeeByID($trans_fee_id) 
    {
        $sql = "SELECT student_transport_fees.*,route_pickup_point.fees,transport_feemaster.month,transport_feemaster.due_date ,transport_feemaster.fine_amount, transport_feemaster.fine_type,transport_feemaster.fine_percentage,students.id as student_id,students.firstname,students.middlename,students.admission_no,students.lastname,student_session.class_id,classes.class,sections.section,students.guardian_name,students.guardian_phone,students.father_name,student_session.section_id,student_session.student_id, IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_transport_fees` INNER JOIN transport_feemaster on transport_feemaster.id =student_transport_fees.transport_feemaster_id   LEFT JOIN student_fees_deposite on student_fees_deposite.student_transport_fee_id=student_transport_fees.id INNER JOIN student_session on student_session.id= student_transport_fees.student_session_id INNER JOIN classes on classes.id= student_session.class_id INNER JOIN sections on sections.id= student_session.section_id INNER JOIN students on students.id=student_session.student_id INNER JOIN route_pickup_point on route_pickup_point.id = student_transport_fees.route_pickup_point_id  WHERE student_transport_fees.id=" . $trans_fee_id;
        $query = $this->db->query($sql);
        return $query->row();
    }
	
	public function getDueFeeByFeeSessionGroupFeetype($fee_session_groups_id, $student_fees_master_id, $fee_groups_feetype_id)
    {
        $sql = "SELECT fee_groups_feetype.fine_type,student_fees_master.id,student_fees_master.is_system,student_fees_master.student_session_id,student_fees_master.fee_session_group_id,student_fees_master.amount as `student_fees_master_amount`,fee_groups_feetype.id as `fee_groups_feetype_id`,students.id as student_id,students.firstname,students.middlename,students.admission_no,students.lastname,student_session.class_id,classes.class,sections.section,students.guardian_name,students.guardian_phone,students.father_name,student_session.section_id,student_session.student_id,fee_groups_feetype.amount,fee_groups_feetype.due_date,fee_groups_feetype.fine_amount,fee_groups_feetype.fee_groups_id,fee_groups.name,fee_groups_feetype.feetype_id,feetype.code,feetype.type, IFNULL(student_fees_deposite.id,0) as `student_fees_deposite_id`, IFNULL(student_fees_deposite.amount_detail,0) as `amount_detail` FROM `student_fees_master` INNER JOIN fee_session_groups on fee_session_groups.id = student_fees_master.fee_session_group_id INNER JOIN fee_groups_feetype on  fee_groups_feetype.fee_session_group_id = fee_session_groups.id  INNER JOIN fee_groups on fee_groups.id=fee_groups_feetype.fee_groups_id INNER JOIN feetype on feetype.id=fee_groups_feetype.feetype_id LEFT JOIN student_fees_deposite on student_fees_deposite.student_fees_master_id=student_fees_master.id and student_fees_deposite.fee_groups_feetype_id=fee_groups_feetype.id INNER JOIN student_session on student_session.id= student_fees_master.student_session_id INNER JOIN classes on classes.id= student_session.class_id INNER JOIN sections on sections.id= student_session.section_id INNER JOIN students on students.id=student_session.student_id  WHERE student_fees_master.fee_session_group_id =" . $fee_session_groups_id . " and student_fees_master.id=" . $student_fees_master_id . " and fee_groups_feetype.id= " . $fee_groups_feetype_id;

        $query = $this->db->query($sql);
        return $query->row();
    }


}
