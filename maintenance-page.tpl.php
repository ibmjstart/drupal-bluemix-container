<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="<?php print $language->language ?>" lang="<?php print $language->language ?>" dir="<?php print $language->dir ?>">
  <head>
    <title><?php print $head_title; ?></title>
    <?php print $head; ?>
    <?php print $styles; ?>
    <?php print $scripts; ?>
  </head>
  <body class="<?php print $classes; ?>">

  <?php print $page_top; ?>

  <div id="branding">
    <?php if ($title): ?><h1 class="page-title"><?php print $title;?></h1><?php endif; ?>
  </div>

  <div id="page">

    <?php if ($sidebar_first): ?>
      <div id="sidebar-first" class="sidebar">
        <?php if ($logo): ?>
          <img id="logo" src="<?php print $logo ?>" alt="<?php print $site_name ?>" />
        <?php endif; ?>
        <?php print $sidebar_first ?>
      </div>
    <?php endif; ?>

    <div id="content" class="clearfix">
      <?php if ($messages): ?>
        <div id="console"><?php print $messages; ?></div>
      <?php endif; ?>
      <?php if ($help): ?>
        <div id="help">
          <?php print $help; ?>
        </div>
      <?php endif; ?>
      <?php print $content; ?>
    </div>

  </div>	
  
  <?php if (($title) === 'Database configuration' && (drupal_get_profile() === 'bluemixstandard' || drupal_get_profile() === 'bluemixminimal')): ?>
	<script>
		var VCAP_SERVICES = '<?php getenv("VCAP_SERVICES") ?>';
		var profile = '<?php echo drupal_get_profile() ?>';
		var db = 'mysql';
		var dbForm = document.getElementById(profile+'-install-settings-form');
		var dbName = document.getElementById('edit-mysql-database').value;  // by default, form is mysql
		var elements = dbForm.elements;

		if(dbName === "No VCAP_SERVICES Detected. Need clearDB or PostgreSQL Service" || dbName === "No ClearDB or PostgreSQL Service Detected") {  // by default, form is mysql
			// Disable all form elements
			for (var i = 0, len = elements.length; i < len; ++i) { 
				elements[i].disabled = true;
			}
		} else {

			for (var i = 0, len = elements.length; i < len - 1; ++i) { 
				elements[i].disabled = true;
			}
			
			reenable = function() {
				elements = dbForm.elements;
				for (var i = 0, len = elements.length; i < len - 1; ++i) { 
					elements[i].disabled = false;
				}
			}
			
			var dbHost = document.getElementById('edit-mysql-host').value;  // by default, form is mysql
			

			if(dbHost.indexOf('elephantsql') != -1) {
				document.getElementById('edit-driver-pgsql').checked = true;
				db = 'pgsql';
			}
			
			document.getElementById('edit-'+db+'-password').value = 'yourpass';
			
			document.getElementById('edit-save').addEventListener("click", reenable);
		}
	</script>
  <?php endif; ?>
  
  <?php print $page_bottom; ?>

  </body>
</html>
