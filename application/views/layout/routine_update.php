<div id="activelicmodal" class="modal fade">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
                <h4 class="modal-title">Prime School Enterprise License</h4>
            </div>
            <form action="<?php echo site_url('admin/admin/updatePurchaseCode') ?>" method="POST" id="purchase_code">
                <div class="modal-body lic_modal-body">
                    <div class="form-group">
                        <div class="req"><b>Enterprise Notice:</b> Your Prime School platform is deployed under Primeskill Solutions Private Limited Multi-Tenant Enterprise License.</div>
                    </div>
                    <div class="error_message">

                    </div>
                    <div class="form-group">
                        <label class="ainline"><span>Enterprise License Key</span></label>
                        <input type="text" class="form-control" id="input-envato_market_purchase_code" name="envato_market_purchase_code" value="PRIMESKILL-ENTERPRISE-LTS">
                        <div id="error" class="text text-danger"></div>
                    </div>

                    <div class="form-group">
                        <label for="exampleInputEmail1">Registered Enterprise Email</label>
                        <input type="text" class="form-control" id="input-email" name="email" value="admin@primeskillsolutions.com">
                        <div id="error" class="text text-danger"></div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="submit" class="btn btn-success" data-loading-text="<i class='fa fa-spinner fa-spin '></i> Saving...">Save</button>
                </div>
            </form>
        </div>
    </div>
</div>
