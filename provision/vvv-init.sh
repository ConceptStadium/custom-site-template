#!/usr/bin/env bash
# Provision WordPress Stable

DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
DOMAINS=`get_hosts "${DOMAIN}"`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Install and configure the latest stable version of WordPress
if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-load.php" ]]; then
    echo "Downloading WordPress..."
	noroot wp core download --version="${WP_VERSION}" --locale=en_GB --skip-content
fi

if [[ ! -f "${VVV_PATH_TO_SITE}/public_html/wp-config.php" ]]; then
  echo "Configuring WordPress Stable..."
  noroot wp core config --dbname="${DB_NAME}" --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP
fi

if ! $(noroot wp core is-installed); then
  echo "Installing WordPress Stable..."

  if [ "${WP_TYPE}" = "subdomain" ]; then
    INSTALL_COMMAND="multisite-install --subdomains"
  elif [ "${WP_TYPE}" = "subdirectory" ]; then
    INSTALL_COMMAND="multisite-install"
  else
    INSTALL_COMMAND="install"
  fi

  noroot wp core ${INSTALL_COMMAND} --url="${DOMAIN}" --quiet --title="${SITE_TITLE}" --admin_name=conceptstadium --admin_email="claude@conceptstadium.com" --admin_password="password"

  echo "- Setting Permalink Structure..."
  noroot wp option update permalink_structure "/%category%/%postname%/"
  noroot wp option update category_base "/."

  echo "- Setting General Settings..."
  noroot wp option update date_format "F j, Y"
  noroot wp option update timezone_string "Europe/Malta"
  noroot wp option update start_of_week "1"
  noroot wp option update time_format "H:i"
  noroot wp option update users_can_register "0"
  noroot wp option update WPLANG "en_GB"

  echo "- Setting Reading Settings..."
  noroot wp option update blog_public "0"

  echo "- Setting Discussion Settings..."
  noroot wp option update close_comments_days_old "0"
  noroot wp option update close_comments_for_old_posts "1"
  noroot wp option update comment_registration "1"
  noroot wp option update default_comment_status "closed"
  noroot wp option update show_avatars ""
  
  echo "- Uninstalling and Deleting default plugins..."
  noroot wp plugin uninstall hello --deactivate
  noroot wp plugin delete hello
  noroot wp plugin uninstall akismet --deactivate
  noroot wp plugin delete akismet
  
  echo "- Installing and Activating plugins..."
  noroot wp plugin install duplicate-post --activate
  noroot wp plugin install all-in-one-wp-migration --activate
  noroot wp plugin install enable-media-replace --activate
else
  echo "Updating WordPress Stable..."
  cd ${VVV_PATH_TO_SITE}/public_html
  noroot wp core update --version="${WP_VERSION}"
fi

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
sed -i "s#{{DOMAINS_HERE}}#${DOMAINS}#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
