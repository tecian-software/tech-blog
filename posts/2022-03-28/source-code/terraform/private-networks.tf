resource "aws_subnet" "private_subnets" {

  # generate one subnet per defined
  # CIDR block and set in and select availabity zone
  count             = length(var.private_subnet_cidrs)
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  vpc_id            = aws_vpc.vpc.id
}

resource "aws_route_table" "private_route_tables" {
  count    = length(var.private_subnet_cidrs)
  vpc_id   = aws_vpc.vpc.id
}

# generate routes for route tables
resource "aws_route" "private_route" {
  # define route table definitions
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private_route_tables[count.index].id
  # define destionation configurations
  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id         = aws_nat_gateway.nat_gateway[count.index].id
}

resource "aws_route_table_association" "private_route_asc" {
  # iterate over each index
  count          = length(var.private_subnet_cidrs)
  # get subnet ID and route table ID from index
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_tables[count.index].id
}