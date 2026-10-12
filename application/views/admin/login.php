<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="theme-color" content="#424242" />
        <title>Login : <?php echo $name; ?></title>        
        <link href="<?php echo base_url(); ?>uploads/school_content/admin_small_logo/<?php echo $this->setting_model->getAdminsmalllogo(); ?>" rel="shortcut icon" type="image/x-icon">
        <!-- CSS -->
        <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Roboto:400,100,300,500">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/usertemplate/assets/bootstrap/css/bootstrap.min.css">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/usertemplate/assets/font-awesome/css/font-awesome.min.css">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/usertemplate/assets/css/form-elements.css">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/usertemplate/assets/css/style.css">
        <link rel="stylesheet" href="<?php echo base_url(); ?>backend/usertemplate/assets/css/jquery.mCustomScrollbar.min.css">
    </head>
    <body>
        <!-- Top content -->
        <div class="top-content">
            <div class="inner-bg">
                <div class="container-fluid">
                    <div class="row">
                        <?php
                        
                        $offset = "";
                        $bgoffsetbg = "bgoffsetbg";
                        $bgoffsetbgno = "";
                        if (empty($notice)) {
                            
                            // $offset = "col-md-offset-4";
                            // $bgoffsetbg = "";
                            // $bgoffsetbgno = "bgoffsetbgno";
                        }
                        ?>  
                        <div class="<?php echo $bgoffsetbg; ?>">  
                            <div class="col-lg-4 col-md-4 col-sm-12 nopadding <?php echo $bgoffsetbgno; ?> <?php echo $offset; ?>">
                                 
                                <div class="loginbg">  
                                   <div class="form-top">
                                        <div class="form-top-left logowidth">
                                            <img src="<?php echo base_url(); ?>uploads/school_content/admin_logo/<?php echo $this->setting_model->getAdminlogo(); ?>" />    
                                        </div>
                                    </div>
                                    <div class="form-bottom">
                                        <h3 class="font-white bolds"><?php echo $this->lang->line('admin_login'); ?></h3>
                                        <?php
                                        if (isset($error_message)) {
                                            echo "<div class='alert alert-danger'>" . $error_message . "</div>";
                                        }
                                        ?>
                                        <?php
                                        if ($this->session->flashdata('message')) {
                                            echo "<div class='alert alert-success'>" . $this->session->flashdata('message') . "</div>";
                                            $this->session->unset_userdata('message'); 
                                        };
                                        ?>
                                        <?php
                                        if ($this->session->flashdata('disable_message')) {
                                            echo "<div class='alert alert-danger'>" . $this->session->flashdata('disable_message') . "</div>";
                                            $this->session->unset_userdata('disable_message'); 
                                        };
                                        ?>
                                        <!-- Login Method Tabs -->
                                        <div class="login-tab-switch" style="display: flex; gap: 8px; margin-bottom: 20px;">
                                            <button type="button" class="btn" id="tab-password-btn" onclick="switchLoginTab('password')" style="flex: 1; border-radius: 6px; font-weight: 600; padding: 10px; background: rgba(255,255,255,0.25); color: #fff; border: 1px solid rgba(255,255,255,0.4);"><i class="fa fa-lock"></i> Password</button>
                                            <button type="button" class="btn" id="tab-phone-btn" onclick="switchLoginTab('phone')" style="flex: 1; border-radius: 6px; font-weight: 600; padding: 10px; background: transparent; color: rgba(255,255,255,0.7); border: 1px solid rgba(255,255,255,0.2);"><i class="fa fa-mobile-phone fa-lg"></i> SMS OTP</button>
                                        </div>

                                        <!-- Password Login Container -->
                                        <div id="password-login-container">
                                            <form action="<?php echo site_url('site/login') ?>" method="post">
                                                <?php echo $this->customlib->getCSRF(); ?>
                                                <div class="form-group has-feedback">                                            
                                                    <input type="text" name="username" placeholder="<?php echo $this->lang->line('username'); ?>" value="<?php echo set_value('username') ?>" class="form-username form-control" id="form-username">
                                                    <span class="fa fa-envelope form-control-feedback"></span>
                                                    <span class="text-danger"><?php echo form_error('username'); ?></span>
                                                </div>
                                                <div class="form-group has-feedback">                      
                                                    <input type="password" value="<?php echo set_value('password') ?>" name="password" placeholder="<?php echo $this->lang->line('password'); ?>" class="form-password form-control" id="form-password">
                                                    <span class="fa fa-lock form-control-feedback"></span>
                                                    <span class="text-danger"><?php echo form_error('password'); ?></span>
                                                </div>
                                                <?php if($is_captcha){ ?>
                                                <div class="form-group has-feedback row"> 
                                                    <div class='col-lg-7 col-md-12 col-sm-6'>
                                                        <span id="captcha_image"><?php echo $captcha_image; ?></span>
                                                        <span title='Refresh Catpcha' class="fa fa-refresh catpcha" onclick="refreshCaptcha()"></span>
                                                    </div>
                                                    <div class='col-lg-5 col-md-12 col-sm-6'>
                                                        <input type="text" name="captcha" placeholder="<?php echo $this->lang->line('captcha'); ?>" class=" form-control" autocomplete="off" id="captcha"> 
                                                        <span class="text-danger"><?php echo form_error('captcha'); ?></span>
                                                    </div>
                                                </div>
                                                <?php } ?>
                                                <button type="submit" class="btn"><?php echo $this->lang->line('sign_in'); ?></button>
                                            </form>
                                            <a href="<?php echo site_url('site/forgotpassword') ?>" class="forgot"><i class="fa fa-key"></i> <?php echo $this->lang->line('forgot_password'); ?>?</a>
                                        </div>

                                        <!-- SMS OTP Login Container -->
                                        <div id="phone-login-container" style="display: none;">
                                            <div id="phone-alert" class="alert" style="display: none; font-size: 13px; padding: 10px 14px; margin-bottom: 14px; border-radius: 6px;"></div>

                                            <!-- Step 1: Mobile Number Input -->
                                            <div id="phone-step-1">
                                                <div class="form-group text-left" style="margin-bottom: 15px;">
                                                    <label style="color: #fff; font-size: 12px; font-weight: 500; margin-bottom: 6px; display: block;">Registered Mobile Number</label>
                                                    <div class="input-group">
                                                        <span class="input-group-addon" style="background: rgba(255,255,255,0.15); color: #fff; border-color: rgba(255,255,255,0.25); font-weight: 600;">+91</span>
                                                        <input type="tel" id="sms-phone-number" maxlength="10" placeholder="10-digit number" class="form-control" style="border-top-left-radius: 0; border-bottom-left-radius: 0; font-size: 16px; letter-spacing: 1px;" autocomplete="tel">
                                                    </div>
                                                    <p style="font-size: 11px; color: rgba(255,255,255,0.75); margin-top: 6px; margin-bottom: 0;"><i class="fa fa-shield"></i> We'll send an SMS verification OTP to this number.</p>
                                                </div>
                                                <div id="recaptcha-container"></div>
                                                <button type="button" id="btn-send-otp" onclick="handleSendOTP()" class="btn" style="width: 100%; margin-top: 10px; font-weight: 600;">
                                                    <i class="fa fa-paper-plane"></i> Send OTP via SMS
                                                </button>
                                            </div>

                                            <!-- Step 2: OTP Verification -->
                                            <div id="phone-step-2" style="display: none;">
                                                <div class="form-group text-left" style="margin-bottom: 15px;">
                                                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                                                        <label style="color: #fff; font-size: 12px; font-weight: 500; margin: 0;">Enter 6-digit OTP</label>
                                                        <a href="javascript:void(0)" onclick="resetPhoneStep()" style="color: #ffeb3b; font-size: 12px; text-decoration: underline;"><i class="fa fa-pencil"></i> Change Number</a>
                                                    </div>
                                                    <input type="text" id="sms-otp-code" maxlength="6" placeholder="• • • • • •" class="form-control" style="font-size: 22px; text-align: center; letter-spacing: 8px; font-weight: bold; height: 46px;" autocomplete="one-time-code">
                                                    <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 8px;">
                                                        <span id="otp-timer-text" style="color: rgba(255,255,255,0.75); font-size: 12px;">Resend OTP in <b id="otp-countdown">30</b>s</span>
                                                        <a href="javascript:void(0)" id="btn-resend-otp" onclick="handleResendOTP()" style="display: none; color: #ffeb3b; font-size: 12px; font-weight: 600; text-decoration: underline;"><i class="fa fa-repeat"></i> Resend OTP</a>
                                                    </div>
                                                </div>
                                                <button type="button" id="btn-verify-otp" onclick="handleVerifyOTP()" class="btn" style="width: 100%; margin-top: 10px; font-weight: 600;">
                                                    <i class="fa fa-check-circle"></i> Verify & Sign In
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            
                                <div class="col-lg-8 col-md-8 col-sm-12 nopadding-2">
                                   <div class="d-flex align-items-center text-wrap flex-column justify-content-center bg-position-sm-left bg-position-lg-center" style="background: url('<?php echo base_url(); ?>uploads/school_content/login_image/<?php echo $school['admin_login_page_background']; ?>') no-repeat; background-size:cover">  
                                    <div class="<?php if ($notice){ ?> bg-shadow-remove <?php } ?>">
                                    <?php
                                        if ($notice) {
                                    ?>
                                   
                                    <h3 class="h3"><?php echo $this->lang->line('whats_new_in'); ?> <?php echo $school['name']; ?>   </h3>
                                    <div class="loginright mCustomScrollbar">
                                        <div class="messages"> 

                                            <?php
                                            foreach ($notice as $notice_key => $notice_value) {
                                                ?>
                                                <h4><?php echo $notice_value['title']; ?></h4>

													<?php
													$string = strip_tags($notice_value['description']);
												
													if (mb_strlen($string, 'UTF-8') > 50) {
														// truncate string
														$stringCut = mb_substr($string, 0, 50, 'UTF-8');
														$endPoint = mb_strrpos($stringCut, ' ', 0, 'UTF-8');
												
														// if no space found, just use the raw cut
														$string = $endPoint !== false
															? mb_substr($stringCut, 0, $endPoint, 'UTF-8')
															: $stringCut;
												
														$string .= '... <a class="more" href="' . site_url('read/' . $notice_value['slug']) . '" target="_blank">'
															. $this->lang->line('read_more') . '</a>';
													}
												
													echo '<p>' . $string . '</p>';
													?>

                                                <div class="logdivider"></div>
                                                <?php
                                            }
                                            ?>
                                        </div>  
                                    </div>
                                    <?php
                                        }
                                    ?>
                                  </div>  
                                  </div>  
                                </div><!--./col-lg-6-->
                                
                        </div>  
                    </div>
                </div>
            </div>
        </div>
        <!-- Javascript -->
        <script src="<?php echo base_url(); ?>backend/usertemplate/assets/js/jquery-1.11.1.min.js"></script>
        <script src="<?php echo base_url(); ?>backend/usertemplate/assets/bootstrap/js/bootstrap.min.js"></script>
        <script src="<?php echo base_url(); ?>backend/usertemplate/assets/js/jquery.backstretch.min.js"></script>
        <script src="<?php echo base_url(); ?>backend/usertemplate/assets/js/jquery.mCustomScrollbar.min.js"></script>
        <script src="<?php echo base_url(); ?>backend/usertemplate/assets/js/jquery.mousewheel.min.js"></script>
    </body>
</html>
<script type="text/javascript">
    $(document).ready(function () {
        $('.login-form input[type="text"], .login-form input[type="password"], .login-form textarea').on('focus', function () {
            $(this).removeClass('input-error');
        });
        $('.login-form').on('submit', function (e) {
            $(this).find('input[type="text"], input[type="password"], textarea').each(function () {
                if ($(this).val() == "") {
                    e.preventDefault();
                    $(this).addClass('input-error');
                } else {
                    $(this).removeClass('input-error');
                }
            });
        });
    });
</script>
<script type="text/javascript">
    function refreshCaptcha(){
        $.ajax({
            type: "POST",
            url: "<?php echo base_url('site/refreshCaptcha'); ?>",
            data: {},
            success: function(captcha){
                $("#captcha_image").html(captcha);
            }
        });
    }    
</script>

<!-- Firebase App & Auth SDK (v10 compat) -->
<script src="https://www.gstatic.com/firebasejs/10.9.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.9.0/firebase-auth-compat.js"></script>

<script type="text/javascript">
    var firebaseConfig = {
        apiKey: "AIzaSyAe1_cGg5mDpGUA0kYKNNxymWPQqm8YQ-s",
        authDomain: "prime-school-sms.firebaseapp.com",
        projectId: "prime-school-sms",
        storageBucket: "prime-school-sms.firebasestorage.app",
        messagingSenderId: "407763495068",
        appId: "1:407763495068:web:0fc1c0fe0cb7955bd86559"
    };

    if (!firebase.apps.length) {
        firebase.initializeApp(firebaseConfig);
    }

    var windowConfirmationResult = null;
    var otpTimerInterval = null;

    function switchLoginTab(type) {
        $('#phone-alert').hide().removeClass('alert-danger alert-success');
        if (type === 'phone') {
            $('#tab-password-btn').css({ 'background': 'transparent', 'color': 'rgba(255,255,255,0.7)', 'border-color': 'rgba(255,255,255,0.2)' });
            $('#tab-phone-btn').css({ 'background': 'rgba(255,255,255,0.25)', 'color': '#fff', 'border-color': 'rgba(255,255,255,0.4)' });
            $('#password-login-container').hide();
            $('#phone-login-container').fadeIn(200);
            initRecaptcha();
        } else {
            $('#tab-phone-btn').css({ 'background': 'transparent', 'color': 'rgba(255,255,255,0.7)', 'border-color': 'rgba(255,255,255,0.2)' });
            $('#tab-password-btn').css({ 'background': 'rgba(255,255,255,0.25)', 'color': '#fff', 'border-color': 'rgba(255,255,255,0.4)' });
            $('#phone-login-container').hide();
            $('#password-login-container').fadeIn(200);
        }
    }

    function initRecaptcha() {
        if (!window.recaptchaVerifier) {
            try {
                window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('recaptcha-container', {
                    'size': 'invisible',
                    'callback': function(response) {
                        // reCAPTCHA solved
                    },
                    'expired-callback': function() {
                        showPhoneAlert('reCAPTCHA expired, please try again.', 'danger');
                    }
                });
                window.recaptchaVerifier.render().catch(function(e){ console.warn(e); });
            } catch (err) {
                console.warn('reCAPTCHA init error:', err);
            }
        }
    }

    function showPhoneAlert(msg, type) {
        $('#phone-alert').removeClass('alert-danger alert-success').addClass('alert-' + type).html(msg).fadeIn();
    }

    function handleSendOTP() {
        var rawPhone = $('#sms-phone-number').val().trim();
        var cleanPhone = rawPhone.replace(/[^0-9]/g, '');
        if (cleanPhone.length < 10) {
            showPhoneAlert('Please enter a valid 10-digit mobile number.', 'danger');
            return;
        }

        var fullNumber = '+91' + cleanPhone.slice(-10);
        $('#btn-send-otp').prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> Sending OTP SMS...');
        $('#phone-alert').hide();

        initRecaptcha();

        firebase.auth().signInWithPhoneNumber(fullNumber, window.recaptchaVerifier)
            .then(function(confirmationResult) {
                windowConfirmationResult = confirmationResult;
                $('#btn-send-otp').prop('disabled', false).html('<i class="fa fa-paper-plane"></i> Send OTP via SMS');
                $('#phone-step-1').hide();
                $('#phone-step-2').fadeIn();
                $('#sms-otp-code').focus();
                showPhoneAlert('6-digit OTP has been sent via SMS to <b>' + fullNumber + '</b>', 'success');
                startOtpCountdown();
            })
            .catch(function(error) {
                console.error('Firebase Phone Auth Error:', error);
                $('#btn-send-otp').prop('disabled', false).html('<i class="fa fa-paper-plane"></i> Send OTP via SMS');
                if (window.grecaptcha && window.recaptchaWidgetId) {
                    grecaptcha.reset(window.recaptchaWidgetId);
                }
                var errorMsg = error.message || 'Failed to send OTP SMS. Please try again.';
                if (error.code === 'auth/quota-exceeded') {
                    errorMsg = 'Daily SMS quota exceeded. Please contact school administration or use password login.';
                } else if (error.code === 'auth/invalid-phone-number') {
                    errorMsg = 'The provided phone number is invalid.';
                } else if (error.code === 'auth/too-many-requests') {
                    errorMsg = 'Too many requests. Please wait a few minutes before trying again.';
                }
                showPhoneAlert(errorMsg, 'danger');
            });
    }

    function handleResendOTP() {
        handleSendOTP();
    }

    function startOtpCountdown() {
        var count = 30;
        $('#btn-resend-otp').hide();
        $('#otp-timer-text').show();
        $('#otp-countdown').text(count);

        if (otpTimerInterval) clearInterval(otpTimerInterval);
        otpTimerInterval = setInterval(function() {
            count--;
            $('#otp-countdown').text(count);
            if (count <= 0) {
                clearInterval(otpTimerInterval);
                $('#otp-timer-text').hide();
                $('#btn-resend-otp').show();
            }
        }, 1000);
    }

    function resetPhoneStep() {
        if (otpTimerInterval) clearInterval(otpTimerInterval);
        $('#phone-step-2').hide();
        $('#phone-step-1').fadeIn();
        $('#phone-alert').hide();
    }

    function handleVerifyOTP() {
        var otp = $('#sms-otp-code').val().trim();
        if (otp.length < 6) {
            showPhoneAlert('Please enter the complete 6-digit OTP.', 'danger');
            return;
        }

        if (!windowConfirmationResult) {
            showPhoneAlert('Session expired. Please request a new OTP.', 'danger');
            resetPhoneStep();
            return;
        }

        $('#btn-verify-otp').prop('disabled', true).html('<i class="fa fa-spinner fa-spin"></i> Verifying...');
        $('#phone-alert').hide();

        windowConfirmationResult.confirm(otp)
            .then(function(result) {
                var rawPhone = $('#sms-phone-number').val().trim();
                showPhoneAlert('OTP Verified! Authenticating your staff account...', 'success');

                var csrfName = '<?php echo $this->security->get_csrf_token_name(); ?>';
                var csrfHash = '<?php echo $this->security->get_csrf_hash(); ?>';
                var postData = {
                    phone: rawPhone,
                    user_type: 'staff'
                };
                postData[csrfName] = csrfHash;

                $.ajax({
                    type: "POST",
                    url: "<?php echo site_url('site/login_by_phone'); ?>",
                    data: postData,
                    dataType: "json",
                    success: function(response) {
                        if (response.status === 1) {
                            showPhoneAlert('Welcome! Redirecting to dashboard...', 'success');
                            window.location.href = response.redirect_url;
                        } else {
                            $('#btn-verify-otp').prop('disabled', false).html('<i class="fa fa-check-circle"></i> Verify & Sign In');
                            showPhoneAlert(response.message || 'No registered staff account found with this phone number.', 'danger');
                        }
                    },
                    error: function(xhr) {
                        $('#btn-verify-otp').prop('disabled', false).html('<i class="fa fa-check-circle"></i> Verify & Sign In');
                        showPhoneAlert('Server communication error. Please try again or use password.', 'danger');
                    }
                });
            })
            .catch(function(error) {
                console.error('OTP confirmation error:', error);
                $('#btn-verify-otp').prop('disabled', false).html('<i class="fa fa-check-circle"></i> Verify & Sign In');
                showPhoneAlert('Incorrect OTP code entered. Please check and try again.', 'danger');
            });
    }
</script>