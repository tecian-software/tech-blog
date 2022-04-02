resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public_subnets" {

  # generate one subnet per defined
  # CIDR block and set in and select availabity zone
  count             = length(var.public_subnet_cidrs)
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  vpc_id            = aws_vpc.vpc.id

  map_public_ip_on_launch = true
}

# create new route table to manange newtork rules
resource "aws_route_table" "public_route_tables" {
  count    = length(var.public_subnet_cidrs)
  vpc_id   = aws_vpc.vpc.id
}

# create new route to map traffic from internet
# gateway to route table
resource "aws_route" "public_routes" {
  count                  = length(var.public_subnet_cidrs)
  # define route table definitions
  route_table_id         = aws_route_table.public_route_tables[count.index].id
  # define destination configurations. note that
  # all networks are used for the the destination block
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

# create new association between public subnet and route table
resource "aws_route_table_association" "public_route_ascs" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_tables[count.index].id
}