<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class Coursecertificate_model extends CI_Model
{

    protected $current_session;
    public function __construct()
    {
        parent::__construct();
        $this->current_session = $this->setting_model->getCurrentSession();
    }
    

    public function get($id=null)
    {
        if(isset($id) && $id!=""){
            $this->db->where('id', $id);
        }
        $this->db->select('*');
        $this->db->from('online_course_certificate_template');        
        $query = $this->db->get();
        return $query->result_array();
    }   

    public function getstudentcertificate()
    {
        $this->db->select('*');
        $this->db->from('certificates');
        $this->db->where('created_for = 2');
        $query = $this->db->get();
        return $query->result();
    }

    public function certifiatebyid($id)
    {
        $this->db->select('*');
        $this->db->from('certificates');
        $this->db->where('id', $id);
        $query = $this->db->get();
        return $query->row();
    }

}
