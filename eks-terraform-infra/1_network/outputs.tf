output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}


output "database_subnets_ids" {
  value = module.vpc.database_subnets
}

output "natgw_ids" {
  value = module.vpc.natgw_ids
}

output "interface_ids" {
  value = module.vpc.natgw_interface_ids
}