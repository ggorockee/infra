locals {
  region                  = data.aws_region.current.name
  private_route_table_ids = data.aws_route_tables.private.ids
  sorted_public_subnets   = sort(data.terraform_remote_state.network.outputs.public_subnet_ids)

}