<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Stripe Pay Custom Integration Demo</title>
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
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/razorpay.jpg" style="margin-bottom: 10px;"><br />Razorpay Payment Gateway </h3>

                            <div class="paybody">
                                <table class="table2" width="100%">
                                    <tr>
                                        <th><?php echo ('Description'); ?></th>
                                        <th class="text-right"><?php echo ('Amount') ?></th>
                                    </tr>
                                      <?php
                                    foreach ($params['student_fees_master_array'] as $fees_key => $fees_value) {
                                        ?>
                                        <tr>
                                             <td>
                                                <span class="title"><?php if ($fees_value['is_system']) {
                echo $this->lang->line($fees_value['fee_group_name']);
            } else {
                echo $fees_value['fee_group_name'] ;
            }?> </span>
                                                <span class="product-description">
                                                    <?php  if ($fees_value['is_system']) {
                echo $this->lang->line($fees_value['fee_type_code']);
            } else {
                echo $fees_value['fee_type_code'];
            } ?></span>
                                            </td>
                                            <td class="text-right"><?php echo $setting[0]['currency_symbol'] . $fees_value['amount_balance']; ?></td>
                                        </tr>
                                        <tr class="border_bottom">
                                            <td> 
                                                <span class="text-fine"><?php echo ('Fine'); ?></span></td>
                                            <td class="text-right"><?php echo $setting[0]['currency_symbol'] . $fees_value['fine_balance']; ?></td>
                                        </tr>
                                        <?php
                                    }
                                    ?>
                                    

                                    <tr class="bordertoplightgray">
                                        <td bgcolor="#fff"> <?php echo ('Total Fine'); ?>:</td>
                                        <td bgcolor="#fff" class="text-right"> <?php echo $setting[0]['currency_symbol'] .($params['fine_amount_balance']); ?></td>
                                    </tr>
                                     <?php if($params['gateway_processing_charge']>0){ ?>
                                                       <tr class="border_bottom">
                                            <td>
                                                <span class="text-text-success"><?php echo ('Processing Fees'); ?></span>
                                            </td>
                                            <td class="text-right"><?php echo $setting[0]['currency_symbol'] .((float) $params['gateway_processing_charge']); ?></td>
                                        </tr>
                                    <?php } ?>
                                    <tr class="bordertoplightgray">
                                        <td bgcolor="#fff"> <?php echo ('Total Amount'); ?>:</td>
                                        <td bgcolor="#fff" class="text-right"> <?php echo $setting[0]['currency_symbol'] .($params['total']- $params['applied_fee_discount']+$params['gateway_processing_charge']); ?></td>
                                    </tr>
                                    <tr><td colspan="2"><hr /></td></tr>
                                    <tr class="bordertoplightgray">
                                        <td  bgcolor="#fff">  </td>
                                        <td  bgcolor="#fff" class="text-right"> <button type="button" onclick="pay()" name="search"  value="" class="btn btn-info"><i class="fa fa fa-chevron-right"></i> <?php echo ('Pay With Razorpay'); ?></button>  </td>
                                    </tr>
                                </table>
                            </div>    
                        </div><!--./paybox-->
                    </div><!--./paybox_bg-->
                </div><!--./col-md-12-->
            </div><!--./row-->
        </div><!--./container-->

        <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
        <script src="https://code.jquery.com/jquery-3.3.1.min.js"></script> 
        <script>
                                            var SITEURL = "<?php echo base_url() ?>";

                                            function pay(e) {
                                                var totalAmount = <?php echo $params['total']; ?>;
                                                var product_id = <?php echo $merchant_order_id; ?>;
                                                var options = {
                                                    "key": "<?php echo $key_id; ?>",
                                                    "amount": "<?php echo ($params['total']*100); ?>", // 2000 paise = INR 20
                                                    "name": "<?php echo $name; ?>",
                                                    "description": "<?php echo $title; ?>",
                                                    "currency": "<?php echo 'INR'; ?>",
                                                    "image": "https://www.73lines.com/web/image/12427",
                                                    "callback_url": SITEURL + 'gateway/razorpay/multi_callback/<?php echo $id;?>',
                                                    "redirect": true,
                                                    "handler": function (response) {



                                                    },

                                                    "theme": {
                                                        "color": "#528FF0"
                                                    }
                                                };
                                                var rzp1 = new Razorpay(options);
                                                rzp1.open();

                                            }
                                            ;

        </script>

    </body>
</html>