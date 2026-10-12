<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class Homework_model extends CI_Model
{
    private $current_session;
    public function __construct()
    {
        parent::__construct();
        $this->current_session = $this->setting_model->getCurrentSession();
    }

    public function getStudentHomeworkPercentage($student_session_id, $class_id, $section_id)
    {
        $sql = "SELECT count(*) as total_homework,(SELECT COUNT(homework_evaluation.id) as `aa` FROM `homework` LEFT JOIN homework_evaluation on homework_evaluation.homework_id=homework.id and homework_evaluation.student_session_id= " . $this->db->escape($student_session_id) . " WHERE homework.class_id=" . $this->db->escape($class_id) . " AND homework.section_id=" . $this->db->escape($section_id) . " AND homework.session_id=" . $this->current_session . ") as `completed`  FROM `homework` WHERE class_id=" . $this->db->escape($class_id) . " AND section_id=" . $this->db->escape($section_id) . " AND session_id=" . $this->current_session;
        $query = $this->db->query($sql);
        return $query->row();
    }

    public function getStudentHomework($class_id, $section_id, $student_session_id, $student_id, $subject_group_subject_id, $homework_status = '')
    {
        $condition = "";
        if (!empty($subject_group_subject_id)) {
            $condition .= " AND homework.subject_group_subject_id = " . $this->db->escape($subject_group_subject_id);
        }

        if (!empty($homework_status)) {
            $condition .= " AND (
				CASE
					WHEN homework_evaluation.id IS NOT NULL THEN 'evaluated'
					WHEN submit_assignment.id IS NOT NULL THEN 'submitted'
					ELSE 'pending'
				END
			) = " . $this->db->escape($homework_status);
        }

        $sql = "
			SELECT 
				homework.*,
				homework_evaluation.note,
				homework_evaluation.marks AS evaluation_marks,
				homework_evaluation.created_at AS evaluation_date,
				staff.name AS evaluated_by_name,
				staff.surname AS evaluated_by_surname,
				staff.employee_id AS evaluated_by_employee_id,
				classes.class,
				sections.section,
				subjects.name AS subject_name,
				subjects.code AS subject_code,
				submit_assignment.docs AS submitted_file,

				CASE 
					WHEN homework_evaluation.id IS NOT NULL THEN 'evaluated'
					WHEN submit_assignment.id IS NOT NULL THEN 'submitted'
					ELSE 'pending'
				END AS status

			FROM homework

			LEFT JOIN homework_evaluation 
				ON homework_evaluation.homework_id = homework.id 
				AND homework_evaluation.student_session_id = " . $this->db->escape($student_session_id) . "

			LEFT JOIN submit_assignment 
				ON submit_assignment.homework_id = homework.id 
				AND submit_assignment.student_id = " . $this->db->escape($student_id) . "

			JOIN staff ON staff.id = homework.created_by
			JOIN classes ON classes.id = homework.class_id
			JOIN sections ON sections.id = homework.section_id
			JOIN subject_group_subjects ON subject_group_subjects.id = homework.subject_group_subject_id
			JOIN subjects ON subjects.id = subject_group_subjects.subject_id

			WHERE homework.class_id = " . $this->db->escape($class_id) . "
			AND homework.section_id = " . $this->db->escape($section_id) . "
			AND homework.session_id = " . $this->current_session . "
			$condition

			ORDER BY homework.homework_date DESC
			";

        return $this->db->query($sql)->result_array();
    }

	public function getHomeworkById($id = null)
    {
        $query = $this->db->select("homework.*,classes.class,sections.section,subjects.name,subjects.code,subject_groups.name as subject_group, staff.id as created_staff_id, staff.employee_id as created_employee_id, staff.name as created_staff_name, staff.surname as created_staff_surname, staff_roles.role_id as created_staff_roleid,submit_assignment.message as student_message")
            ->join("classes", "classes.id = homework.class_id")
            ->join("sections", "sections.id = homework.section_id")
            ->join('subject_group_subjects', 'homework.subject_group_subject_id=subject_group_subjects.id')
            ->join("subjects", "subjects.id = subject_group_subjects.subject_id", "left")
            ->join('subject_groups', 'subject_group_subjects.subject_group_id=subject_groups.id')
            ->join('staff', 'staff.id=homework.created_by')
            ->join('staff_roles', 'staff_roles.staff_id=staff.id')        
            ->join('submit_assignment', 'submit_assignment.homework_id = homework.id AND submit_assignment.homework_id = '.$this->db->escape($id), 'left')
            ->where("homework.id", $id)
            ->get("homework");
        return $query->row_array();
    }
 

    public function add($data)
    {
        $this->db->where('homework_id', $data['homework_id']);
        $this->db->where('student_id', $data['student_id']);
        $q = $this->db->get('submit_assignment');
        if ($q->num_rows() > 0) {
            $this->db->where('homework_id', $data['homework_id']);
            $this->db->where('student_id', $data['student_id']);
            $this->db->update('submit_assignment', $data);
        } else {
            $this->db->insert('submit_assignment', $data);
        }
    }

    public function getdailyassignment($student_id, $student_session_id)
    {
        return $this->db->select('daily_assignment.*,subjects.name as subject_name,subjects.code as subject_code')
            ->from('daily_assignment')
            ->join('student_session', 'student_session.session_id=daily_assignment.student_session_id', 'left')
            ->join('subject_group_subjects', 'subject_group_subjects.id=daily_assignment.subject_group_subject_id', 'left')
            ->join('subjects', 'subjects.id=subject_group_subjects.subject_id')
            ->where('daily_assignment.student_session_id', $student_session_id)
            ->or_where('student_session.student_id', $student_id)
            ->order_by('daily_assignment.id', 'desc')
            ->get()
            ->result_array();
    }

    public function adddailyassignment($data)
    {
        if (isset($data["id"]) && $data["id"] > 0) {
            $this->db->where("id", $data["id"])->update("daily_assignment", $data);
            $insert_id = $data["id"];
        } else {
            $this->db->insert("daily_assignment", $data);
            $insert_id = $this->db->insert_id();
        }

        return $insert_id;
    }

    public function getdailyassignmentbyid($id)
    {
        return $this->db->select('daily_assignment.*')
            ->from('daily_assignment')
            ->where('id', $id)
            ->get()
            ->row();
    }

    public function deletedailyassignment($id)
    {
        $this->db->where("id", $id)
            ->delete("daily_assignment");
    }

}
