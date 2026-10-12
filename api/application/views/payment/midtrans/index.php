<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Midtrans Custom Integration </title>
        <link href="style.css" type="text/css" rel="stylesheet" />
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap.min.css">
        <script type="text/javascript"
                src="https://app.sandbox.midtrans.com/snap/snap.js"
        data-client-key="SB-Mid-client-2uDtZD3V5ZA_pNYW"></script> 
        <script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js"></script>
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
            .bt_title img{width: auto; height: auto;}
        </style>

    </head>
    <body>

        <div class="container">
            <div class="row">
                <div class="col-md-12">
                    <div class="paybox">
                        <div class="paybox_bg">
                            <h3 class="bt_title"><img src="<?php echo base_url();?>/backend/images/midtrans.jpg" style="margin-bottom: 10px;"><br />Midtrans Payment Gateway </h3>

                            <div class="paybody">
                                <?php if (isset($api_error) && !empty($api_error)) { ?>
                                    <div class="alert alert-danger">
                                        <strong><?php echo ('Error'); ?>:</strong><br/>
                                        <?php 
                                        if (is_array($api_error)) {
                                            if (isset($api_error['error'])) {
                                                echo htmlspecialchars($api_error['error']);
                                            } else {
                                                echo htmlspecialchars(print_r($api_error, true));
                                            }
                                        } else {
                                            echo htmlspecialchars($api_error);
                                        }
                                        ?>
                                    </div>
                                <?php } ?>
                                
                                <form id="payment-form" method="post" action="<?= site_url() ?>/admin/admin/response">
                                    <input type="hidden" name="result_type" id="result-type" value="">
                                    <input type="hidden" name="result_data" id="result-data" value="">
                                    <input type="hidden" name="session_id" id="session-id" value="<?php echo isset($id) ? $id : ''; ?>">
                                </form>

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
                                    
                                    <tr><td colspan="2"><hr /></td></tr>
                                    <tr class="bordertoplightgray">
                                        <td bgcolor="#fff">  </td>
                                        <td bgcolor="#fff" class="text-right"> 
                                            <button type="submit" name="search" id="pay-button" value="" class="btn btn-info" <?php echo (isset($api_error) && !empty($api_error)) ? 'disabled' : ''; ?>>
                                                <i class="fa fa fa-chevron-right"></i> <?php echo ('Pay With Midtrans'); ?>
                                            </button>  
                                        </td>
                                    </tr>
                                </table>
                            </div>    
                        </div><!--./paybox-->
                    </div><!--./paybox_bg-->
                </div><!--./col-md-12-->
            </div><!--./row-->
        </div><!--./container-->

    </body>
    <script type="text/javascript">
        var resultType = document.getElementById('result-type');
        var resultData = document.getElementById('result-data');

        function changeResult(type, data) {
            $("#result-type").val(type);
            $("#result-data").val(JSON.stringify(data));
        }
        var payButton = document.getElementById('pay-button');
        var snapToken = '<?php echo isset($snap_Token) ? $snap_Token : ''; ?>';
        
        payButton.addEventListener('click', function () {
            if (!snapToken || snapToken === '') {
                alert('Payment gateway is not available. Please check the error message above.');
                return false;
            }
            
            snap.pay(snapToken, {
                onSuccess: function (result) {
                    changeResult('success', result);
                    $.ajax({
                        url: '<?php echo base_url(); ?>gateway/midtrans/success',
                        type: 'POST',
                        data: $('#payment-form').serialize(),
                        dataType: "json",
                        success: function (msg) {
                            if (msg.success) {
                                window.location.href = "<?php echo base_url(); ?>payment/successinvoice/" + msg.invoice_id + "/" + msg.sub_invoice_id;
                            } else {
                                alert('Payment processing failed: ' + (msg.error || 'Unknown error'));
                                window.location.href = "<?php echo base_url(); ?>payment/paymentfailed";
                            }
                        },
                        error: function(xhr, status, error) {
                            alert('Payment processing error: ' + error);
                            window.location.href = "<?php echo base_url(); ?>payment/paymentfailed";
                        }
                    });
                },
                onPending: function (result) {
                    console.log('pending');
                    console.log(result);
                },
                onError: function (result) {
                    console.log('error');
                    console.log(result);
                    alert('Payment error occurred');
                },
                onClose: function () {
                    console.log('customer closed the popup without finishing the payment');
                }
            });
        });
    </script>
</html>
