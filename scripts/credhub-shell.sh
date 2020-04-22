#!/usr/bin/env bash

set -eu

echo "${0#$PWD}" >> ~/.paas-script-usage

tunnel_mux='/tmp/bosh-ssh-tunnel.mux'

function cleanup () {
  echo 'Closing SSH tunnel'
  ssh -S "$tunnel_mux" -O exit a-destination &>/dev/null || true
}
trap cleanup EXIT

BOSH_CA_CERT="$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-CA.crt" -)"
export BOSH_CA_CERT

ssh -qfNC -4 -D 25555 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -M \
  -S "$tunnel_mux" \
  "bosh-external.${SYSTEM_DNS_ZONE_NAME}"

# Setup Credhub variables
CREDHUB_CA_CERT="$(cat <<EOCERTS
$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-vars-store.yml" - | \
  ruby -ryaml -e 'print YAML.load(STDIN).dig("credhub_tls", "ca")')
$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-vars-store.yml" - | \
  ruby -ryaml -e 'print YAML.load(STDIN).dig("uaa_ssl", "ca")')
EOCERTS
)"
export CREDHUB_CA_CERT

export CREDHUB_PROXY="socks5://localhost:25555"

export CREDHUB_SHELL=1

cat <<EOF
-------
                      ____          __
  _____________  ____/ / /_  __  __/ /_
 / ___/ ___/ _ \\/ __  / __ \\/ / / / __ \\
/ /__/ /  /  __/ /_/ / / / / /_/ / /_/ /
\\___/_/   \\___/\\____/_/ /_/\\____/_____/

1. Run 'credhub login --sso'
2. Enter the passcode from https://bosh-uaa-external.${SYSTEM_DNS_ZONE_NAME}/passcode

From this shell, you can access credhub using the credhub cli.
Basic usage:

  \$ credhub find -p /path/of/secrets
  \$ credhub get -n /name/of/secretc

To upload credentials, see the 'upload-*-secrets' Make targets
-------
EOF

unset CREDHUB_SERVER # otherwise CLI does not recognise SSO logins
credhub api "https://bosh.${SYSTEM_DNS_ZONE_NAME}:8844/api"

PS1="CREDHUB ($DEPLOY_ENV) $ " bash --login --norc --noprofile
