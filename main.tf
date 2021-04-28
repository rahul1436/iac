provider "aws" {
  region                  = "ca-central-1"
}

resource "aws_launch_template" "test-launchtemplate" {
  name = "test-launchtemplate"
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 30
      volume_type = "gp2"

    }
  }
  iam_instance_profile {
    name = "test-iam-instance-profile"
  }

  image_id      = "your-ami-id"
  user_data     = "${base64encode(file("test.sh"))}"
  instance_type = "m4.xlarge"
  key_name      = "yourkey"

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = "subnet-"
    security_groups             = ["sg-"]

  }

  placement {
    availability_zone = "ca-central-1a"
  }


  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }
}
resource "aws_autoscaling_group" "test-od-asg" {
  availability_zones = ["ca-central-1a"]
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1
  health_check_type  = "EC2"

  launch_template {
    id      = aws_launch_template.test-launchtemplate.id
    version = "$Latest"
  }
}
resource "aws_autoscaling_policy" "scale-up" {
  name                   = "agents-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.test-od-asg.name}"
}

resource "aws_autoscaling_policy" "scale-down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.test-od-asg.name}"
}
resource "aws_cloudwatch_metric_alarm" "test-high" {
  alarm_name          = "test-scaleup"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "20000"
  alarm_description   = "This metric monitors number of messages in queue"
  alarm_actions = [
    "${aws_autoscaling_policy.scale-up.arn}"
  ]
  dimensions = {
    autoscaling_group_name = "${aws_autoscaling_group.test-od-asg.name}"
    QueueName              = "YourQueueName"
  }
}

resource "aws_cloudwatch_metric_alarm" "test-low" {
  alarm_name          = "test-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfMessagesNotVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "40"
  alarm_description   = "This metric monitors number of messages in queue"
  alarm_actions = [
    "${aws_autoscaling_policy.scale-down.arn}"
  ]
  dimensions = {
    autoscaling_group_name = "${aws_autoscaling_group.test-od-asg.name}"
    QueueName              = "YourQueueName"
  }
}
