param(
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-southeast-1"
)

Write-Host "============================================" -ForegroundColor Yellow
Write-Host " MANUAL PRE-DESTROY CLEANUP" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

# --- Buoc 1: Ket noi toi EKS ---
Write-Host ""
Write-Host "[1/6] Updating kubeconfig for cluster: $ClusterName ..." -ForegroundColor Cyan
aws eks update-kubeconfig --region $Region --name $ClusterName
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not connect to EKS. Cluster may already be deleted. Skipping K8s steps."
    exit 0
}

# --- Buoc 2: Xoa ArgoCD Applications ---
Write-Host ""
Write-Host "[2/6] Deleting all ArgoCD Applications..." -ForegroundColor Cyan
kubectl delete applications.argoproj.io --all -n argocd --ignore-not-found --timeout=120s
Start-Sleep -Seconds 15

# --- Buoc 3: Xoa tat ca LoadBalancer Services ---
Write-Host ""
Write-Host "[3/6] Finding and deleting all LoadBalancer-type Services..." -ForegroundColor Cyan
$svcsRaw = kubectl get svc --all-namespaces -o json 2>&1
$svcs = $svcsRaw | ConvertFrom-Json
$lbSvcs = $svcs.items | Where-Object { $_.spec.type -eq "LoadBalancer" }

if ($null -eq $lbSvcs -or $lbSvcs.Count -eq 0) {
    Write-Host "  No LoadBalancer services found." -ForegroundColor Green
} else {
    foreach ($svc in $lbSvcs) {
        $ns = $svc.metadata.namespace
        $name = $svc.metadata.name
        Write-Host "  Deleting: $ns/$name" -ForegroundColor White
        kubectl delete svc $name -n $ns --ignore-not-found
    }
}

# --- Buoc 4: Xoa tat ca Ingresses ---
Write-Host ""
Write-Host "[4/6] Deleting all Ingress resources..." -ForegroundColor Cyan
kubectl delete ingress --all --all-namespaces --ignore-not-found --timeout=60s

# --- Buoc 4b: Xoa orphan Security Groups do ALB Controller tao ---
Write-Host ""
Write-Host "[4b/6] Deleting orphan Security Groups created by ALB Controller..." -ForegroundColor Cyan
$vpcId = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*$ClusterName*" --query "Vpcs[0].VpcId" --output text --region $Region 2>$null)
if ($vpcId -and $vpcId -ne "None" -and $vpcId -ne "") {
    Write-Host "  Found VPC: $vpcId" -ForegroundColor Gray
    $sgs = aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[?GroupName!='default'].{ID:GroupId,Name:GroupName}" --output json --region $Region | ConvertFrom-Json
    $orphanSgs = $sgs | Where-Object { $_.Name -like "k8s-*" }
    if ($null -eq $orphanSgs -or $orphanSgs.Count -eq 0) {
        Write-Host "  No orphan ALB security groups found." -ForegroundColor Green
    } else {
        foreach ($sg in $orphanSgs) {
            Write-Host "  Deleting SG: $($sg.ID) ($($sg.Name))" -ForegroundColor White
            aws ec2 delete-security-group --group-id $sg.ID --region $Region 2>&1
        }
    }
} else {
    Write-Host "  VPC not found - skipping SG cleanup." -ForegroundColor Yellow
}

# --- Buoc 5: Doi AWS thu hoi ALB/NLB ---
Write-Host ""
Write-Host "[5/6] Waiting 3 minutes for AWS to release ENIs from subnets..." -ForegroundColor Cyan
Write-Host "  (ALB can ~2-3 phut de AWS xoa ENI va giai phong subnet)" -ForegroundColor Gray
$countdown = 180
while ($countdown -gt 0) {
    Write-Host "  Con $countdown giay..." -ForegroundColor Gray
    Start-Sleep -Seconds 10
    $countdown -= 10
}

# --- Buoc 6: Kiem tra ENI con lai ---
Write-Host ""
Write-Host "[6/6] Verifying no ENIs remain..." -ForegroundColor Cyan
$vpcId = (aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*$ClusterName*" --query "Vpcs[0].VpcId" --output text 2>$null)
if ($vpcId -and $vpcId -ne "None" -and $vpcId -ne "") {
    $enis = (aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpcId" --query "NetworkInterfaces[?Status!='available'].NetworkInterfaceId" --output text 2>$null)
    if ($enis -and $enis -ne "") {
        Write-Warning "Still have non-available ENIs: $enis. May need to wait longer."
    } else {
        Write-Host "  All ENIs released! Safe to run terraform destroy." -ForegroundColor Green
    }
} else {
    Write-Host "  VPC not found by tag - may already be partially deleted." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " DONE! Now run: terraform destroy" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
