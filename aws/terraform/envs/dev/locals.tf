locals {
  region                  = data.aws_region.current.name
  private_route_table_ids = data.aws_route_tables.private.ids
}