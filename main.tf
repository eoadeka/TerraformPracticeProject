provider "aws" {
    region = "eu-west-2"
    access_key = "x"
    secret_key = "x"
}

# 1. Create a VPC
resource "aws_vpc" "free-vpc" {

    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "production"
    }

}

# 2. Create an Internet Gateway
resource "aws_internet_gateway" "free-igw" {

    vpc_id = aws_vpc.free-vpc.id

}

# 3. Create a custom Route Table
resource "aws_route_table" "free-routetable" {

    vpc_id = aws_vpc.free-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.free-igw.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.free-igw.id
    }
    tags = {
      Name = "production"
    }
  
}

# 4. Create a Subnet
resource "aws_subnet" "free-subnet" {
    vpc_id = aws_vpc.free-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"
    tags = {
      Name = "prod-subnet"
    }
}

# 5. Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.free-subnet.id
    route_table_id = aws_route_table.free-routetable.id
}

# 6. Create a Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
    name = "allow_web_traffic"
    description = "Allow web inbound traffic"
    vpc_id = aws_vpc.free-vpc.id

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags = {
        Name = "allow_web"
    }
  
}

# 7. Create a Network Interface with an IP in the subnet(step 4)
resource "aws_network_interface" "web-server-nic" {
    subnet_id = aws_subnet.free-subnet.id
    private_ips = [ "10.0.1.50" ]
    security_groups = [ aws_security_group.allow_web.id ]

}

# 8. Assign an elastic IP to the network interface(step 7)
resource "aws_eip" "one" {
    domain = "vpc"
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [ aws_internet_gateway.free-igw ]
}

# Output/Print the public IP address
output "server_public_ip" {
    value = aws_eip.one.public_ip
}

# 9. Create an ubuntu server and install/enable apache2
resource "aws_instance" "web-server-instance" {
    ami = "ami-x"
    instance_type = "t2.micro"
    availability_zone = "eu-west-2a"
    key_name = "freecode-practice-masterkey"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo "your veery first webserver" > /var/www/html/index.html'
                EOF
    
    tags = {
        Name = "web-server"
    }
}