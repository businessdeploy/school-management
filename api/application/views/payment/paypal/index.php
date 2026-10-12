<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Paypal Pay Custom Integration Demo</title>
        <link href="style.css" type="text/css" rel="stylesheet" />
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap.min.css">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">

        <style type="text/css">
            .paybox{width: 460px;margin: 7% auto;}
            .paybox_bg{background: #fff;box-shadow: 0px 1px 15px rgba(0, 0, 0, 0.18);border-radius: 10px;}
            .bt_title{background: #fff; color: #000; padding: 20px 20px; border-bottom:1px solid #ccc;}
            .paybody{padding: 20px;}
            .paybox label{font-size: 13px; padding-top: 7px;}
            .submit_button{border-radius: 4px; padding: 10px 20px; border:0; background: #204d74; color: #fff; display: block;width: 100%; font-size: 16px; text-transform: uppercase; margin-top: 20px;}
            .submit_button:hover{background: #367fa9;}
            .table2 td{padding-top: 8px;}
            .table2 th{padding: 8px; background: #f5f5f5;}
            .bordertoplightgray{border-top: 1px solid #ddd;}
            .border_bottom{border-bottom: 1px solid #ddd;}
            @media(max-width:767px){
                .paybox{width: 100%;margin: 1% auto;}
                .bt_title img{width: 100%; height: auto;}
            }
        </style>   
    </head>
    <body>
        <div class="container">
            <div class="row">
                <div class="col-md-12">
                    <div class="paybox">   
                        <div class="paybox_bg"> 
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/paypal.png" style="margin-bottom:10px"><br />Paypal Payment Gateway</h3>                         
                            <div class="paybody">
                                <form class="paddtlrb" action="<?php echo site_url('gateway/paypal/pay') ?>" method="POST" id="paypalForm">
                                    <div class="form-group row">
                                        <label class="col-sm-4">Name</label>
                                        <div class="col-sm-8">
                                            <div class="form-control"><?php echo $session_params['name']; ?></div></div>
                                    </div><!--./form-group-->
                                    <div class="form-group row">
                                        <label class="col-sm-4">Email</label>
                                        <div class="col-sm-8">
                                            <div class="form-control"><?php echo isset($session_params['guardian_email']) ? $session_params['guardian_email'] : (isset($session_params['email']) ? $session_params['email'] : ''); ?></div></div>
                                    </div><!--./form-group-->
                                    <div class="form-group row">
                                        <label class="col-sm-4">Guardian Phone</label>
                                        <div class="col-sm-8"><div class="form-control"><?php echo $session_params['guardian_phone']; ?></div></div>
                                    </div><!--./form-group-->
                                    
                                    <!-- Fees Details Table (like Razorpay) -->
                                    <table class="table2" width="100%" style="margin-bottom: 20px;">
                                        <tr>
                                            <th><?php echo ('Description'); ?></th>
                                            <th class="text-right"><?php echo ('Amount') ?></th>
                                        </tr>
                                        <?php
                                        // Unified flow - handle both single and multi payments using student_fees_master_array
                                        if (isset($params['student_fees_master_array']) && !empty($params['student_fees_master_array'])) {
                                            foreach ($params['student_fees_master_array'] as $fees_key => $fees_value) {
                                                ?>
                                                <tr>
                                                    <td>
                                                        <span class="title"><?php if (isset($fees_value['is_system']) && $fees_value['is_system']) {
                                                            echo $this->lang->line($fees_value['fee_group_name']);
                                                        } else {
                                                            echo $fees_value['fee_group_name'];
                                                        }?> </span>
                                                        <span class="product-description">
                                                            <?php if (isset($fees_value['is_system']) && $fees_value['is_system']) {
                                                                echo $this->lang->line($fees_value['fee_type_code']);
                                                            } else {
                                                                echo $fees_value['fee_type_code'];
                                                            } ?>
                                                        </span>
                                                    </td>
                                                    <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['amount_balance'], 2, '.', ''); ?></td>
                                                </tr>
                                                <?php if (isset($fees_value['discount_amount']) && $fees_value['discount_amount'] > 0) { ?>
                                                <tr class="border_bottom">
                                                    <td> 
                                                        <span class="text-discount" style="color: #17a2b8;"><?php echo ('Discount'); ?></span>
                                                    </td>
                                                    <td class="text-right" style="color: #17a2b8;"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['discount_amount'], 2, '.', ''); ?></td>
                                                </tr>
                                                <?php } ?>
                                                <tr class="border_bottom">
                                                    <td> 
                                                        <span class="text-fine"><?php echo ('Fine'); ?></span>
                                                    </td>
                                                    <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['fine_balance'], 2, '.', ''); ?></td>
                                                </tr>
                                                <?php
                                            }
                                        }
                                        ?>
                                        
                                        <?php if(isset($params['applied_fee_discount']) && $params['applied_fee_discount'] > 0){ ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Discount'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right" style="color: #17a2b8;"><?php echo $setting[0]['currency_symbol'] . number_format($params['applied_fee_discount'], 2, '.', ''); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Fine'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <?php echo $setting[0]['currency_symbol'] . number_format(isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0, 2, '.', ''); ?></td>
                                        </tr>
                                        <?php if(isset($params['gateway_processing_charge']) && $params['gateway_processing_charge'] > 0){ ?>
                                        <tr class="border_bottom">
                                            <td>
                                                <span class="text-text-success"><?php echo ('Processing Fees'); ?></span>
                                            </td>
                                            <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format((float) $params['gateway_processing_charge'], 2, '.', ''); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Amount'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <?php 
                                                $total_amount = $params['total'] - (isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0) + (isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0) + (isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0);
                                                echo $setting[0]['currency_symbol'] . number_format($total_amount, 2, '.', ''); 
                                            ?></td>
                                        </tr>
                                    </table>

                                    <div class="form-group">
                                        <button type="submit" class="submit_button"><i class="fa fa-money"></i> Pay Now </button> 
                                    </div>	

                                </form>
                            </div><!--./paybody-->                       
                        </div><!--./paybox_bg-->                        
                    </div><!--./paybox-->
                </div><!--./col-md-12-->
            </div><!--./row-->
        </div><!--./container-->                           
    </body>
</html> 
