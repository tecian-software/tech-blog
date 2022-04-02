resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)
  vpc   = true
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id

  subnet_id     = aws_subnet.public_subnets[count.index].id
  depends_on    = [aws_internet_gateway.gateway]
}