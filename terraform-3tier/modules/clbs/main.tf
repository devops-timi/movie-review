# ────────────────────────────────────────────
# PUBLIC CLB (frontend / web tier)
# Classic Load Balancer — supported on free tier accounts
# ────────────────────────────────────────────
resource "aws_elb" "public" {
  name            = "${var.project_name}-public-clb"
  subnets         = var.web_subnet_ids
  security_groups = [var.public_alb_sg_id]
  internal        = false

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Name = "${var.project_name}-public-clb" }
}

# ────────────────────────────────────────────
# INTERNAL CLB (app tier)
# ────────────────────────────────────────────
resource "aws_elb" "internal" {
  name            = "${var.project_name}-internal-clb"
  subnets         = var.app_subnet_ids
  security_groups = [var.internal_alb_sg_id]
  internal        = true

  listener {
    instance_port     = 3010
    instance_protocol = "HTTP"
    lb_port           = 3010
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:3010/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = { Name = "${var.project_name}-internal-clb" }
}
