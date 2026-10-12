<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>DPO Pay Custom Integration</title>
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
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/dpopay.png" style="margin-bottom: 10px; max-width: 200px;"><br />DPO Payment Gateway</h3>
                            <div class="paybody">
                                <?php if (isset($api_error) && $api_error) { ?>
                                    <div class="alert alert-danger">
                                        <h4><i class="icon fa fa-warning"></i> Payment Error!</h4>
                                        <?php
                                        if (isset($api_error['ResultExplanation'])) {
                                            echo '<p><strong>Error:</strong> ' . htmlspecialchars($api_error['ResultExplanation']) . '</p>';
                                        }
                                        if (isset($api_error['Result'])) {
                                            echo '<p><strong>Error Code:</strong> ' . htmlspecialchars($api_error['Result']) . '</p>';
                                        }
                                        if (isset($api_error['message'])) {
                                            echo '<p><strong>Error:</strong> ' . htmlspecialchars($api_error['message']) . '</p>';
                                        }
                                        ?>
                                        <p>Please check your payment details and try again. If problem persists, please contact support.</p>
                                    </div>
                                <?php } ?>
                                
                                <?php if (validation_errors()) { ?>
                                    <div class="alert alert-danger">
                                        <?php echo validation_errors(); ?>
                                    </div>
                                <?php } ?>

                                <form action="<?php echo base_url(); ?>course_payment/dpopay/pay" method="post">
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
                                            <td bgcolor="#fff"><?php echo ('Credit Card Number') ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="creditcardnumber" required value="<?php echo set_value('creditcardnumber'); ?>" /></td>
                                        </tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Credit Card Expiry'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="creditcardexpiry" required value="<?php echo set_value('creditcardexpiry'); ?>" placeholder="MMYY" /></td>
                                        </tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Credit Card CVV'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="creditcardcvv" required value="<?php echo set_value('creditcardcvv'); ?>" /></td>
                                        </tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff"><?php echo ('Card Holder Name'); ?>:</td>
                                            <td bgcolor="#fff" class="text-right"> <input type="text" class="form-control" name="cardholdername" required value="<?php echo set_value('cardholdername'); ?>" /></td>
                                        </tr>
                                        
                                        <tr><td colspan="2"><hr /></td></tr>
                                        <tr class="bordertoplightgray">
                                            <td bgcolor="#fff">  </td>
                                            <td bgcolor="#fff" class="text-right"> <button type="submit" name="search" value="" class="btn btn-info"><i class="fa fa fa-chevron-right"></i> <?php echo ('Pay With DPO'); ?></button>  </td>
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
