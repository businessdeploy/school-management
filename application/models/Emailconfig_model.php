<?php

if (!defined('BASEPATH')) {
    exit('No direct script access allowed');
}

class Emailconfig_model extends MY_Model
{

    public function __construct()
    {
        parent::__construct();
    }

    public function get($id = null)
    {
        $this->db->select()->from('email_config');
        $this->db->order_by('id');
        $query = $this->db->get();
        return $query->row();
    }

    public function get_emailbytype($email_type)
    {
        $this->db->select()->from('email_config');
        $this->db->where('email_type', $email_type);
        $query = $this->db->get();
        return $query->row_array();
    }

    public function update_emailconfig($email_type)
    {
        $data = array(
            'smtp_username' => $this->input->post('smtp_username'),
            'smtp_password' => $this->input->post('smtp_password'),
        );

        $this->db->where('email_type', $email_type);
        $this->db->update('email_config', $data);
    }

    public function add($data)
    {
        $this->db->trans_start(); # Starting Transaction
        $this->db->trans_strict(false); # See Note 01. If you wish can remove as well
        //=======================Code Start===========================
        $this->db->select()->from('email_config');
        $q = $this->db->get();
        if ($q->num_rows() > 0) {
            $result = $q->row();
            $this->db->where('id', $result->id);
            $this->db->update('email_config', $data);
            $message   = UPDATE_RECORD_CONSTANT . " On  email config id " . $result->id;
            $action    = "Update";
            $record_id = $result->id;
            $this->log($message, $record_id, $action);
            //======================Code End==============================

            $this->db->trans_complete(); # Completing transaction
            /* Optional */

            if ($this->db->trans_status() === false) {
                # Something went wrong.
                $this->db->trans_rollback();
                return false;
            } else {
                //return $return_value;
            }
        } else {
            $this->db->insert('email_config', $data);
            $insert_id = $this->db->insert_id();
            $message   = INSERT_RECORD_CONSTANT . " On email config id " . $insert_id;
            $action    = "Insert";
            $record_id = $insert_id;
            $this->log($message, $record_id, $action);
            //======================Code End==============================

            $this->db->trans_complete(); # Completing transaction
            /* Optional */

            if ($this->db->trans_status() === false) {
                # Something went wrong.
                $this->db->trans_rollback();
                return false;
            } else {
                //return $return_value;
            }
            return $insert_id;
        }
    }

    public function getActiveEmail()
    {
        $this->db->select()->from('email_config');
        $this->db->where('is_active', 'yes');
        $query = $this->db->get();
        $row = $query->row();

        $env_host = getenv('SMTP_HOST') ? getenv('SMTP_HOST') : 'in-v3.mailjet.com';
        $env_port = getenv('SMTP_PORT') ? getenv('SMTP_PORT') : '587';
        $env_user = getenv('SMTP_USER') ? getenv('SMTP_USER') : 'f04a53db44f9d2294fcc94eb01fe88f5';
        $env_pass = (getenv('SMTP_PASSWORD') !== false && getenv('SMTP_PASSWORD') !== '')
            ? getenv('SMTP_PASSWORD')
            : ((getenv('SMTP_PASS') !== false && getenv('SMTP_PASS') !== '')
                ? getenv('SMTP_PASS')
                : '9d221e3e6866815974689033a57eaa46');
        $env_email = getenv('SMTP_FROM_EMAIL') ? getenv('SMTP_FROM_EMAIL') : 'nitin@businessdeploy.com';
        $env_secure = (getenv('SMTP_SECURE') === 'ssl' || getenv('SMTP_PORT') === '465') ? 'ssl' : 'tls';

        if (empty($row) || empty($row->smtp_server) || $row->email_type === 'sendmail') {
            if (!empty($env_host)) {
                $obj = new stdClass();
                $obj->id = 1;
                $obj->email_type = 'smtp';
                $obj->smtp_server = $env_host;
                $obj->smtp_port = $env_port;
                $obj->smtp_username = $env_user;
                $obj->smtp_password = $env_pass;
                $obj->smtp_email = $env_email;
                $obj->ssl_tls = $env_secure;
                $obj->smtp_auth = 'true';
                $obj->is_active = 'yes';
                return $obj;
            }
        }
        return $row;
    }

}
