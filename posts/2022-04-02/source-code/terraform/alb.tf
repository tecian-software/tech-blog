resource "aws_lb" "main" {

  name               = "example-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  # add private and public subnets to loadbalancer
  subnets                    = data.aws_subnet.public.*.id
  drop_invalid_header_fields = true
}

# create security group for application loadbalancer
# which defines HTTPS and HTTP ports as valid
resource "aws_security_group" "alb" {
  name        = "example-app-sg-alb"
  vpc_id      = data.aws_vpc.main.id
  description = "Allow access to ALB over HTTP port 80, HTTPS port 443 and allow all egress"

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    description      = "Allow ingress to HTTP port over all routes"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    description      = "Allow ingress to HTTPS port over all routes"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    description      = "Allow egress to all sources"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# manage HTTPS traffic via target group
resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# manage HTTPS traffic via target group
resource "aws_alb_listener" "https" {

  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"
  # set certificate ARN
  certificate_arn = var.certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    target_group_arn = aws_alb_target_group.http.id
    type             = "forward"
  }
}

# define target group to receive HTTPS traffic.
# the target group can then be references by the
# ECS service to receive traffic from the loadbalancer
resource "aws_alb_target_group" "http" {
  name        = "example-app-tg-api"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "120"
    protocol            = "HTTP"
    matcher             = "404"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}
