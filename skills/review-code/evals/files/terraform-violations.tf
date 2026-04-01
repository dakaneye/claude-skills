provider "aws" {
  region     = "us-west-2"
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

resource "aws_instance" "app" {
  count         = length(var.subnet_ids)
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.medium"
  subnet_id     = var.subnet_ids[count.index]

  tags = {
    Name = "app-${count.index}"
  }
}

resource "aws_db_instance" "production" {
  identifier     = "prod-database"
  engine         = "postgres"
  engine_version = "14.7"
  instance_class = "db.r5.large"

  allocated_storage = 100
  storage_encrypted = true

  username = "admin"
  password = "SuperSecret123!"

  skip_final_snapshot = true
}

variable "subnet_ids" {
  type = list(string)
}
