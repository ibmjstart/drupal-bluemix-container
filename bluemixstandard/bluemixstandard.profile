<?php

function bluemixstandard_install() {
  include_once DRUPAL_ROOT . '/profiles/standard/standard.install';
  standard_install();
}

function bluemixstandard_install_tasks_alter(&$tasks, $install_state) { 
  $tasks['install_settings_form']['function'] = 'bluemixstandard_install_settings_form';
}
 
function bluemixstandard_install_settings_form($form, &$form_state, &$install_state) {
  global $databases;

  $profile = $install_state['parameters']['profile'];
  $install_locale = $install_state['parameters']['locale'];

  drupal_static_reset('conf_path');
  $conf_path = './' . conf_path(FALSE);
  $settings_file = $conf_path . '/settings.php';

  
   // We will parse VCAP variables and pre-set the database configuration form
  $hostname = '';
  $port = '';
  $dbName = 'No VCAP_SERVICES Detected. Need clearDB or PostgreSQL Service';
  $username = '';
  $password = ''; 

  if(false !== getenv('VCAP_SERVICES')) {   // Parse VCAP_SERVICES to get DB creds
    $dbName = 'No ClearDB or PostgreSQL Service Detected';

    $VCAP_SERVICES = getenv('VCAP_SERVICES');
    $decoded = json_decode($VCAP_SERVICES);

    if(!empty($decoded->cleardb)) { 
      $hostname = $decoded->cleardb[0]->credentials->hostname;
      $port = $decoded->cleardb[0]->credentials->port;
      $dbName = $decoded->cleardb[0]->credentials->name;
      $username = $decoded->cleardb[0]->credentials->username;
    } elseif (!empty($decoded->elephantsql)) {
      $postgresURI = substr($decoded->elephantsql[0]->credentials->uri, 11);
	  $slashIndex = strrpos($postgresURI,'/');
      $dotCom = strrpos($postgresURI,'.com');
      $atIndex = strpos($postgresURI, '@');
      $colonIndex = strpos($postgresURI, ':');

      $hostname = substr($postgresURI, $atIndex+1, $dotCom-$atIndex+3);
      $username = substr($postgresURI, 0, $colonIndex);
      $dbName = substr($postgresURI, $slashIndex+1);
      $port = substr($postgresURI, $dotCom+5, $dotCom-$slashIndex);
    }
  }

  // I added this line with our defaults.
  $databases['default']['default'] = array(
    'driver'   => 'mysql',
    'database' => $dbName,
    'username' => $username,
    'host'     => $hostname,
    'port'     => $port,
    'prefix'   => '',
  ); 

  $database = isset($databases['default']['default']) ? $databases['default']['default'] : array();

  drupal_set_title(st('Database configuration'));

  $drivers = drupal_get_database_types();
  $drivers_keys = array_keys($drivers);

  $form['driver'] = array(
    '#type' => 'radios',
    '#title' => st('Database type'),
    '#required' => TRUE,
    '#default_value' => !empty($database['driver']) ? $database['driver'] : current($drivers_keys),
    '#description' => st('The type of database your @drupal data will be stored in.', array('@drupal' => drupal_install_profile_distribution_name())),
  );
  if (count($drivers) == 1) {
    $form['driver']['#disabled'] = TRUE;
    $form['driver']['#description'] .= ' ' . st('Your PHP configuration only supports a single database type, so it has been automatically selected.');
  }

  // Add driver specific configuration options.
  foreach ($drivers as $key => $driver) {
    $form['driver']['#options'][$key] = $driver->name();

    $form['settings'][$key] = $driver->getFormOptions($database);
    $form['settings'][$key]['#prefix'] = '<h2 class="js-hide">' . st('@driver_name settings', array('@driver_name' => $driver->name())) . '</h2>';
    $form['settings'][$key]['#type'] = 'container';
    $form['settings'][$key]['#tree'] = TRUE;
    $form['settings'][$key]['advanced_options']['#parents'] = array($key);
    $form['settings'][$key]['#states'] = array(
      'visible' => array(
        ':input[name=driver]' => array('value' => $key),
      ),
    );
  }

  $form['actions'] = array('#type' => 'actions');
  $form['actions']['save'] = array(
    '#type' => 'submit',
    '#value' => st('Save and continue'),
    '#limit_validation_errors' => array(
      array('driver'),
      array(isset($form_state['input']['driver']) ? $form_state['input']['driver'] : current($drivers_keys)),
    ),
  // Point to custom submit function
    '#submit' => array('bluemixstandard_install_settings_form_submit'),
  );

  $form['errors'] = array();
  $form['settings_file'] = array(
    '#type' => 'value',
    '#value' => $settings_file,
  );

  return $form;
} 


function bluemixstandard_install_settings_form_validate($form, &$form_state) {
  $driver = $form_state['values']['driver'];
  $database = $form_state['values'][$driver];

  $password = ''; 

  // Parse VCAP_SERVICES to get DB creds
  if(false !== getenv('VCAP_SERVICES')) {		
    $VCAP_SERVICES = getenv('VCAP_SERVICES');
    $decoded = json_decode($VCAP_SERVICES);

    if(!empty($decoded->cleardb)) {
      $password = $username = $decoded->cleardb[0]->credentials->password;
	  
    } elseif (!empty($decoded->elephantsql)) {
      $postgresURI = substr($decoded->elephantsql[0]->credentials->uri, 11);
      $atIndex = strpos($postgresURI, '@');
      $colonIndex = strpos($postgresURI, ':');

      $password = substr($postgresURI, $colonIndex+1, $atIndex-$colonIndex-1);
    }
  }
  // Password must be set here (it won't be passed to the page and shouldn't be)
  $database['password'] = $password;
  
  $database['driver'] = $driver;

  // TODO: remove when PIFR will be updated to use 'db_prefix' instead of
  // 'prefix' in the database settings form.
  $database['prefix'] = $database['db_prefix'];
  unset($database['db_prefix']);

  $form_state['storage']['database'] = $database;
  $errors = install_database_errors($database, $form_state['values']['settings_file']);
  foreach ($errors as $name => $message) {
    form_set_error($name, $message);
  }
}

function bluemixstandard_install_settings_form_submit($form, &$form_state) {
  global $install_state;

  // Update global settings array and save.
  $settings['databases'] = array(
    'value' => array('default' => array('default' => $form_state['storage']['database'])),
    'required' => TRUE,
  );
  $settings['drupal_hash_salt'] = array(
    'value' => drupal_hash_base64(drupal_random_bytes(55)),
    'required' => TRUE,
  );
  drupal_rewrite_settings($settings);
  // Indicate that the settings file has been verified, and check the database
  // for the last completed task, now that we have a valid connection. This
  // last step is important since we want to trigger an error if the new
  // database already has Drupal installed.
  $install_state['settings_verified'] = TRUE;
  $install_state['completed_task'] = install_verify_completed_task();
}
