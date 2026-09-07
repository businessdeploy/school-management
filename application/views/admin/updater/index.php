<div class="content-wrapper">
    <!-- Main content -->
    <section class="content">
        <div class="row">
            <div class="col-md-12">
                <div class="box box-primary">
                    <div class="box-header ptbnull">
                        <h3 class="box-title titlefix"><?php echo $this->lang->line('system_update') ?></h3>
                        <div class="box-tools pull-right"></div>
                    </div>
                    <div class="box-body">
                        <div class="row text-center">
                            <div class="col-md-6 col-md-offset-3">
                                <div class="alert alert-success" style="border-radius: 8px; padding: 20px; margin-bottom: 25px;">
                                    <h3 style="margin-top: 0; font-weight: 700; color: #155724;">
                                        <i class="fa fa-check-circle"></i> Prime School Enterprise
                                    </h3>
                                    <p class="versionup" style="font-size: 16px; margin: 10px 0;">
                                        <?php echo $this->lang->line('your_app_name_version'); ?>: 
                                        <strong><?php echo $this->customlib->getAppVersion(); ?> (LTS)</strong>
                                    </p>
                                    <div style="font-size: 13px; color: #155724; opacity: 0.9;">
                                        Provided & Managed by <strong>Primeskill Solutions Private Limited</strong>
                                    </div>
                                </div>
                            </div>
                            <div class="clearfix"></div>

                            <?php if ($this->session->flashdata('message')) { ?>
                                <div class="col-md-8 col-md-offset-2">
                                    <div class="text-success">
                                        <ul class="update-list" style="list-style: none; padding: 0;">
                                            <?php foreach ($this->session->flashdata('message') as $message_key => $message_value) { ?>
                                                <li><h5><i class="fa fa-info-circle"></i> <?php echo $message_value; ?></h5></li>
                                            <?php } ?>
                                        </ul>
                                    </div>
                                </div>  
                            <?php } ?>

                            <div class="col-md-8 col-md-offset-2">
                                <div class="callout callout-info text-left" style="background-color: #f0f7fd !important; border-left-color: #3182ce; color: #2b6cb0; border-radius: 4px; margin-top: 10px;">
                                    <h4><i class="fa fa-shield"></i> Centralized Fleet Management Active</h4>
                                    <p style="font-size: 13px; margin-bottom: 0;">
                                        Your Prime School instance is connected to the high-availability multi-tenant cloud fleet. Updates, database migrations, and security patches are deployed automatically and seamlessly through the Primeskill Solutions Fleet Control Plane without interruption to school operations.
                                    </p>
                                </div>
                            </div>
                        </div><!--./row-->
                    </div><!-- /.box-body -->
                </div>
            </div><!--/.col (left) -->
        </div>
        
        <div class="row">             
            <div class="col-md-12">
                <div class="box box-primary">
                    <div class="box-header ptbnull">
                        <h3 class="box-title titlefix">Hosting Server PHP Information</h3>
                        <div class="box-tools pull-right"></div>
                    </div>
                    <div class="box-body">
                        <div class="row">
                            <div class="col-md-12 font15" id="btnhide">
                                <a href="#" class="displayinline align-text-top font-weight-bold showinfo"><?php echo $this->lang->line('show') ?></a>    
                            </div>
                            
                            <div class="col-md-12 hide" id="showinfo">
                                <div class="table-responsive">
                                    <?php $this->load->view('admin/updater/qdtest'); ?> 
                                </div>                   
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section><!-- /.content -->
</div>

<script type="text/javascript">
    $('.showinfo').on('click', function (e) {
        e.preventDefault();
        $('#showinfo').removeClass('hide');
        $('#btnhide').addClass('hide');
    });
</script>