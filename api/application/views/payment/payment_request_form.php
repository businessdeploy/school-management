<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payment Request</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 600px;
            width: 100%;
            padding: 40px;
        }
        
        h1 {
            color: #333;
            margin-bottom: 10px;
            text-align: center;
        }
        
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        label {
            display: block;
            margin-bottom: 8px;
            color: #333;
            font-weight: 500;
        }
        
        input[type="text"],
        input[type="password"],
        input[type="number"] {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        input[type="text"]:focus,
        input[type="password"]:focus,
        input[type="number"]:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .btn {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn:active {
            transform: translateY(0);
        }
        
        .btn-secondary {
            background: #6c757d;
            margin-top: 10px;
        }
        
        .error {
            background: #fee;
            color: #c33;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #c33;
        }
        
        .success {
            background: #efe;
            color: #3c3;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #3c3;
        }
        
        .response-box {
            background: #f8f9fa;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            padding: 15px;
            margin-top: 20px;
            max-height: 300px;
            overflow-y: auto;
        }
        
        .response-box pre {
            margin: 0;
            white-space: pre-wrap;
            word-wrap: break-word;
            font-size: 14px;
        }
        
        .login-info {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 4px solid #2196F3;
        }
        
        .login-info p {
            margin: 5px 0;
            color: #1976D2;
        }
        
        .logout-link {
            text-align: center;
            margin-top: 20px;
        }
        
        .logout-link a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }
        
        .logout-link a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>💳 Payment Request</h1>
        <p class="subtitle">Submit your payment request securely</p>
        
        <?php if (!$is_logged_in): ?>
            <!-- Login Form -->
            <?php if (!empty($login_error)): ?>
                <div class="error"><?php echo htmlspecialchars($login_error); ?></div>
            <?php endif; ?>
            
            <?php echo form_open('payment_request', array('method' => 'POST')); ?>
                <div class="form-group">
                    <label for="student_id">Username / Admission No / Mobile / Email</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'student_id',
                        'name' => 'student_id',
                        'required' => true,
                        'autofocus' => true,
                        'placeholder' => 'Enter username, admission no, mobile, or email',
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="password">Password</label>
                    <?php echo form_password(array(
                        'id' => 'password',
                        'name' => 'password',
                        'required' => true,
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <?php echo form_submit('login', 'Login', 'class="btn"'); ?>
            <?php echo form_close(); ?>
            
        <?php else: ?>
            <!-- Payment Request Form -->
            <div class="login-info">
                <p><strong>Logged in as Student ID:</strong> <?php echo htmlspecialchars($student_id); ?></p>
            </div>
            
            <?php if (!empty($payment_error)): ?>
                <div class="error"><?php echo htmlspecialchars($payment_error); ?></div>
            <?php endif; ?>
            
            <?php if (!empty($payment_response)): ?>
                <div class="success">Payment request submitted successfully!</div>
                <div class="response-box">
                    <strong>API Response:</strong>
                    <pre><?php echo htmlspecialchars($payment_response); ?></pre>
                </div>
            <?php endif; ?>
            
            <?php echo form_open('payment_request', array('method' => 'POST')); ?>
                <div class="form-group">
                    <label for="student_fees_master_id">Student Fees Master ID</label>
                    <?php echo form_input(array(
                        'type' => 'number',
                        'id' => 'student_fees_master_id',
                        'name' => 'student_fees_master_id',
                        'value' => '1',
                        'required' => true,
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="fee_groups_feetype_id">Fee Groups Fee Type ID</label>
                    <?php echo form_input(array(
                        'type' => 'number',
                        'id' => 'fee_groups_feetype_id',
                        'name' => 'fee_groups_feetype_id',
                        'value' => '1',
                        'required' => true,
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="student_transport_fee_id">Student Transport Fee ID (Optional)</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'student_transport_fee_id',
                        'name' => 'student_transport_fee_id',
                        'value' => '',
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="fee_discount_group">Fee Discount Group</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'fee_discount_group',
                        'name' => 'fee_discount_group',
                        'value' => '[{0:2}]',
                        'required' => true,
                        'class' => 'form-control'
                    )); ?>
                </div>
                
                <?php echo form_submit('submit_payment', 'Submit Payment Request', 'class="btn"'); ?>
            <?php echo form_close(); ?>
            
            <div class="logout-link">
                <a href="<?php echo base_url('payment_request?logout=1'); ?>">Logout</a>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>

