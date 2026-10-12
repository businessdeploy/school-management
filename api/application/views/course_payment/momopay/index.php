<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>MomoPay Custom Integration</title>
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
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/momopay.png" style="margin-bottom: 10px; max-width: 200px;"><br />MomoPay Payment Gateway</h3>
                            <div class="paybody">
                                <?php if (isset($api_error) && $api_error) { ?>
                                    <div class="alert alert-danger">
                                        <h4><i class="icon fa fa-warning"></i> Payment Error!</h4>
                                        <?php
                                        if (isset($api_error['message'])) {
                                            echo '<p><strong>Error:</strong> ' . htmlspecialchars($api_error['message']) . '</p>';
                                        }
                                        if (isset($api_error['code'])) {
                                            echo '<p><strong>Error Code:</strong> ' . htmlspecialchars($api_error['code']) . '</p>';
                                        }
                                        if (isset($api_error['status'])) {
                                            echo '<p><strong>Status:</strong> ' . htmlspecialchars($api_error['status']) . '</p>';
                                        }
                                        if (isset($api_error['details'])) {
                                            echo '<p><strong>Details:</strong> ' . htmlspecialchars($api_error['details']) . '</p>';
                                        }
                                        if (isset($api_error['error'])) {
                                            echo '<p><strong>Error:</strong> ' . htmlspecialchars($api_error['error']) . '</p>';
                                        }
                                        if (isset($api_error['error_description'])) {
                                            echo '<p><strong>Description:</strong> ' . htmlspecialchars($api_error['error_description']) . '</p>';
                                        }
                                        ?>
                                        <p>Please check your payment details and try again. If the problem persists, please contact support.</p>
                                    </div>
                                <?php } ?>
                                
                                <?php if (isset($processing) && $processing) { ?>
                                    <div class="alert alert-info">
                                        <h4><i class="icon fa fa-info"></i> Payment Processing</h4>
                                        <p>Your payment request has been submitted. Please check your phone to complete the payment.</p>
                                        <?php if (isset($trans_ref)) { ?>
                                            <p><strong>Transaction Reference:</strong> <?php echo htmlspecialchars($trans_ref); ?></p>
                                        <?php } ?>
                                    </div>
                                <?php } ?>
                                
                                <?php if (validation_errors()) { ?>
                                    <div class="alert alert-danger">
                                        <?php echo validation_errors(); ?>
                                    </div>
                                <?php } ?>

                                <form action="<?php echo base_url(); ?>course_payment/momopay/pay" method="post">
                                    <table class="table2" width="100%">
                                        <tr>
                                            <th><?php echo ('Description'); ?></th>
                                            <th class="text-right"><?php echo ('Amount') ?></th>
                                        </tr>
                                        <?php
                                        if (isset($params['course_name'])) {
                                            ?>
                                            <tr>
                                                <td>
                                                    <span class="title"><?php echo htmlspecialchars($params['course_name']); ?></span>
                                                    <span class="product-description">
                                                        <?php echo isset($params['description']) ? htmlspecialchars($params['description']) : ''; ?></span>
                                                </td>
                                                <td class="text-right"><?php echo isset($params['currency_symbol']) ? $params['currency_symbol'] : ''; ?><?php echo number_format($params['actual_amount'], 2); ?></td>
                                            </tr>
                                            <?php
                                        }
                                        ?>
                                        
                                        <?php if(isset($params['discount']) && $params['discount']>0){ ?>
                                        <tr class="border_bottom">
                                            <td> 
                                                <span class="text-discount" style="color: #17a2b8;"><?php echo ('Discount'); ?></span>
                                            </td>
                                            <td class="text-right" style="color: #17a2b8;"><?php echo isset($params['currency_symbol']) ? $params['currency_symbol'] : ''; ?><?php echo number_format($params['discount'], 2); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <?php if(isset($params['gateway_processing_charge']) && $params['gateway_processing_charge']>0){ ?>
                                        <tr class="border_bottom">
                                            <td>
                                                <span class="text-text-success"><?php echo ('Processing Fees'); ?></span>
                                            </td>
                                            <td class="text-right"><?php echo isset($params['currency_symbol']) ? $params['currency_symbol'] : ''; ?><?php echo number_format((float) $params['gateway_processing_charge'], 2); ?></td>
                                        </tr>
                                        <?php } ?>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"> <?php echo ('Total Amount'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <?php 
                                                $total_amount = (isset($params['total_amount']) ? $params['total_amount'] : 0) 
                                                    + (isset($params['gateway_processing_charge']) ? $params['gateway_processing_charge'] : 0);
                                                echo isset($params['currency_symbol']) ? $params['currency_symbol'] : ''; ?><?php echo number_format($total_amount, 2); 
                                            ?></td>
                                        </tr>
                                        
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Phone Number') ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="phone" required value="<?php echo set_value('phone', isset($params['contact_no']) ? $params['contact_no'] : ''); ?>" /></td>
                                        </tr>
                                        
                                        <tr><td colspan="2"><hr /></td></tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff">  </td>
                                            <td bgcolor="#fff" class="text-right"> <button type="submit" name="search" value="" class="btn btn-info" <?php echo (isset($processing) && $processing) ? 'disabled' : ''; ?>><i class="fa fa fa-chevron-right"></i> <?php echo ('Pay With MomoPay'); ?></button>  </td>
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
