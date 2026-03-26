#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-}"
if [[ -z "$base_ref" || "$base_ref" == "0000000000000000000000000000000000000000" ]]; then
  base_ref="HEAD~1"
fi

service_roots=(
  adservice
  cartservice
  checkoutservice
  currencyservice
  emailservice
  frontend
  loadgenerator
  paymentservice
  productcatalogservice
  recommendationservice
  shippingservice
)

changed_files=$(git diff --name-only "$base_ref"...HEAD)

declare -a changed_services=()
for service in "${service_roots[@]}"; do
  if grep -qE "^src/${service}/" <<< "$changed_files"; then
    changed_services+=("$service")
  fi
done

if [[ ${#changed_services[@]} -eq 0 ]]; then
  echo ""
  exit 0
fi

# Skaffold modules in this repo are config names: app and loadgenerator.
has_app=false
has_loadgenerator=false

for service in "${changed_services[@]}"; do
  if [[ "$service" == "loadgenerator" ]]; then
    has_loadgenerator=true
  else
    has_app=true
  fi
done

modules=()
if [[ "$has_app" == true ]]; then
  modules+=("app")
fi
if [[ "$has_loadgenerator" == true ]]; then
  modules+=("loadgenerator")
fi

IFS=,
echo "${modules[*]}"
