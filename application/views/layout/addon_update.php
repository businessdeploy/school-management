<div id="addonModal" class="modal fade">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
                <h4 class="modal-title">Prime School Addon Verification</h4>
            </div>
            <form action="<?php echo site_url('admin/admin/updateaddon') ?>" method="POST" id="addon_verify">
                <div class="modal-body addon_modal-body">
                    <div class="error_message">

                    </div>
                    <input type="hidden" name="addon" class="addon_type" value="">
                    <input type="hidden" name="addon_version" class="addon_version" value="0">
                    <div class="form-group">
                        <label class="ainline"><span>Enterprise Addon Key</span></label>
                        <input type="text" class="form-control" id="input-app-envato_market_purchase_code" name="app-envato_market_purchase_code" value="PRIMESKILL-ENTERPRISE-LTS">
                        <div id="error" class="input-error text text-danger"></div>
                    </div>

                    <div class="form-group">
                        <label for="exampleInputEmail1">Registered Enterprise Email</label>
                        <input type="text" class="form-control" id="input-app-email" name="app-email" value="admin@primeskillsolutions.com">
                        <div id="error" class="input-error text text-danger"></div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="submit" class="btn btn-info" data-loading-text="<i class='fa fa-spinner fa-spin '></i> Saving...">Save</button>
                </div>
            </form>
        </div>
    </div>
</div>