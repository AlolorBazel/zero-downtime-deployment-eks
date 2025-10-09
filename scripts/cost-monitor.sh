#!/usr/bin/env bash
# AWS Cost Monitoring and Alerting Setup

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ALERT_EMAIL="${COST_ALERT_EMAIL:-bossfreeman9@gmail.com}"
MONTHLY_BUDGET="${MONTHLY_BUDGET:-300}"

echo "🔍 Setting up AWS cost monitoring and alerts..."

# Check AWS CLI availability
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install: https://aws.amazon.com/cli/"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "📊 AWS Account: ${ACCOUNT_ID}"

# Create SNS topic for cost alerts
echo "📧 Creating SNS topic for cost alerts..."
TOPIC_ARN=$(aws sns create-topic \
    --name eks-cost-alerts \
    --region "${REGION}" \
    --query TopicArn \
    --output text 2>/dev/null || \
    aws sns list-topics --region "${REGION}" | \
    jq -r '.Topics[] | select(.TopicArn | contains("eks-cost-alerts")) | .TopicArn' | head -1)

echo "✅ SNS Topic: ${TOPIC_ARN}"

# Subscribe email to SNS topic
echo "📮 Subscribing ${ALERT_EMAIL} to alerts..."
aws sns subscribe \
    --topic-arn "${TOPIC_ARN}" \
    --protocol email \
    --notification-endpoint "${ALERT_EMAIL}" \
    --region "${REGION}" 2>/dev/null || echo "⚠️  Subscription may already exist"

echo "⚠️  Check ${ALERT_EMAIL} and confirm subscription!"

# Create CloudWatch billing alarm (80% of budget)
echo "⏰ Creating CloudWatch billing alarm at 80% threshold..."
aws cloudwatch put-metric-alarm \
    --alarm-name "eks-cost-80-percent" \
    --alarm-description "Alert when EKS costs reach 80% of monthly budget" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 21600 \
    --evaluation-periods 1 \
    --threshold $(echo "${MONTHLY_BUDGET} * 0.8" | bc) \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions "${TOPIC_ARN}" \
    --dimensions Name=Currency,Value=USD \
    --region us-east-1

# Create CloudWatch billing alarm (100% of budget)
echo "🚨 Creating CloudWatch billing alarm at 100% threshold..."
aws cloudwatch put-metric-alarm \
    --alarm-name "eks-cost-100-percent" \
    --alarm-description "Alert when EKS costs reach monthly budget" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 21600 \
    --evaluation-periods 1 \
    --threshold "${MONTHLY_BUDGET}" \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions "${TOPIC_ARN}" \
    --dimensions Name=Currency,Value=USD \
    --region us-east-1

# Get current month-to-date costs
echo ""
echo "💰 Current month-to-date costs:"
aws ce get-cost-and-usage \
    --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --region us-east-1 \
    --query 'ResultsByTime[0].Total.BlendedCost' 2>/dev/null || echo "⚠️  Cost Explorer API may not be available"

echo ""
echo "✅ Cost monitoring setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Confirm email subscription (check ${ALERT_EMAIL})"
echo "   2. View alarms: aws cloudwatch describe-alarms --region us-east-1"
echo "   3. Monitor costs: aws ce get-cost-and-usage (requires Cost Explorer enabled)"
echo "   4. Run: make cost-report for detailed breakdown"
