#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:-origin/main}"

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
  echo "[]"
  exit 0
fi

printf '['
for i in "${!changed_services[@]}"; do
  printf '"%s"' "${changed_services[$i]}"
  if [[ "$i" -lt $((${#changed_services[@]} - 1)) ]]; then
    printf ','
  fi
done
printf ']\n'
