# ────────────────────────────────────────────
# WEB TIER — Next.js behind Nginx (Public Subnet)
# ────────────────────────────────────────────
resource "aws_instance" "web" {
  count                  = length(var.web_subnet_ids)
  ami                    = var.web_ami
  instance_type          = var.web_instance_type
  subnet_id              = var.web_subnet_ids[count.index]
  vpc_security_group_ids = [var.web_sg_id]
  key_name               = var.key_name



  tags = { Name = "${var.project_name}-web-${count.index + 1}", Tier = "web" }
}

resource "aws_elb_attachment" "web" {
  count    = length(aws_instance.web)
  elb      = var.public_clb_name
  instance = aws_instance.web[count.index].id
}

# ────────────────────────────────────────────
# APP TIER — Node.js (Private Subnet)
# ────────────────────────────────────────────
resource "aws_instance" "app" {
  count                  = length(var.app_subnet_ids)
  ami                    = var.app_ami
  instance_type          = var.app_instance_type
  subnet_id              = var.app_subnet_ids[count.index]
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = var.key_name



  tags = { Name = "${var.project_name}-app-${count.index + 1}", Tier = "app" }
}

resource "aws_elb_attachment" "app" {
  count    = length(aws_instance.app)
  elb      = var.internal_clb_name
  instance = aws_instance.app[count.index].id
}
