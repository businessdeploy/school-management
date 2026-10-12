<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Mollie Pay Custom Integration</title>
        <link href="style.css" type="text/css" rel="stylesheet" />
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap.min.css">
        <style type="text/css">
            .paybox{width: 460px;margin: 7% auto;}
            .paybox_bg{background: #fff;box-shadow: 0px 1px 15px rgba(0, 0, 0, 0.18);border-radius: 10px;}
            .bt_title{background: #fff; color: #000; padding: 20px 20px; border-bottom:1px solid #ccc;}
            .paybody{padding: 20px;}
            .paybox label{font-size: 13px; padding-top: 7px;}
            .submit_button{border-radius: 4px; padding: 10px 20px; border:0; background: #204d74; color: #fff; display: block;width: 100%; font-size: 16px; text-transform: uppercase; margin-top: 20px;}
            .submit_button:hover{background: #367fa9;}
            .payspan{position: absolute; right:0; top:5px; font-size: 18px;}
            @media(max-width:767px){
                .paybox{width: 100%;margin: 1% auto;}
            }
            .bt_title img{width: 100%; height: auto;}
        </style>

    </head>
    <body>

        <div class="container">
            <div class="row">
                <div class="col-md-12">
                    <div class="paybox">
                        <div class="paybox_bg">
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/mollie.png" style="margin-bottom: 10px;"><br />Mollie Payment Gateway</h3>
                            <div class="paybody">
                                <?php if (isset($api_error) && $api_error) { ?>
                                    <div class="alert alert-danger"><?php
                                        if (is_array($api_error)) {
                                            print_r($api_error);
                                        } else {
                                            echo $api_error;
                                        }
                                        ?> </div>
                                <?php } ?>
                                
                                <?php if (validation_errors()) { ?>
                                    <div class="alert alert-danger">
                                        <?php echo validation_errors(); ?>
                                    </div>
                                <?php } ?>

                                <form action="<?php echo base_url(); ?>gateway/mollie/pay" method="post">
                                    <table class="table2" width="100%">
                                        <tr>
                                            <th><?php echo ('Description'); ?></th>
                                            <th class="text-right"><?php echo ('Amount') ?></th>
                                        </tr>
                                        <?php
                                        if (isset($params['student_fees_master_array']) && !empty($params['student_fees_master_array'])) {
                                            foreach ($params['student_fees_master_array'] as $fees_key => $fees_value) {
                                                ?>
                                                <tr>
                                                    <td>
                                                        <span class="title"><?php if (isset($fees_value['is_system']) && $fees_value['is_system']) {
                                                            echo $this->lang->line($fees_value['fee_group_name']);
                                                        } else {
                                                            echo isset($fees_value['fee_group_name']) ? $fees_value['fee_group_name'] : '';
                                                        }?> </span>
                                                        <span class="product-description">
                                                            <?php if (isset($fees_value['is_system']) && $fees_value['is_system']) {
                                                                echo $this->lang->line($fees_value['fee_type_code']);
                                                            } else {
                                                                echo isset($fees_value['fee_type_code']) ? $fees_value['fee_type_code'] : '';
                                                            } ?></span>
                                                    </td>
                                                    <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['amount_balance'], 2); ?></td>
                                                </tr>
                                                <?php if (isset($fees_value['discount_amount']) && $fees_value['discount_amount'] > 0) { ?>
                                                <tr class="border_bottom">
                                                    <td> 
                                                        <span class="text-discount" style="color: #17a2b8;"><?php echo ('Discount'); ?></span>
                                                    </td>
                                                    <td class="text-right" style="color: #17a2b8;"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['discount_amount'], 2); ?></td>
                                                </tr>
                                                <?php } ?>
                                                <tr class="border_bottom">
                                                    <td> 
                                                        <span class="text-fine"><?php echo ('Fine'); ?></span></td>
                                                    <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format($fees_value['fine_balance'], 2); ?></td>
                                                </tr>
                                                <?php
                                            }
                                        }
                                        ?>
                                        
                                        <?php if(isset($params['applied_fee_discount']) && $params['applied_fee_discount']>0){ ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Discount'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right" style="color: #17a2b8;"><?php echo $setting[0]['currency_symbol'] . number_format($params['applied_fee_discount'], 2); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Fine'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <?php echo $setting[0]['currency_symbol'] . number_format(isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0, 2); ?></td>
                                        </tr>
                                        <?php if(isset($params['gateway_processing_charge']) && $params['gateway_processing_charge']>0){ ?>
                                        <tr class="border_bottom">
                                            <td>
                                                <span class="text-text-success"><?php echo ('Processing Fees'); ?></span>
                                            </td>
                                            <td class="text-right"><?php echo $setting[0]['currency_symbol'] . number_format((float) $params['gateway_processing_charge'], 2); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Amount'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <?php 
                                                $total_amount = (isset($params['total']) ? $params['total'] : 0) 
                                                    - (isset($params['applied_fee_discount']) ? $params['applied_fee_discount'] : 0) 
                                                    + (isset($params['fine_amount_balance']) ? $params['fine_amount_balance'] : 0) 
                                                    + (isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0);
                                                echo $setting[0]['currency_symbol'] . number_format($total_amount, 2); 
                                            ?></td>
                                        </tr>
                                        
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Phone') ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="phone" required value="<?php echo set_value('phone', isset($params['guardian_phone']) ? $params['guardian_phone'] : ''); ?>" /></td>
                                        </tr>

                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Email'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="email" class="form-control" name="email" required value="<?php echo set_value('email', isset($student_data->guardian_email) ? $student_data->guardian_email : ''); ?>" ></td>
                                        </tr>
                                        
                                        <tr><td colspan="2"><hr /></td></tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff">  </td>
                                            <td bgcolor="#fff" class="text-right"> <button type="submit" name="search" value="" class="btn btn-info"><i class="fa fa fa-chevron-right"></i> <?php echo ('Pay With Mollie'); ?></button>  </td>
                                        </tr>
                                    </table>
                                </form>
                            </div>    
                        </div><!--./paybox-->
                    </div><!--./paybox_bg-->
                </div><!--./col-md-12-->
            </div><!--./row-->
        </div><!--./container-->

    </body>
</html>
