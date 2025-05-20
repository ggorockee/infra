locals {
  _base_addon_config = {
    coredns = {
      addon_version     = try(var.cluster_addons.coredns.addon_version, var.default_addon_versions.coredns)
      resolve_conflicts = "OVERWRITE"
      #   configuration_values = jsonencode({
      #     resources = {
      #       limits   = { cpu = "200m", memory = "256Mi" }
      #       requests = { cpu = "100m", memory = "128Mi" }
      #     }
      #   })
    }
    kube-proxy = {
      addon_version     = try(var.cluster_addons["kube-proxy"].addon_version, var.default_addon_versions["kube-proxy"])
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version     = try(var.cluster_addons["vpc-cni"].addon_version, var.default_addon_versions["vpc-cni"])
      resolve_conflicts = "OVERWRITE"
      #   configuration_values = jsonencode({
      #     env = {
      #       ENABLE_PREFIX_DELEGATION = "true"
      #       WARM_IP_TARGET           = "5"
      #       ENABLE_IPv6              = "false"
      #     }
      #   })
    }
    eks-pod-identity-agent = {
      addon_version     = try(var.cluster_addons["eks-pod-identity-agent"].addon_version, var.default_addon_versions["eks-pod-identity-agent"])
      resolve_conflicts = "OVERWRITE"
    }

  }

  base_addon_config = {
    for key, config in local._base_addon_config :
    key => merge(config, {
      tags = merge(
        var.tags,
        try(config.tags, {})
      )
    })
  }

  merged_addons = merge(local.base_addon_config, var.cluster_addons)

  access_entries = merge(
    var.eks_access_entries,
    # 기본값이나 추가적인 설정이 필요할 경우 여기에 정의
    {
      # 예: 기본 액세스 엔트리 추가
      # "example_user" = {
      #   kubernetes_groups = ["viewers"]
      #   principal_arn     = "arn:aws:iam::123456789012:user/example-user"
      # }
    }
  )

  private_route_table_ids = data.aws_route_tables.private.ids

}

