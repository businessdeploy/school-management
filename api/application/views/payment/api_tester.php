<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payment API Tester</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            padding: 30px;
        }
        
        h1 {
            color: #333;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 14px;
        }
        
        .section {
            margin-bottom: 25px;
            padding: 20px;
            background: #fafafa;
            border-radius: 6px;
            border: 1px solid #e0e0e0;
        }
        
        .section-title {
            font-size: 16px;
            font-weight: 600;
            color: #333;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        label {
            display: block;
            margin-bottom: 6px;
            color: #555;
            font-size: 13px;
            font-weight: 500;
        }
        
        input[type="text"],
        input[type="url"],
        select,
        textarea {
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            font-family: 'Consolas', 'Monaco', monospace;
            transition: border-color 0.2s;
        }
        
        input[type="text"]:focus,
        input[type="url"]:focus,
        select:focus,
        textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        
        textarea {
            min-height: 200px;
            resize: vertical;
        }
        
        .method-select {
            display: flex;
            gap: 10px;
            align-items: center;
        }
        
        select {
            width: auto;
            min-width: 100px;
        }
        
        .btn {
            padding: 12px 24px;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 4px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
        }
        
        .btn:hover {
            background: #5568d3;
        }
        
        .btn:active {
            transform: translateY(1px);
        }
        
        .response-section {
            margin-top: 30px;
        }
        
        .response-box {
            background: #f8f9fa;
            color: #333;
            padding: 20px;
            border-radius: 4px;
            border: 1px solid #e0e0e0;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 13px;
            max-height: 500px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        .error-box {
            background: #fee;
            color: #c33;
            padding: 15px;
            border-radius: 4px;
            border-left: 4px solid #c33;
            margin-bottom: 20px;
        }
        
        .success-box {
            background: #efe;
            color: #3c3;
            padding: 15px;
            border-radius: 4px;
            border-left: 4px solid #3c3;
            margin-bottom: 20px;
        }
        
        .info-box {
            background: #e7f3ff;
            color: #1976D2;
            padding: 12px;
            border-radius: 4px;
            margin-bottom: 15px;
            font-size: 13px;
        }
        
        .response-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 1px solid #e0e0e0;
        }
        
        .response-info {
            display: flex;
            gap: 20px;
            font-size: 13px;
            color: #666;
        }
        
        .response-info span {
            font-weight: 600;
            color: #333;
        }
        
        .two-column {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
        }
        
        @media (max-width: 768px) {
            .two-column {
                grid-template-columns: 1fr;
            }
        }
        
        .json-pretty {
            color: #d4d4d4;
        }
        
        .json-key {
            color: #9cdcfe;
        }
        
        .json-string {
            color: #ce9178;
        }
        
        .json-number {
            color: #b5cea8;
        }
        
        .student-info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .info-card {
            background: white;
            padding: 15px;
            border-radius: 6px;
            border: 1px solid #e0e0e0;
        }
        
        .info-card label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 5px;
            display: block;
        }
        
        .info-card .value {
            font-size: 16px;
            color: #333;
            font-weight: 500;
        }
        
        .fees-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-radius: 6px;
            overflow: hidden;
        }
        
        .fees-table th,
        .fees-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }
        
        .fees-table th {
            background: #007bff;
            color: white;
            font-weight: 600;
            font-size: 13px;
            text-transform: uppercase;
        }
        
        .fees-table td {
            font-size: 14px;
        }
        
        .fees-table tbody tr:hover {
            background: #f8f9fa;
        }
        
        .fees-table tfoot {
            background: #f8f9fa;
        }
        
        .status-paid {
            color: #28a745;
            font-weight: 600;
        }
        
        .status-unpaid {
            color: #dc3545;
            font-weight: 600;
        }
        
        .status-partial {
            color: #ffc107;
            font-weight: 600;
        }
        
        .loading-spinner {
            text-align: center;
            padding: 40px;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>
            <span>🚀</span>
            Payment API Tester
        </h1>
        <p class="subtitle">Test your Payment API endpoints like Postman</p>
        
        <form id="apiForm">
        
        <!-- Request Section -->
        <div class="section">
            <div class="section-title">
                <span>📡</span>
                Request
            </div>
            
            <div class="form-group method-select">
                <label for="method">Method:</label>
                <?php 
                $methods = array('GET' => 'GET', 'POST' => 'POST', 'PUT' => 'PUT', 'DELETE' => 'DELETE');
                echo form_dropdown('method', $methods, 'POST', 'id="method" class="form-control"');
                ?>
            </div>
            
            <div class="form-group">
                <label for="api_url">API URL:</label>
                <?php echo form_input(array(
                    'type' => 'url',
                    'id' => 'api_url',
                    'name' => 'api_url',
                    'value' => base_url('payment/fees_pay'),
                    'placeholder' => 'Enter API endpoint URL',
                    'required' => true
                )); ?>
            </div>
        </div>
        
        <!-- Headers Section -->
        <div class="section">
            <div class="section-title">
                <span>📋</span>
                Headers
            </div>
            
            <div class="info-box">
                Configure your API headers below. Default values are pre-filled.
            </div>
            
            <div class="two-column">
                <div class="form-group">
                    <label for="auth_token">Authorization:</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'auth_token',
                        'name' => 'auth_token',
                        'value' => 'NQNANwOQNQ',
                        'placeholder' => 'Authorization token'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="auth_key">Auth-Key:</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'auth_key',
                        'name' => 'auth_key',
                        'value' => 'schoolAdmin@',
                        'placeholder' => 'Auth key'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="client_service">Client-Service:</label>
                    <?php echo form_input(array(
                        'type' => 'text',
                        'id' => 'client_service',
                        'name' => 'client_service',
                        'value' => 'smartschool',
                        'placeholder' => 'Client service name'
                    )); ?>
                </div>
                
                <div class="form-group">
                    <label for="user_id">User-ID (Authenticated User ID from users table):</label>
                    <div style="display: flex; gap: 10px; align-items: flex-start;">
                        <?php 
                        $users_options = array('' => '-- Select User --');
                        if (isset($users_list) && !empty($users_list)) {
                            $users_options = array_merge($users_options, $users_list);
                        }
                        echo form_dropdown('user_id', $users_options, '1', 'id="user_id" class="form-control" style="flex: 1;"');
                        ?>
                        <button type="button" id="fetchStudentIdBtn" class="btn" style="padding: 10px 15px; white-space: nowrap; background: #28a745;">
                            Get Student ID
                        </button>
                    </div>
                    <small style="color: #666; font-size: 12px; display: block; margin-top: 5px;">
                        Select a user from dropdown (only users with student data are shown). Click "Get Student ID" to auto-fill student_id in request body.
                    </small>
                </div>
            </div>
            
            <div class="form-group">
                <label for="content_type">Content-Type:</label>
                <?php echo form_input(array(
                    'type' => 'text',
                    'id' => 'content_type',
                    'name' => 'content_type',
                    'value' => 'application/json',
                    'placeholder' => 'Content type'
                )); ?>
            </div>
        </div>
        
        <!-- Student Details & Fees Section -->
        <div class="section" id="studentDetailsSection">
            <div class="section-title" style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <span>👤</span>
                    Student Details & Fees
                </div>
                <button type="button" id="loadStudentDetailsBtn" class="btn" style="padding: 8px 15px; background: #17a2b8; font-size: 13px; width: auto;">
                    Load Details
                </button>
            </div>
            
            <div id="studentDetailsContent">
                <div style="text-align: center; padding: 20px; color: #666;">
                    Click "Load Details" to view student information and fees
                </div>
            </div>
        </div>
        
        <!-- Body Section -->
        <div class="section">
            <div class="section-title">
                <span>📝</span>
                Body (JSON)
            </div>
            
            <div class="form-group">
                <label for="post_body">Request Body:</label>
                <?php 
                echo form_textarea(array(
                    'id' => 'post_body',
                    'name' => 'post_body',
                    'value' => '',
                    'placeholder' => 'Enter JSON request body or it will be auto-generated when you enter payment amounts',
                    'rows' => '10'
                )); ?>
            </div>
        </div>
        
        <!-- Submit Button -->
        <div style="text-align: center; margin-top: 20px;">
            <button type="submit" class="btn" id="submitBtn">Send Request</button>
            <button type="button" class="btn" id="loadingBtn" style="display:none; background:#999;" disabled>Loading...</button>
        </div>
        
        </form>
        
        <!-- Response Section -->
        <div class="response-section" id="responseSection" style="display:none;">
            <div class="section-title">
                <span>📥</span>
                Response
            </div>
            
            <div id="errorBox" style="display:none;"></div>
            
            <div class="response-header" id="responseHeader" style="display:none;">
                <div class="response-info">
                    <div>
                        Status: <span id="statusCode"></span>
                    </div>
                    <div>
                        Time: <span id="responseTime"></span>
                    </div>
                </div>
            </div>
            
            <div class="response-box" id="responseBox" style="display:none;"></div>
            
            <!-- Redirect Button -->
            <div id="redirectButtonContainer" style="display:none; margin-top: 15px; text-align: center;">
                <button id="redirectButton" class="btn" style="background: #28a745; padding: 12px 30px; font-size: 16px;">
                    🔗 Open Payment Page
                </button>
            </div>
        </div>
    </div>
    
    <script>
        // Helper function to normalize redirect URL - fix double slashes, escaped slashes, and ensure proper protocol
        function normalizeRedirectUrl(url) {
            if (!url) return '';
            
            // First, replace escaped slashes (\/) with regular slashes (/)
            url = url.replace(/\\\//g, '/');
            
            // Remove double slashes (except after protocol like http:// or https://)
            // This regex replaces multiple slashes with single slash, but keeps http:// or https://
            url = url.replace(/([^:]\/)\/+/g, '$1');
            
            // If URL doesn't start with http:// or https://, add it
            if (!url.match(/^https?:\/\//)) {
                // If it starts with //, add http:
                if (url.startsWith('//')) {
                    url = 'http:' + url;
                } else if (url.startsWith('/')) {
                    // Relative URL - construct from current location
                    var currentProtocol = window.location.protocol;
                    var currentHost = window.location.host;
                    url = currentProtocol + '//' + currentHost + url;
                } else {
                    // Assume it's a full URL missing protocol
                    url = 'http://' + url;
                }
            }
            
            return url;
        }
        
        // Auto-format JSON on paste
        document.getElementById('post_body').addEventListener('paste', function(e) {
            setTimeout(function() {
                var textarea = e.target;
                try {
                    var json = JSON.parse(textarea.value);
                    textarea.value = JSON.stringify(json, null, 2);
                } catch(err) {
                    // Not valid JSON, leave as is
                }
            }, 10);
        });

        // Auto-update student_id when user selects from dropdown
        var userDropdown = document.getElementById('user_id');
        if (userDropdown) {
            userDropdown.addEventListener('change', function() {
                var userId = this.value;
                if (userId) {
                    // Automatically get student_id and update request body
                    var xhr = new XMLHttpRequest();
                    xhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', true);
                    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    
                    xhr.onload = function() {
                        if (xhr.status === 200) {
                            try {
                                var result = JSON.parse(xhr.responseText);
                                if (result.success && result.student_id) {
                                    // Update student_id in request body
                                    var postBody = document.getElementById('post_body');
                                    try {
                                        var jsonData = JSON.parse(postBody.value);
                                        jsonData.student_id = result.student_id;
                                        postBody.value = JSON.stringify(jsonData, null, 2);
                                    } catch(err) {
                                        // Not valid JSON, create new
                                        var newJson = {
                                            "student_fees_master_id": "1",
                                            "fee_groups_feetype_id": "1",
                                            "student_id": result.student_id,
                                            "student_transport_fee_id": "",
                                            "fee_discount_group": "[{0:2}]"
                                        };
                                        postBody.value = JSON.stringify(newJson, null, 2);
                                    }
                                } else {
                                    console.log('Student ID not found for User-ID:', userId);
                                }
                            } catch(err) {
                                console.log('Error updating student_id:', err);
                            }
                        }
                    };
                    
                    xhr.onerror = function() {
                        console.log('Network error while fetching student_id');
                    };
                    
                    xhr.send('user_id=' + encodeURIComponent(userId));
                }
            });
        }

        // Fetch Student ID from User ID
        var fetchStudentIdBtn = document.getElementById('fetchStudentIdBtn');
        if (fetchStudentIdBtn) {
            fetchStudentIdBtn.addEventListener('click', function() {
                var userId = document.getElementById('user_id').value;
                if (!userId) {
                    alert('Please select User-ID from dropdown first');
                    return;
                }

                var btn = this;
                var originalText = btn.textContent;
                btn.textContent = 'Loading...';
                btn.disabled = true;

                // Make AJAX call to get student_id
                var xhr = new XMLHttpRequest();
                xhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', true);
                xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                
                xhr.onload = function() {
                    btn.textContent = originalText;
                    btn.disabled = false;
                    
                    if (xhr.status === 200) {
                        try {
                            var result = JSON.parse(xhr.responseText);
                            if (result.success && result.student_id) {
                                // Update student_id in request body
                                var postBody = document.getElementById('post_body');
                                try {
                                    var jsonData = JSON.parse(postBody.value);
                                    jsonData.student_id = result.student_id;
                                    postBody.value = JSON.stringify(jsonData, null, 2);
                                    alert('Student ID ' + result.student_id + ' has been auto-filled in request body!');
                                } catch(err) {
                                    alert('Could not update request body. Please ensure it contains valid JSON.');
                                }
                            } else {
                                alert(result.message || 'Student ID not found for this User-ID');
                            }
                        } catch(err) {
                            alert('Error parsing response: ' + err.message);
                        }
                    } else {
                        alert('Error: Server returned status ' + xhr.status);
                    }
                };
                
                xhr.onerror = function() {
                    btn.textContent = originalText;
                    btn.disabled = false;
                    alert('Network error. Please try again.');
                };
                
                xhr.ontimeout = function() {
                    btn.textContent = originalText;
                    btn.disabled = false;
                    alert('Request timeout. Please try again.');
                };
                
                xhr.timeout = 10000; // 10 seconds timeout
                xhr.send('user_id=' + encodeURIComponent(userId));
            });
        }

        // Load Student Details & Fees
        if (document.getElementById('loadStudentDetailsBtn')) {
            document.getElementById('loadStudentDetailsBtn').addEventListener('click', function() {
                var userId = document.getElementById('user_id').value;
                var postBody = document.getElementById('post_body').value;
                var studentId = '';
                
                // Try to get student_id from request body
                try {
                    var jsonData = JSON.parse(postBody);
                    studentId = jsonData.student_id || '';
                } catch(err) {
                    // Not valid JSON
                }
                
                // If no student_id but have user_id, get student_id first
                if (!studentId && userId) {
                    // First get student_id from user_id
                    var getStudentXhr = new XMLHttpRequest();
                    getStudentXhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', false); // Synchronous
                    getStudentXhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    getStudentXhr.send('user_id=' + encodeURIComponent(userId));
                    
                    if (getStudentXhr.status === 200) {
                        try {
                            var result = JSON.parse(getStudentXhr.responseText);
                            if (result.success && result.student_id) {
                                studentId = result.student_id;
                                // Also update request body
                                try {
                                    var jsonData = JSON.parse(postBody);
                                    jsonData.student_id = studentId;
                                    document.getElementById('post_body').value = JSON.stringify(jsonData, null, 2);
                                } catch(err) {
                                    // Ignore
                                }
                            }
                        } catch(err) {
                            // Ignore
                        }
                    }
                }
                
                if (!userId && !studentId) {
                    alert('Please select User-ID from dropdown or ensure student_id is in request body');
                    return;
                }

                var btn = this;
                var section = document.getElementById('studentDetailsSection');
                var content = document.getElementById('studentDetailsContent');
                var originalText = btn.textContent;
                
                btn.textContent = 'Loading...';
                btn.disabled = true;
                section.style.display = 'block';
                content.innerHTML = '<div class="loading-spinner">Loading student details...</div>';

                // Make AJAX call
                var xhr = new XMLHttpRequest();
                xhr.open('POST', '<?php echo base_url("payment_request/get_student_details"); ?>', true);
                xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                
                xhr.onload = function() {
                    btn.textContent = originalText;
                    btn.disabled = false;
                    
                    if (xhr.status === 200) {
                        try {
                            var result = JSON.parse(xhr.responseText);
                            // Debug: Check available_discounts
                            console.log('Available discounts:', result.available_discounts);
                            if (result.success) {
                                // Display student details
                                var html = '<div class="student-info-grid">';
                                html += '<div class="info-card"><label>Student ID</label><div class="value">' + result.student.id + '</div></div>';
                                html += '<div class="info-card"><label>Admission No</label><div class="value">' + (result.student.admission_no || 'N/A') + '</div></div>';
                                html += '<div class="info-card"><label>Name</label><div class="value">' + result.student.name + '</div></div>';
                                html += '<div class="info-card"><label>Class</label><div class="value">' + result.student.class + '</div></div>';
                                html += '<div class="info-card"><label>Section</label><div class="value">' + result.student.section + '</div></div>';
                                html += '<div class="info-card"><label>Email</label><div class="value">' + (result.student.email || 'N/A') + '</div></div>';
                                html += '<div class="info-card"><label>Mobile</label><div class="value">' + (result.student.mobileno || 'N/A') + '</div></div>';
                                html += '<div class="info-card"><label>Guardian</label><div class="value">' + (result.student.guardian_name || 'N/A') + '</div></div>';
                                html += '</div>';
                                
                                // Display fees grouped by session (similar to getfees.php)
                                if (result.fees && result.fees.length > 0) {
                                    html += '<h3 style="margin-top: 20px; margin-bottom: 15px; color: #333; border-bottom: 2px solid #007bff; padding-bottom: 8px;">💰 Fees Details</h3>';
                                    
                                    result.fees.forEach(function(session) {
                                        html += '<div style="margin-bottom: 30px; border: 1px solid #dee2e6; border-radius: 6px; overflow: hidden;">';
                                        html += '<div style="background: #007bff; color: white; padding: 12px 15px; font-weight: bold; font-size: 16px;">';
                                        html += '📅 Session: ' + (session.session_name || 'Unknown Session');
                                        html += '</div>';
                                        
                                        if (session.fee_groups && session.fee_groups.length > 0) {
                                            session.fee_groups.forEach(function(feeGroup) {
                                                html += '<div style="padding: 15px; background: #f8f9fa; border-bottom: 1px solid #dee2e6;">';
                                                html += '<h4 style="margin: 0 0 15px 0; color: #495057; font-size: 14px; font-weight: 600;">📋 ' + (feeGroup.fee_group_name || 'Fee Group') + '</h4>';
                                                
                                                if (feeGroup.fees && feeGroup.fees.length > 0) {
                                                    html += '<div style="overflow-x: auto;">';
                                                    html += '<table class="fees-table" style="margin-bottom: 0;">';
                                                    html += '<thead><tr>';
                                                    html += '<th>Fee Type</th>';
                                                    html += '<th>Due Date</th>';
                                                    html += '<th>Status</th>';
                                                    html += '<th>Amount</th>';
                                                    html += '<th>Payment ID</th>';
                                                    html += '<th>Mode</th>';
                                                    html += '<th>Date</th>';
                                                    html += '<th>Discount</th>';
                                                    html += '<th>Fine</th>';
                                                    html += '<th>Paid</th>';
                                                    html += '<th>Balance</th>';
                                                    html += '<th>Discount Select</th>';
                                                    html += '<th>Pay Amount</th>';
                                                    html += '</tr></thead>';
                                                    html += '<tbody>';
                                                    
                                                    var groupTotalAmount = 0;
                                                    var groupTotalDiscount = 0;
                                                    var groupTotalFine = 0;
                                                    var groupTotalPaid = 0;
                                                    var groupTotalBalance = 0;
                                                    
                                                    feeGroup.fees.forEach(function(fee, feeIndex) {
                                                        groupTotalAmount += parseFloat(fee.amount || 0);
                                                        groupTotalDiscount += parseFloat(fee.discount || 0);
                                                        groupTotalFine += parseFloat(fee.fine || 0);
                                                        groupTotalPaid += parseFloat(fee.paid || 0);
                                                        groupTotalBalance += parseFloat(fee.balance || 0);
                                                        var statusClass = 'status-' + fee.status;
                                                        var statusText = fee.status.charAt(0).toUpperCase() + fee.status.slice(1);
                                                        var statusColor = fee.status === 'paid' ? '#28a745' : (fee.status === 'partial' ? '#ffc107' : '#dc3545');
                                                        
                                                        // Main fee row
                                                        html += '<tr style="' + (fee.balance > 0 && fee.due_date && new Date(fee.due_date) < new Date() ? 'background: #fff5f5;' : '') + '">';
                                                        html += '<td><strong>' + (fee.fee_type_name || fee.fee_type_code || 'N/A') + ' (' + (fee.fee_type_code || 'N/A') + ')</strong></td>';
                                                        html += '<td>' + (fee.due_date ? new Date(fee.due_date).toLocaleDateString() : 'N/A') + '</td>';
                                                        html += '<td><span class="' + statusClass + '" style="padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; background: ' + statusColor + '; color: white;">' + statusText + '</span></td>';
                                                        html += '<td style="text-align: right;">₹' + parseFloat(fee.amount || 0).toFixed(2) + (fee.fine > 0 ? ' <span style="color: #dc3545;">+ ₹' + parseFloat(fee.fine || 0).toFixed(2) + '</span>' : '') + '</td>';
                                                        html += '<td>-</td>';
                                                        html += '<td>-</td>';
                                                        html += '<td>-</td>';
                                                        html += '<td style="text-align: right; color: #17a2b8;">₹' + parseFloat(fee.discount || 0).toFixed(2) + '</td>';
                                                        html += '<td style="text-align: right; color: #ffc107;">₹' + parseFloat(fee.fine || 0).toFixed(2) + '</td>';
                                                        html += '<td style="text-align: right; color: #28a745;">₹' + parseFloat(fee.paid || 0).toFixed(2) + '</td>';
                                                        html += '<td style="text-align: right; font-weight: bold;">₹' + parseFloat(fee.balance || 0).toFixed(2) + '</td>';
                                                        html += '<td>';
                                                        // Discount checkboxes
                                                        html += '<div class="discount-checkboxes" style="max-width: 200px; max-height: 150px; overflow-y: auto; padding: 5px; border: 1px solid #ddd; border-radius: 4px;" data-fee-id="' + fee.id + '" data-fee-groups-feetype-id="' + fee.fee_groups_feetype_id + '">';
                                                        if (result.available_discounts && result.available_discounts.length > 0) {
                                                            result.available_discounts.forEach(function(discount) {
                                                                var discountText = discount.name + ' (' + discount.code + ')';
                                                                if (discount.type === 'percentage' && discount.percentage) {
                                                                    discountText += ' - ' + discount.percentage + '%';
                                                                } else if (discount.amount) {
                                                                    discountText += ' - ₹' + parseFloat(discount.amount).toFixed(2);
                                                                }
                                                                html += '<label style="display: block; margin: 5px 0; font-size: 11px; cursor: pointer;">';
                                                                html += '<input type="checkbox" class="discount-checkbox" value="' + discount.id + '" data-amount="' + (discount.amount || 0) + '" data-percentage="' + (discount.percentage || 0) + '" data-type="' + (discount.type || 'fix') + '" data-name="' + discountText.replace(/"/g, '&quot;') + '" style="margin-right: 5px;">';
                                                                html += '<span>' + discountText + '</span>';
                                                                html += '</label>';
                                                            });
                                                        } else {
                                                            html += '<span style="font-size: 11px; color: #999;">No discounts available</span>';
                                                        }
                                                        html += '</div>';
                                                        html += '</td>';
                                                        html += '<td>';
                                                        // Pay amount textbox
                                                        if (fee.balance > 0) {
                                                            html += '<input type="number" class="pay-amount-input" step="0.01" min="0" max="' + fee.balance + '" placeholder="0.00" style="width: 100px; padding: 5px; font-size: 12px; text-align: right;" data-fee-id="' + fee.id + '" data-fee-group="' + (feeGroup.fee_group_name || '') + '" data-fee-type="' + (fee.fee_type_name || fee.fee_type_code || '') + '" data-balance="' + fee.balance + '" data-original-balance="' + fee.balance + '" data-student-fees-master-id="' + fee.student_fees_master_id + '" data-fee-groups-feetype-id="' + fee.fee_groups_feetype_id + '" data-amount="' + fee.amount + '">';
                                                        } else {
                                                            html += '<span style="color: #28a745; font-weight: 600;">Paid</span>';
                                                        }
                                                        html += '</td>';
                                                        html += '</tr>';
                                                        
                                                        // Payment history rows
                                                        if (fee.payment_history && fee.payment_history.length > 0) {
                                                            fee.payment_history.forEach(function(payment) {
                                                                html += '<tr style="background: #f8f9fa; font-size: 12px;">';
                                                                html += '<td colspan="3"></td>';
                                                                html += '<td></td>';
                                                                html += '<td>' + (payment.payment_id || 'N/A') + '</td>';
                                                                html += '<td>' + (payment.payment_mode || 'N/A') + '</td>';
                                                                html += '<td>' + (payment.date ? new Date(payment.date).toLocaleDateString() : 'N/A') + '</td>';
                                                                html += '<td style="text-align: right; color: #17a2b8;">₹' + parseFloat(payment.discount || 0).toFixed(2) + '</td>';
                                                                html += '<td style="text-align: right; color: #ffc107;">₹' + parseFloat(payment.fine || 0).toFixed(2) + '</td>';
                                                                html += '<td style="text-align: right; color: #28a745;">₹' + parseFloat(payment.amount || 0).toFixed(2) + '</td>';
                                                                html += '<td></td>';
                                                                html += '<td></td>';
                                                                html += '</tr>';
                                                            });
                                                        }
                                                    });
                                                    
                                                    // Add totals row
                                                    html += '<tfoot>';
                                                    html += '<tr style="background: #f8f9fa; font-weight: bold; border-top: 2px solid #dee2e6;">';
                                                    html += '<td colspan="3" style="text-align: right;"><strong>Total:</strong></td>';
                                                    html += '<td style="text-align: right;">₹' + groupTotalAmount.toFixed(2) + '</td>';
                                                    html += '<td colspan="3"></td>';
                                                    html += '<td style="text-align: right; color: #17a2b8;">₹' + groupTotalDiscount.toFixed(2) + '</td>';
                                                    html += '<td style="text-align: right; color: #ffc107;">₹' + groupTotalFine.toFixed(2) + '</td>';
                                                    html += '<td style="text-align: right; color: #28a745;">₹' + groupTotalPaid.toFixed(2) + '</td>';
                                                    html += '<td style="text-align: right; font-weight: bold;">₹' + groupTotalBalance.toFixed(2) + '</td>';
                                                    html += '<td></td>';
                                                    html += '<td>';
                                                    html += '<input type="number" class="total-pay-amount" step="0.01" min="0" max="' + groupTotalBalance + '" placeholder="Total Pay" style="width: 120px; padding: 5px; font-size: 12px; text-align: right; font-weight: bold; background: #e7f3ff;" data-group-balance="' + groupTotalBalance + '">';
                                                    html += '</td>';
                                                    html += '</tr>';
                                                    html += '</tfoot>';
                                                    
                                                    html += '</tbody></table>';
                                                    html += '</div>';
                                                }
                                                
                                                html += '</div>';
                                            });
                                        }
                                        
                                        html += '</div>';
                                    });
                                } else {
                                    html += '<div style="text-align: center; padding: 20px; color: #666; background: #f8f9fa; border-radius: 6px; margin-top: 15px;">';
                                    html += '<p style="margin: 0;">No fees records found for this student.</p>';
                                    html += '</div>';
                                }
                                
                                content.innerHTML = html;
                                
                                // Handle total pay amount - disburse across all rows in the group
                                var totalPayInputs = content.querySelectorAll('.total-pay-amount');
                                totalPayInputs.forEach(function(totalInput) {
                                    totalInput.addEventListener('input', function() {
                                        var totalPayAmount = parseFloat(this.value) || 0;
                                        var groupBalance = parseFloat(this.getAttribute('data-group-balance')) || 0;
                                        
                                        if (totalPayAmount > groupBalance) {
                                            this.value = groupBalance.toFixed(2);
                                            totalPayAmount = groupBalance;
                                        }
                                        
                                        // Get all pay inputs in this group
                                        var table = this.closest('table');
                                        var payInputs = table.querySelectorAll('.pay-amount-input');
                                        
                                        // If total is 0, clear all individual amounts
                                        if (totalPayAmount === 0) {
                                            payInputs.forEach(function(input) {
                                                input.value = '';
                                                input.dispatchEvent(new Event('input'));
                                            });
                                            return;
                                        }
                                        
                                        var totalBalance = 0;
                                        payInputs.forEach(function(input) {
                                            totalBalance += parseFloat(input.getAttribute('data-balance')) || 0;
                                        });
                                        
                                        // Disburse amount proportionally
                                        if (totalBalance > 0 && totalPayAmount > 0) {
                                            payInputs.forEach(function(input) {
                                                // Use original balance for disbursement calculation
                                                var originalBalance = parseFloat(input.getAttribute('data-original-balance')) || parseFloat(input.getAttribute('data-balance')) || 0;
                                                var proportion = originalBalance / totalBalance;
                                                var disbursedAmount = totalPayAmount * proportion;
                                                
                                                if (disbursedAmount > originalBalance) {
                                                    disbursedAmount = originalBalance;
                                                }
                                                
                                                input.value = disbursedAmount.toFixed(2);
                                                
                                                // Trigger change event to update UI
                                                input.dispatchEvent(new Event('input'));
                                            });
                                        }
                                    });
                                });
                                
                                // Handle individual pay amount inputs
                                var payInputs = content.querySelectorAll('.pay-amount-input');
                                payInputs.forEach(function(input) {
                                    input.addEventListener('input', function() {
                                        var payAmount = parseFloat(this.value) || 0;
                                        var originalBalance = parseFloat(this.getAttribute('data-balance')) || 0;
                                        
                                        // Get original balance from data attribute (store it if not already stored)
                                        if (!this.hasAttribute('data-original-balance')) {
                                            this.setAttribute('data-original-balance', originalBalance);
                                        }
                                        var originalBalanceStored = parseFloat(this.getAttribute('data-original-balance')) || originalBalance;
                                        
                                        if (payAmount > originalBalanceStored) {
                                            this.value = originalBalanceStored.toFixed(2);
                                            payAmount = originalBalanceStored;
                                        }
                                        
                                        // Update balance in UI
                                        var row = this.closest('tr');
                                        var balanceCell = row.querySelector('td:nth-last-child(3)');
                                        var newBalance = originalBalanceStored - payAmount;
                                        balanceCell.innerHTML = '₹' + newBalance.toFixed(2);
                                        this.setAttribute('data-balance', newBalance);
                                        
                                        // Update Paid amount
                                        var paidCell = row.querySelector('td:nth-last-child(4)');
                                        var originalAmount = parseFloat(this.getAttribute('data-amount')) || 0;
                                        var actualPaid = originalAmount - newBalance;
                                        paidCell.innerHTML = '<span style="color: #28a745;">₹' + actualPaid.toFixed(2) + '</span>';
                                        
                                        // Update status
                                        var statusCell = row.querySelector('td:nth-child(3)');
                                        if (newBalance <= 0) {
                                            statusCell.innerHTML = '<span class="status-paid" style="padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; background: #28a745; color: white;">Paid</span>';
                                            row.style.background = '#f0f9f0';
                                        } else if (payAmount > 0) {
                                            statusCell.innerHTML = '<span class="status-partial" style="padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; background: #ffc107; color: white;">Partial</span>';
                                        } else {
                                            // Reset to unpaid if amount is 0
                                            statusCell.innerHTML = '<span class="status-unpaid" style="padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; background: #dc3545; color: white;">Unpaid</span>';
                                            row.style.background = '';
                                        }
                                        
                                        // Update total pay amount in footer
                                        var table = this.closest('table');
                                        var totalPayInput = table.querySelector('.total-pay-amount');
                                        if (totalPayInput) {
                                            var totalPayAmount = 0;
                                            var allPayInputs = table.querySelectorAll('.pay-amount-input');
                                            allPayInputs.forEach(function(inp) {
                                                totalPayAmount += parseFloat(inp.value) || 0;
                                            });
                                            totalPayInput.value = totalPayAmount > 0 ? totalPayAmount.toFixed(2) : '';
                                        }
                                        
                                        // Update Request Body
                                        updateRequestBody();
                                    });
                                });
                                
                                // Handle discount checkbox selection using event delegation
                                content.addEventListener('change', function(e) {
                                    if (e.target && e.target.classList.contains('discount-checkbox')) {
                                        updateRequestBody();
                                    }
                                });
                                
                                // Function to update Request Body JSON - Reset every time, only payments
                                function updateRequestBody() {
                                    var postBody = document.getElementById('post_body');
                                    var studentId = '';
                                    
                                    // First try to get student_id from existing JSON body
                                    try {
                                        var existingJson = JSON.parse(postBody.value);
                                        // Check if it's the new format with payments array
                                        if (existingJson.payments && Array.isArray(existingJson.payments) && existingJson.payments.length > 0) {
                                            studentId = existingJson.payments[0].student_id || '';
                                        } else if (existingJson.student_id) {
                                            studentId = existingJson.student_id;
                                        }
                                    } catch(err) {
                                        // Not valid JSON or empty - will get from dropdown
                                    }
                                    
                                    // If not found in JSON, try to get from user dropdown
                                    if (!studentId) {
                                        var userIdDropdown = document.getElementById('user_id');
                                        if (userIdDropdown && userIdDropdown.value) {
                                            // Make synchronous call to get student_id
                                            var getStudentXhr = new XMLHttpRequest();
                                            getStudentXhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', false);
                                            getStudentXhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                                            getStudentXhr.send('user_id=' + encodeURIComponent(userIdDropdown.value));
                                            
                                            if (getStudentXhr.status === 200) {
                                                try {
                                                    var result = JSON.parse(getStudentXhr.responseText);
                                                    if (result.success && result.student_id) {
                                                        studentId = result.student_id;
                                                    }
                                                } catch(err) {
                                                    // Ignore
                                                }
                                            }
                                        }
                                    }
                                    
                                    try {
                                        // Only include payments array, no base structure
                                        var paymentsArray = [];
                                        
                                        // Get all pay inputs and discount selects
                                        var allPayInputs = content.querySelectorAll('.pay-amount-input');
                                        allPayInputs.forEach(function(input) {
                                            var payAmount = parseFloat(input.value) || 0;
                                            if (payAmount > 0) {
                                                var selectedDiscounts = [];
                                                var discountContainer = input.closest('tr').querySelector('.discount-checkboxes');
                                                if (discountContainer) {
                                                    var checkedBoxes = discountContainer.querySelectorAll('.discount-checkbox:checked');
                                                    checkedBoxes.forEach(function(checkbox) {
                                                        selectedDiscounts.push({
                                                            id: checkbox.value,
                                                            name: checkbox.getAttribute('data-name') || checkbox.value,
                                                            amount: parseFloat(checkbox.getAttribute('data-amount')) || 0,
                                                            percentage: parseFloat(checkbox.getAttribute('data-percentage')) || 0,
                                                            type: checkbox.getAttribute('data-type') || 'fix'
                                                        });
                                                    });
                                                }
                                                
                                                paymentsArray.push({
                                                    student_fees_master_id: input.getAttribute('data-student-fees-master-id'),
                                                    fee_groups_feetype_id: input.getAttribute('data-fee-groups-feetype-id'),
                                                    amount: payAmount,
                                                    student_id: studentId,
                                                    fee_type: input.getAttribute('data-fee-type'),
                                                    fee_group: input.getAttribute('data-fee-group'),
                                                    discounts: selectedDiscounts
                                                });
                                            }
                                        });
                                        
                                        // Always create clean JSON structure with payments array
                                        if (paymentsArray.length > 0) {
                                            var cleanJson = { payments: paymentsArray };
                                            postBody.value = JSON.stringify(cleanJson, null, 2);
                                        } else {
                                            // If no payments, set empty object with payments array
                                            postBody.value = JSON.stringify({ payments: [] }, null, 2);
                                        }
                                    } catch(err) {
                                        console.log('Error updating request body:', err);
                                        // On error, try to create a clean structure
                                        try {
                                            postBody.value = JSON.stringify({ payments: [] }, null, 2);
                                        } catch(e) {
                                            console.log('Could not reset JSON structure');
                                        }
                                    }
                                }
                            } else {
                                content.innerHTML = '<div class="error-box">' + result.message + '</div>';
                            }
                        } catch(err) {
                            content.innerHTML = '<div class="error-box">Error parsing response</div>';
                        }
                    } else {
                        content.innerHTML = '<div class="error-box">Error: Server returned status ' + xhr.status + '</div>';
                    }
                };
                
                xhr.onerror = function() {
                    btn.textContent = originalText;
                    btn.disabled = false;
                    content.innerHTML = '<div class="error-box">Network error. Please try again.</div>';
                };
                
                var params = 'user_id=' + encodeURIComponent(userId);
                if (studentId) {
                    params += '&student_id=' + encodeURIComponent(studentId);
                }
                xhr.send(params);
            });
        }

        // Preserve student_id when API URL changes
        var apiUrlInput = document.getElementById('api_url');
        if (apiUrlInput) {
            apiUrlInput.addEventListener('change', function() {
                // Preserve student_id in request body when URL changes
                var postBody = document.getElementById('post_body');
                var userIdDropdown = document.getElementById('user_id');
                var studentId = '';
                
                // Try to get student_id from existing JSON
                try {
                    var existingJson = JSON.parse(postBody.value);
                    if (existingJson.student_id) {
                        studentId = existingJson.student_id;
                    }
                } catch(err) {
                    // Not valid JSON or empty
                }
                
                // If not found, get from user dropdown
                if (!studentId && userIdDropdown && userIdDropdown.value) {
                    var getStudentXhr = new XMLHttpRequest();
                    getStudentXhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', false);
                    getStudentXhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    getStudentXhr.send('user_id=' + encodeURIComponent(userIdDropdown.value));
                    
                    if (getStudentXhr.status === 200) {
                        try {
                            var result = JSON.parse(getStudentXhr.responseText);
                            if (result.success && result.student_id) {
                                studentId = result.student_id;
                            }
                        } catch(err) {
                            // Ignore
                        }
                    }
                }
                
                // If we have student_id, preserve it in JSON (if JSON exists and has payments)
                if (studentId) {
                    try {
                        var currentJson = postBody.value.trim();
                        if (currentJson) {
                            var jsonData = JSON.parse(currentJson);
                            // Only update if it's the correct structure with payments array
                            if (jsonData.payments && Array.isArray(jsonData.payments)) {
                                jsonData.payments.forEach(function(payment) {
                                    payment.student_id = studentId;
                                });
                                // Create clean JSON structure
                                postBody.value = JSON.stringify({ payments: jsonData.payments }, null, 2);
                            } else {
                                // If structure is wrong, create clean structure
                                postBody.value = JSON.stringify({ payments: [] }, null, 2);
                            }
                        }
                    } catch(err) {
                        // If not valid JSON, create clean structure
                        try {
                            postBody.value = JSON.stringify({ payments: [] }, null, 2);
                        } catch(e) {
                            // Ignore
                        }
                    }
                }
            });
        }

        // AJAX Form Submission
        document.getElementById('apiForm').addEventListener('submit', function(e) {
            e.preventDefault();
            
            var submitBtn = document.getElementById('submitBtn');
            var loadingBtn = document.getElementById('loadingBtn');
            var responseSection = document.getElementById('responseSection');
            var errorBox = document.getElementById('errorBox');
            var responseHeader = document.getElementById('responseHeader');
            var responseBox = document.getElementById('responseBox');
            
            // Show loading
            submitBtn.style.display = 'none';
            loadingBtn.style.display = 'inline-block';
            responseSection.style.display = 'none';
            errorBox.style.display = 'none';
            responseHeader.style.display = 'none';
            responseBox.style.display = 'none';
            
            // Hide redirect button when starting new request
            document.getElementById('redirectButtonContainer').style.display = 'none';
            
            // Get form data
            var formData = new FormData(this);
            var postBodyValue = document.getElementById('post_body').value;
            
            // Ensure student_id is in request body if not present and validate JSON structure
            try {
                var jsonData = JSON.parse(postBodyValue);
                var userId = formData.get('user_id');
                var apiUrl = formData.get('api_url');
                var isFeesPayEndpoint = apiUrl && apiUrl.indexOf('fees_pay') !== -1;
                
                // If calling fees_pay endpoint, ensure payments array structure
                if (isFeesPayEndpoint) {
                    // Check if it's old format (without payments wrapper)
                    if (!jsonData.payments || !Array.isArray(jsonData.payments)) {
                        // Convert old format to new format
                        if (jsonData.student_fees_master_id || jsonData.fee_groups_feetype_id || jsonData.amount) {
                            // This is old format, convert to new
                            var paymentObj = {
                                student_fees_master_id: jsonData.student_fees_master_id || '',
                                fee_groups_feetype_id: jsonData.fee_groups_feetype_id || '',
                                amount: jsonData.amount || 0,
                                student_id: jsonData.student_id || '',
                                fee_type: jsonData.fee_type || '',
                                fee_group: jsonData.fee_group || '',
                                discounts: jsonData.discounts || []
                            };
                            jsonData = { payments: [paymentObj] };
                        } else {
                            // No valid data, create empty structure
                            jsonData = { payments: [] };
                        }
                    }
                }
                
                // Update student_id in payments array
                if (jsonData.payments && Array.isArray(jsonData.payments)) {
                    var studentId = '';
                    
                    // Try to get from existing payments
                    if (jsonData.payments.length > 0 && jsonData.payments[0].student_id) {
                        studentId = jsonData.payments[0].student_id;
                    }
                    
                    // If not found, get from user dropdown
                    if (!studentId && userId) {
                        var getStudentXhr = new XMLHttpRequest();
                        getStudentXhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', false);
                        getStudentXhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                        getStudentXhr.send('user_id=' + encodeURIComponent(userId));
                        
                        if (getStudentXhr.status === 200) {
                            try {
                                var result = JSON.parse(getStudentXhr.responseText);
                                if (result.success && result.student_id) {
                                    studentId = result.student_id;
                                }
                            } catch(err) {
                                // Ignore
                            }
                        }
                    }
                    
                    // Update all payments with student_id
                    if (studentId) {
                        jsonData.payments.forEach(function(payment) {
                            payment.student_id = studentId;
                        });
                    }
                    
                    // Create clean JSON structure
                    postBodyValue = JSON.stringify({ payments: jsonData.payments }, null, 2);
                    document.getElementById('post_body').value = postBodyValue;
                }
            } catch(err) {
                // If not valid JSON, create clean structure
                try {
                    var userId = formData.get('user_id');
                    var studentId = '';
                    
                    if (userId) {
                        var getStudentXhr = new XMLHttpRequest();
                        getStudentXhr.open('POST', '<?php echo base_url("payment_request/get_student_id"); ?>', false);
                        getStudentXhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                        getStudentXhr.send('user_id=' + encodeURIComponent(userId));
                        
                        if (getStudentXhr.status === 200) {
                            try {
                                var result = JSON.parse(getStudentXhr.responseText);
                                if (result.success && result.student_id) {
                                    studentId = result.student_id;
                                }
                            } catch(e) {
                                // Ignore
                            }
                        }
                    }
                    
                    postBodyValue = JSON.stringify({ payments: [] }, null, 2);
                    document.getElementById('post_body').value = postBodyValue;
                } catch(e) {
                    // Ignore
                }
            }
            
            formData.append('submit_api', '1');
            
            // Create AJAX request
            var xhr = new XMLHttpRequest();
            xhr.open('POST', '<?php echo base_url("payment_request/make_request"); ?>', true);
            
            xhr.onload = function() {
                submitBtn.style.display = 'inline-block';
                loadingBtn.style.display = 'none';
                responseSection.style.display = 'block';
                
                // Always try to parse and show response, regardless of HTTP status
                try {
                    var result = JSON.parse(xhr.responseText);
                    
                    if (result.success) {
                        // Show success response
                        errorBox.style.display = 'none';
                        responseHeader.style.display = 'block';
                        responseBox.style.display = 'block';
                        
                        // Update status code
                        var statusCode = document.getElementById('statusCode');
                        var statusColor = (result.http_code >= 200 && result.http_code < 300) ? '#3c3' : '#c33';
                        statusCode.textContent = result.http_code;
                        statusCode.style.color = statusColor;
                        
                        // Update response time
                        document.getElementById('responseTime').textContent = result.response_time + ' ms';
                        
                        // Format and display response as JSON
                        if (result.response) {
                            try {
                                var jsonResponse = JSON.parse(result.response);
                                var formattedJson = JSON.stringify(jsonResponse, null, 2);
                                
                                // Extract redirect_url from response - try multiple locations
                                var redirectUrl = result.redirect_url || jsonResponse.redirect_url || '';
                                
                                // Also try to extract from nested response if it's a string
                                if (!redirectUrl && jsonResponse.response) {
                                    try {
                                        var nestedResponse = typeof jsonResponse.response === 'string' ? JSON.parse(jsonResponse.response) : jsonResponse.response;
                                        redirectUrl = nestedResponse.redirect_url || '';
                                        
                                        // If still not found, try parsing the nested response as string again (for double-nested JSON)
                                        if (!redirectUrl && typeof nestedResponse === 'object' && nestedResponse.response) {
                                            try {
                                                var doubleNested = typeof nestedResponse.response === 'string' ? JSON.parse(nestedResponse.response) : nestedResponse.response;
                                                redirectUrl = doubleNested.redirect_url || '';
                                            } catch(e) {
                                                // Ignore
                                            }
                                        }
                                    } catch(e) {
                                        // If parsing fails, try regex extraction from the string
                                        if (typeof jsonResponse.response === 'string') {
                                            var urlMatch = jsonResponse.response.match(/"redirect_url"\s*:\s*"([^"\\]*(\\.[^"\\]*)*)"/);
                                            if (urlMatch && urlMatch[1]) {
                                                redirectUrl = urlMatch[1].replace(/\\\//g, '/').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                                            }
                                        }
                                    }
                                }
                                
                                // Also try to search in the entire JSON string if still not found
                                if (!redirectUrl) {
                                    try {
                                        var jsonString = JSON.stringify(jsonResponse);
                                        var urlMatch = jsonString.match(/"redirect_url"\s*:\s*"([^"\\]*(\\.[^"\\]*)*)"/);
                                        if (urlMatch && urlMatch[1]) {
                                            // Unescape the matched URL
                                            redirectUrl = urlMatch[1].replace(/\\\//g, '/').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                                        }
                                    } catch(e) {
                                        // Ignore
                                    }
                                }
                                
                                // Normalize redirect URL (handles escaped slashes, double slashes, etc.)
                                redirectUrl = normalizeRedirectUrl(redirectUrl);
                                
                                var htmlContent = '';
                                
                                // If redirect_url is available, show it prominently with copy button
                                if (redirectUrl) {
                                    htmlContent += '<div style="background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; padding: 15px; margin-bottom: 15px;">';
                                    htmlContent += '<strong style="color: #155724; display: block; margin-bottom: 10px;">✅ Redirect URL (Click to copy or open):</strong>';
                                    htmlContent += '<div style="display: flex; align-items: center; gap: 10px; background: white; padding: 10px; border-radius: 4px; border: 1px solid #c3e6cb;">';
                                    htmlContent += '<input type="text" id="redirectUrlInput" value="' + redirectUrl + '" readonly style="flex: 1; padding: 8px; border: 1px solid #ddd; border-radius: 4px; font-family: monospace; font-size: 13px; background: #f8f9fa;" onclick="this.select();">';
                                    htmlContent += '<button onclick="navigator.clipboard.writeText(\'' + redirectUrl + '\').then(() => alert(\'URL copied!\')).catch(() => {var copyText = document.getElementById(\'redirectUrlInput\'); copyText.select(); document.execCommand(\'copy\'); alert(\'URL copied!\');});" style="padding: 8px 15px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: bold;">📋 Copy</button>';
                                    htmlContent += '<a href="' + redirectUrl + '" target="_blank" style="padding: 8px 15px; background: #007bff; color: white; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">🔗 Open</a>';
                                    htmlContent += '</div>';
                                    htmlContent += '</div>';
                                }
                                
                                // Display formatted JSON
                                htmlContent += '<pre style="margin: 0; white-space: pre-wrap; font-family: monospace; background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto; font-size: 13px; line-height: 1.5;">' + formattedJson + '</pre>';
                                
                                responseBox.innerHTML = htmlContent;
                                
                                // Show/hide redirect button
                                var redirectButtonContainer = document.getElementById('redirectButtonContainer');
                                var redirectButton = document.getElementById('redirectButton');
                                if (redirectUrl) {
                                    redirectButtonContainer.style.display = 'block';
                                    redirectButton.onclick = function() {
                                        window.open(redirectUrl, '_blank');
                                    };
                                } else {
                                    redirectButtonContainer.style.display = 'none';
                                }
                            } catch(err) {
                                // If not valid JSON, try to display as is
                                responseBox.innerHTML = '<pre style="margin: 0; white-space: pre-wrap; font-family: monospace; background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto;">' + result.response + '</pre>';
                                
                                // Try to extract redirect_url from raw response string
                                // Use a more robust regex that handles escaped characters
                                var redirectUrlMatch = result.response.match(/"redirect_url"\s*:\s*"((?:[^"\\]|\\.)*)"/);
                                var redirectUrl = redirectUrlMatch ? redirectUrlMatch[1] : '';
                                
                                // Unescape the URL (handle escaped slashes, quotes, etc.)
                                if (redirectUrl) {
                                    redirectUrl = redirectUrl.replace(/\\\//g, '/').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                                }
                                
                                // Normalize redirect URL
                                redirectUrl = normalizeRedirectUrl(redirectUrl);
                                
                                // Show/hide redirect button
                                var redirectButtonContainer = document.getElementById('redirectButtonContainer');
                                var redirectButton = document.getElementById('redirectButton');
                                if (redirectUrl) {
                                    redirectButtonContainer.style.display = 'block';
                                    redirectButton.onclick = function() {
                                        window.open(redirectUrl, '_blank');
                                    };
                                } else {
                                    redirectButtonContainer.style.display = 'none';
                                }
                            }
                        } else if (result.redirect_url) {
                            // If only redirect_url is available
                            var redirectUrl = normalizeRedirectUrl(result.redirect_url);
                            responseBox.innerHTML = '<div style="background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; padding: 15px;"><strong style="color: #155724; display: block; margin-bottom: 10px;">✅ Redirect URL:</strong><div style="display: flex; align-items: center; gap: 10px; background: white; padding: 10px; border-radius: 4px;"><input type="text" value="' + redirectUrl + '" readonly style="flex: 1; padding: 8px; border: 1px solid #ddd; border-radius: 4px; font-family: monospace;" onclick="this.select();"><button onclick="navigator.clipboard.writeText(\'' + redirectUrl + '\').then(() => alert(\'URL copied!\')).catch(() => {var copyText = event.target.previousElementSibling; copyText.select(); document.execCommand(\'copy\'); alert(\'URL copied!\');});" style="padding: 8px 15px; background: #28a745; color: white; border: none; border-radius: 4px; cursor: pointer;">📋 Copy</button><a href="' + redirectUrl + '" target="_blank" style="padding: 8px 15px; background: #007bff; color: white; text-decoration: none; border-radius: 4px;">🔗 Open</a></div></div>';
                            
                            // Show redirect button
                            var redirectButtonContainer = document.getElementById('redirectButtonContainer');
                            var redirectButton = document.getElementById('redirectButton');
                            redirectButtonContainer.style.display = 'block';
                            redirectButton.onclick = function() {
                                window.open(redirectUrl, '_blank');
                            };
                        } else {
                            responseBox.innerHTML = '<pre style="margin: 0; font-family: monospace; color: #999;">(Empty response)</pre>';
                            
                            // Hide redirect button
                            document.getElementById('redirectButtonContainer').style.display = 'none';
                        }
                    } else {
                        // Show error from API
                        errorBox.style.display = 'block';
                        errorBox.className = 'error-box';
                        errorBox.innerHTML = '<strong>Error:</strong> ' + (result.error || 'Unknown error');
                        responseHeader.style.display = 'none';
                        responseBox.style.display = 'none';
                        
                        // Hide redirect button on error
                        document.getElementById('redirectButtonContainer').style.display = 'none';
                    }
                } catch(err) {
                    // If JSON parsing fails, show raw response
                    responseHeader.style.display = 'block';
                    responseBox.style.display = 'block';
                    errorBox.style.display = 'none';
                    
                    // Update status code
                    var statusCode = document.getElementById('statusCode');
                    var statusColor = (xhr.status >= 200 && xhr.status < 300) ? '#3c3' : '#c33';
                    statusCode.textContent = xhr.status;
                    statusCode.style.color = statusColor;
                    
                    // Show raw response
                    var rawResponse = xhr.responseText || '(No response body)';
                    responseBox.textContent = rawResponse;
                    
                    // Try to extract redirect_url from raw response
                    // Use a more robust regex that handles escaped characters
                    var redirectUrlMatch = rawResponse.match(/"redirect_url"\s*:\s*"((?:[^"\\]|\\.)*)"/);
                    var redirectUrl = redirectUrlMatch ? redirectUrlMatch[1] : '';
                    
                    // Unescape the URL (handle escaped slashes, quotes, etc.)
                    if (redirectUrl) {
                        redirectUrl = redirectUrl.replace(/\\\//g, '/').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                    }
                    
                    // Normalize redirect URL
                    redirectUrl = normalizeRedirectUrl(redirectUrl);
                    
                    // Show/hide redirect button
                    var redirectButtonContainer = document.getElementById('redirectButtonContainer');
                    var redirectButton = document.getElementById('redirectButton');
                    if (redirectUrl) {
                        redirectButtonContainer.style.display = 'block';
                        redirectButton.onclick = function() {
                            window.open(redirectUrl, '_blank');
                        };
                    } else {
                        redirectButtonContainer.style.display = 'none';
                    }
                    
                    // Also show error if status is not 200
                    if (xhr.status !== 200) {
                        errorBox.style.display = 'block';
                        errorBox.className = 'error-box';
                        errorBox.innerHTML = '<strong>HTTP Error:</strong> Server returned status ' + xhr.status;
                    }
                }
            };
            
            xhr.onerror = function() {
                submitBtn.style.display = 'inline-block';
                loadingBtn.style.display = 'none';
                responseSection.style.display = 'block';
                errorBox.style.display = 'block';
                errorBox.className = 'error-box';
                errorBox.innerHTML = '<strong>Error:</strong> Network error. Please check your connection.';
                
                // Hide redirect button on network error
                document.getElementById('redirectButtonContainer').style.display = 'none';
            };
            
            xhr.send(formData);
        });
    </script>
</body>
</html>

