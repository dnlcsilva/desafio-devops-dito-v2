resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "postgres" {
  name        = "${var.name}-postgres-sg"
  description = "Allow PostgreSQL access from private workloads"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL from internal workloads"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-postgres-sg" })
}

resource "aws_db_instance" "postgres" {
  identifier              = var.name
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = 5432
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.multi_az
  skip_final_snapshot     = !var.multi_az
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.postgres.id]
  tags                    = var.tags
}
