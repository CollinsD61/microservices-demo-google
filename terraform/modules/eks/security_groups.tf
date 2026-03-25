# =============================================================================
# SECURITY GROUPS FOR EKS
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Cluster Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "cluster" {
  name        = "${local.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-eks-cluster-sg"
  })
}

# Cho phép nodes giao tiếp với control plane
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow cluster egress to anywhere"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
}

# -----------------------------------------------------------------------------
# EKS Node Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "node" {
  name        = "${local.name_prefix}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name                                        = "${local.name_prefix}-eks-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Nodes có thể giao tiếp với nhau
resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

# Control plane có thể giao tiếp với nodes
resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow cluster to communicate with nodes"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  type                     = "ingress"
}

# Nodes có thể gửi traffic ra ngoài
resource "aws_security_group_rule" "node_egress_all" {
  description       = "Allow nodes egress to anywhere"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.node.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
}
