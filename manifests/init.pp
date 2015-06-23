# class for installing and configuring tempest
#
# The class checks out the tempest repo and sets the basic config.
#
# Note that only parameters for which values are provided will be
# managed in tempest.conf.
#
# == Parameters
#
# [*lock_path*]
#   Directory to use lock files by tempest.
#
#

class tempest(
  # Clone config
  #
  $tempest_repo_uri          = 'git://github.com/openstack/tempest.git',
  $tempest_repo_revision     = undef,
  $tempest_clone_path        = '/var/lib/tempest',
  $tempest_clone_owner       = 'root',

  $setup_venv                = false,

  # Glance image config
  #
  $configure_images          = true,
  $image_name                = undef,
  $image_name_alt            = undef,
  $image_ref                 = undef,
  $image_ref_alt             = undef,
  $image_ssh_user            = undef,
  $image_alt_ssh_user        = undef,

  # Neutron network config
  #
  $configure_networks        = true,
  $public_network_name       = undef,
  $fixed_network_name        = undef,

  # tempest.conf parameters
  #
  $lock_path                 = '/tmp',
  $identity_uri              = undef,
  $identity_uri_v3           = undef,

  $cli_dir                   = undef,
  # non admin user
  $username                  = undef,
  $password                  = undef,
  $tenant_name               = undef,
  # another non-admin user
  $alt_username              = undef,
  $alt_password              = undef,
  $alt_tenant_name           = undef,
  # admin user
  $admin_username            = undef,
  $admin_password            = undef,
  $admin_tenant_name         = undef,
  $admin_role                = undef,
  # compute features
  $run_ssh                   = undef,
  $ssh_auth_method           = undef,
  $ssh_connect_method        = undef,
  $ssh_user                  = undef,
  $boot_from_volume_only     = undef,
  $disk_config               = undef,
  $api_extensions            = undef,
  $change_password           = undef,
  $console_output            = undef,
  # oslo configs
  $lock_path                 = undef,
  $process_locking           = undef,
  # validation
  $run_validation            = undef,
  $connect_method            = undef,
  $auth_method               = undef, 

  # flavor information
  $flavor_name               = undef,
  $flavor_name_alt           = undef,
  $flavor_ref                = undef,
  $flavor_ref_alt            = undef,
  # whitebox
  $whitebox_db_uri           = undef,
  # testing features that are supported
  $resize_available          = undef,
  $change_password_available = undef,
  $allow_tenant_isolation    = undef,
  # neutron config
  $public_network_id         = undef,
  # Upstream has a bad default - set it to empty string.
  $public_router_id          = '',
  # Service configuration
  $glance_available          = true,
  $heat_available            = false,
  $horizon_available         = true,
  $neutron_available         = false,
  $nova_available            = true,
  $swift_available           = false,
  # Cinder volume options
  $cinder_available          = true,
  $volume_storage_protocol   = 'iSCSI',
) {

  include 'tempest::params'

  if $admin_tenant_name {
    $admin_tenant_name_orig = $admin_tenant_name
  } else {
    $admin_tenant_name_orig = $tenant_name
  }

  ensure_packages([
    'python-pip',
    'git',
    'python-setuptools',
  ])

  ensure_packages($tempest::params::dev_packages)

  exec { 'install-tox':
    command => "pip install -U tox",
    path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin'],
    unless  => '/usr/bin/which tox',
    require => Package['python-pip'],
  }

  vcsrepo { $tempest_clone_path:
    ensure   => 'present',
    source   => $tempest_repo_uri,
    revision => $tempest_repo_revision,
    provider => 'git',
    require  => Package['git'],
    user     => $tempest_clone_owner,
  }

  if $setup_venv {
    # virtualenv will be installed along with tox
    exec { 'setup-venv':
      command => "/usr/bin/python ${tempest_clone_path}/tools/install_venv.py",
      cwd     => $tempest_clone_path,
      unless  => "/usr/bin/test -d ${tempest_clone_path}/.venv",
      require => [
        Vcsrepo[$tempest_clone_path],
        Exec['install-tox'],
        Package[$tempest::params::dev_packages],
      ],
    }
  }

  $tempest_conf = "${tempest_clone_path}/etc/tempest.conf"
  $tempest_account_yaml = "${tempest_clone_path}/etc/accounts.yaml"

  file { $tempest_conf:
    replace => false,
    source  => "${tempest_conf}.sample",
    require => Vcsrepo[$tempest_clone_path],
    owner   => $tempest_clone_owner,
  }

  Tempest_config {
    path    => $tempest_conf,
    require => File[$tempest_conf],
  }

  file { $tempest_account_yaml:
    replace => false,
    ensure  => file,
    require => Vcsrepo[$tempest_clone_path],
    owner   => $tempest_clone_owner,
  }

  Tempest_account_config {
    configfile => $tempest_account_yaml,
    require    => File[$tempest_account_yaml],
  }

  tempest_config {
    'auth/allow_tenant_isolation':       value => $allow_tenant_isolation;
    'compute/change_password_available': value => $change_password_available;
    'compute/image_alt_ssh_user':        value => $image_alt_ssh_user;
    'compute/image_ssh_user':            value => $image_ssh_user;
    'compute/resize_available':          value => $resize_available;
    'compute/fixed_network_name':        value => $fixed_network_name;
    'compute/run_ssh':			 value => $run_ssh;
    'compute/ssh_auth_method':           value => $ssh_auth_method;
    'compute/ssh_connect_method':        value => $ssh_connect_method;
    'compute/ssh_user':			 value => $ssh_user		
    'compute-feature-enabled/boot_from_volume_only': value => $boot_from_volume_only;
    'compute-feature-enabled/disk_config': value => $disk_config;
    'compute-feature-enabled/api_extensions': value => $api_extensions;
    'compute-feature-enabled/change_password': value => $change_password;
    'compute-feature-enabled/console_output': value => $console_output;
    'compute-feature-enabled/resize': value => $resize;
    'identity/admin_password':           value => $admin_password, secret => true;
    'identity/admin_tenant_name':        value => $admin_tenant_name_orig;
    'identity/admin_username':           value => $admin_username;
    'identity/admin_role':               value => $admin_role;
    'identity/alt_password':             value => $alt_password, secret => true;
    'identity/alt_tenant_name':          value => $alt_tenant_name;
    'identity/alt_username':             value => $alt_username;
    'identity/password':                 value => $password, secret => true;
    'identity/tenant_name':              value => $tenant_name;
    'identity/uri':                      value => $identity_uri;
    'identity/uri_v3':                   value => $identity_uri_v3;
    'identity/username':                 value => $username;
    'network/public_router_id':          value => $public_router_id;
    'network/fixed_network_name':        value => $fixed_network_name;
    'oslo_concurrency/lock_path':        value => $lock_path;
    'oslo_concurrency/disable_process_locking':value => $process_locking;
    'service_available/cinder':          value => $cinder_available;
    'service_available/glance':          value => $glance_available;
    'service_available/heat':            value => $heat_available;
    'service_available/horizon':         value => $horizon_available;
    'service_available/neutron':         value => $neutron_available;
    'service_available/nova':            value => $nova_available;
    'service_available/swift':           value => $swift_available;
    'whitebox/db_uri':                   value => $whitebox_db_uri;
    'cli/cli_dir':                       value => $cli_dir;
    'validation/run_validation':         value => $run_validation;
    'validation/connect_method':         value => $connect_method;
    'validation/auth_method':            value => $auth_method;
    'volume/storage_protocol':           value => $volume_storage_protocol;
  }

  tempest_account_config {
    "${username}@${tenant_name}":                   password => $password;
    "${admin_username}@${admin_tenant_name_orig}":  password => $admin_password;
  }

  if ($alt_username) and ($alt_password) and ($alt_tenant_name) {
    tempest_account_config { "${alt_username}@${alt_tenant_name}":
      password => $alt_password
    }
  }

  if ($flavor_name and $flavor_ref) or (! $flavor_name and ! $flavor_ref) {
    fail('Values setting or not setting for both flavor_name and flavor_ref are not valid')
  } elsif $flavor_name {
    $flavor_uuid_set = 'flavor'
    $flavor_ref_orig = $flavor_name
  } elsif $flavor_ref {
    $flavor_ref_orig = $flavor_ref
  }

  if $flavor_name_alt and $flavor_ref_alt  {
    fail('Both flavor_name_alt and flavor_ref_alt can not be provided')
  } elsif $flavor_name_alt {
    $flavor_uuid_set_alt = 'flavor'
    $flavor_ref_alt_orig = $flavor_name_alt
  } elsif $flavor_ref_alt {
    $flavor_ref_alt_orig = $flavor_ref_alt
  }

  if flavor_ref_orig {
    tempest_config {'compute/flavor_ref':
      value  => $flavor_ref_orig,
      set_id => $flavor_uuid_set,
    }
  }

  if flavor_ref_alt_orig {
   tempest_config {'compute/flavor_ref_alt':
    value  => $flavor_ref_alt_orig,
    set_id => $flavor_uuid_set_alt,
   }
  }

  if $configure_images {

    ##
    # If the image id was not provided, look it up via the image name
    # and set the value in the conf file.
    ##

    if ! $image_ref and $image_name {
      $image_uuid_set = 'glance_image'
      $image_ref_orig = $image_name
    } elsif ! $image_name and $image_ref {
      $image_ref_orig = $image_ref
    } elsif ($image_name and $image_ref) or (! $image_name and ! $image_ref) {
      fail('A value for either image_name or image_ref must be provided.')
    }

    if ! $image_ref_alt and $image_name_alt {
      $image_uuid_set_alt = 'glance_image'
      $image_ref_alt_orig = $image_name_alt
    } elsif ! $image_name_alt and $image_ref_alt {
      $image_ref_alt_orig = $image_ref_alt
    } elsif ($image_name_alt and $image_ref_alt) or (! $image_name_alt and ! $image_ref_alt) {
      fail('A value for either image_name_alt or image_ref_alt must be provided.')
    }

    if $image_ref_orig {
      tempest_config {'compute/image_ref':
        value  => $image_ref_orig,
        set_id => $image_uuid_set,
      }
    }

    if $image_ref_alt_orig {
      tempest_config {'compute/image_ref_alt':
        value  => $image_ref_alt_orig,
        set_id => $image_uuid_set_alt,
      }
    }
  }

  if $neutron_available and $configure_networks {
    if ! $public_network_id and $public_network_name {
      $public_network_uuid_set = 'network'
      $public_network_ref_orig = $public_network_name
    } elsif ! $public_network_name and $public_network_id {
      $public_network_ref_orig = $public_network_id
    } elsif ($public_network_name and $public_network_id) or (! $public_network_name and ! $public_network_id) {
      fail('A value for either public_network_id or public_network_name must be provided.')
    }

    if $public_network_ref_orig {
      tempest_config {'network/public_network_id':
        value  => $public_network_ref_orig,
        set_id => $public_network_uuid_set,
      }
    }
  }
}
