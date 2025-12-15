# Cloud Armor Security Policy for GKE Istio Ingress Gateway
# Cost: Free for first 10 rules, $0.75/month per additional rule
# Request processing: First 10K requests/month free, then $0.75 per 1M requests

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.13.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.13.0"
    }
  }
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "gke_istio_policy" {
  name        = "${var.environment}-gke-istio-security-policy"
  description = "Cloud Armor security policy for GKE Istio Ingress Gateway (Free Tier)"
  project     = var.project_id

  # Default rule: Allow all traffic (Priority 2147483647)
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule: allow all"
  }

  # Rule 1: Rate limiting for DDoS protection (Priority 1000)
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limiting: 100 requests per minute per IP"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600  # 10 minutes ban
    }
  }

  # Rule 2: Block known bad user agents (Priority 2000)
  rule {
    action   = "deny(403)"
    priority = 2000
    match {
      expr {
        expression = "has(request.headers['user-agent']) && (request.headers['user-agent'].contains('sqlmap') || request.headers['user-agent'].contains('nikto') || request.headers['user-agent'].contains('masscan') || request.headers['user-agent'].contains('nmap'))"
      }
    }
    description = "Block malicious user agents"
  }

  # Rule 3: Rate limiting for login paths (Priority 3000)
  rule {
    action   = "rate_based_ban"
    priority = 3000
    match {
      expr {
        expression = "request.path.matches('/api/auth/login') || request.path.matches('/api/v1/auth/login') || request.path.matches('/auth/login') || request.path.matches('/login')"
      }
    }
    description = "Login path rate limiting: 10 requests per minute per IP"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 10
        interval_sec = 60
      }
      ban_duration_sec = 1800  # 30 minutes ban for brute force attempts
    }
  }

  # Rule 4: Block SQL injection attempts (Priority 4000)
  rule {
    action   = "deny(403)"
    priority = 4000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attempts"
  }

  # Rule 5: Block XSS attempts (Priority 5000)
  rule {
    action   = "deny(403)"
    priority = 5000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block XSS attempts"
  }

  # Rule 6: Block local file inclusion (Priority 6000)
  rule {
    action   = "deny(403)"
    priority = 6000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block local file inclusion attempts"
  }

  # Rule 7: Block remote file inclusion (Priority 7000)
  rule {
    action   = "deny(403)"
    priority = 7000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rfi-v33-stable')"
      }
    }
    description = "Block remote file inclusion attempts"
  }

  # Adaptive Protection (DDoS protection)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
      rule_visibility = "STANDARD"
    }
  }
}
