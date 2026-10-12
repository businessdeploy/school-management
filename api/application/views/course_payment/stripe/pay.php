<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Stripe Pay Custom Integration Demo</title>
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap.min.css">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/dist/css/style-api.css">
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.0.0/jquery.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.2.0/js/bootstrap.min.js"></script>
    </head>
    <body>
        <div class="container">
            <div class="row">
                <div class="col-md-12">
                    <div class="paybox">
                        <div class="paybox_bg">
                            <h3 class="bt_title"><img src="<?php echo base_url(); ?>/backend/images/stripe.png">
                                <span>Stripe Payment Gateway</span></h3>
                            <div class="paybody">

                                <div class="paymentbg">
                                    <div class="invtext">Course Purchase Details</div>
                                   
                            <div class="dropin-page"> 
                          
                                <?php if(!empty($session_params['course_thumbnail'])){
                                    ?>
                                    <div class="img-container">
                                        <img src="<?php echo $this->customlib->getCourseThumbnailPath($session_params['course_thumbnail']); ?>" class="img-responsive center-block">
                                    </div>
                                    <?php
                                  }?>
                                   <table class="table mb0 paytable">
                                        <tr>
                                            <td class="bmedium text-center pb20" colspan="2">
                                                <?php echo $session_params['course_name']; ?>
                                            </td>
                                        </tr>
                                        
										<tr>
											<td><span class="text text-right"><?php echo ('Amount'); ?>:</span></td>
											<td class="text-right"><?php echo amountFormat((float) $session_params['total_amount'], 2, '.', ''); ?></td>
										</tr>
                                        
										<tr>
											<td><span class="text text-right"><?php echo ('Processing Fees'); ?>:</span></td>
											<td class="text-right"><?php echo amountFormat((float) $session_params['gateway_processing_charge'], 2, '.', ''); ?></td>
										</tr>
                                        
										<tr>
											<td><span class="text text-right"><?php echo ('Total'); ?>:</span></td>
											<td class="text-right"><?php echo amountFormat((float) ($session_params['gateway_processing_charge'] + $session_params['total_amount']), 2, '.', ''); ?></td>
										</tr>
										
                                    <tr>
                                       
                                        <td class="bmedium" colspan="2"> 
                                          <span class="payment-errors text-red"></span>
                                        </td>
                                    </tr>  
                                    <tr><td>  <?php if ($error) {
                                ?>
                                <div class="alert alert-danger error" ><?php
                                   foreach ($error as $key => $value) {
                                       echo $value."<br>";
                                   }
                                    ?> </div>
                            <?php }
                            ?></td>
                                               
                                              </tr> 
                                                
                                            </table>
                               
                                <form id="stripe-payment-form" class="paddtlrb" action="<?php echo site_url('user/gateway/stripe/complete'); ?>" method="POST">
                                <input type='hidden' id='baseurl' value='<?php echo  site_url(); ?>'/>
                                <input type='hidden' id='publishable_key' value='<?php echo $publishable_key; ?>'>
                                <input type='hidden' id='currency' value='<?php echo $session_params['currency_name']; ?>'>
                                <input type='hidden' id='description' value='<?php echo 'Online fees deposit'; ?>'>

                                <input type="hidden" name="student_id" value="<?php echo $session_params['student_id']; ?>">
                                <input type="hidden" name="total" id="amount" value="<?php echo (convertBaseAmountCurrencyFormat($session_params['total_amount'] +$session_params['gateway_processing_charge'])); ?>">
                                  
                                        <div id="stripe-payment-element">
                                            <!--Stripe.js will inject the Payment Element here to get card details-->
                                        </div>
                                        <div class="button-between">
                                            <br>
											<a class="btn btn-primary" href="<?php echo base_url('course_payment/course_payment/paymentfailed'); ?>" > <i class="fa fa-money"></i>  Back</a>
                                            <button type="submit" class="pay btn btn-primary" id="submit-button"  data-loading-text="<i class='fa fa-circle-o-notch fa-spin'></i> Processing"> <i class="fa fa-money"></i> Pay Now</button>
											
											 
													  
													  
											
                                            <div id="payment-reinitiate" class="hidden" >

                                <button class="btn btn-primary" type="button" onclick="reinitiateStripe()"> <i class="fa fa-money"></i>  Reinitiate Payment</button>
                            </div>
                                        </div>
                                     
                                </div>    

                            </form>
                                </div>
                            </div>
                       
                            </div>      
                        </div><!--./paybox-->
                    </div><!--./paybox_bg-->
                </div><!--./col-md-12-->
            </div><!--./row-->
        </div><!--./container-->
        
    </body>

<script src="https://js.stripe.com/v3/"></script>
 <script src="<?php echo base_url('backend/js/stripe-checkout-course.js') ?>" defer></script>
</html>