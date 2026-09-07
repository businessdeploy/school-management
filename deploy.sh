#!/bin/bash
set -e

# ==============================================================================
# Smart School SaaS Multi-Tenant Cloud Deployment Script
# ==============================================================================

echo "=================================================================="
echo "⚡ Smart School Multi-Tenant SaaS Platform Deployer"
echo "=================================================================="

# 1. Directory Scaffolding
echo "📁 Setting up persistent tenant storage directories..."
mkdir -p tenants
mkdir -p master-dashboard/data

# 2. Build Base Tenant Image
echo "🔨 Building Smart School Base Container (PHP 8.2 + De-licensed)..."
docker build -t smartschool-base:latest -f Dockerfile .

# 3. Launch Master Orchestration Stack
echo "🚀 Launching Master Control Plane, MariaDB Fleet, and Caddy Edge Proxy..."
docker compose -f docker-compose.master.yml up -d --build

echo ""
echo "=================================================================="
echo "✅ SaaS Master Fleet Platform is Online!"
echo "=================================================================="
echo "🌐 Master Dashboard:    http://localhost:3000"
echo "👤 Super Admin User:    superadmin"
echo "🔑 Master Password:     MasterAdmin2026!"
echo "🗄️ Database Management: http://localhost:8081 (phpMyAdmin)"
echo "🔐 Caddy On-Demand SSL: Active on Ports 80 & 443"
echo "=================================================================="
