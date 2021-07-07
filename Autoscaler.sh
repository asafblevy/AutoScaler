#!/bin/bash
function Create_and_Balance {
ami = ami-0e8286b71b81c3cc1 
# First We're gonna launch an EC2 instance using a centos image
echo "Launching new instance"
aws ec2 run-instances --image-id $ami --count 1 --instance-type t2.micro --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=NewServer}]' > /dev/null 2>&1

if [ $? -eq 0 ]; then
# Now We're gonna register the new instance to our load balancer
  latest_instance=`aws ec2 describe-instances --query 'Reservations[*].Instances[*].{Instance:InstanceId}' | tail -1`
        echo 'Registering NewServer to Load Balancer'
        aws elb register-instances-with-load-balancer --load-balancer-name my-load-balancer --instances $latest_instance >/dev/null 2>&1

else
        echo 'Instace creation Failed'
fi
}

# Formats the time one hour ago for the cpu command
hrago=`date -d "1 hour ago" '+%Y-%m-%dT%H:%M:%SZ'`
# Formats the time right now for the cpu command
now=`date '+%Y-%m-%dT%H:%M:%SZ'`

# Gets cpu metrics from the last hour
cpuf=`aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization  --period 60 --statistics Maximum --dimensions Name=InstanceId,Value=i-04a105334ba18dd80 --start-time $hrago --end-time $now | awk '{print $2}' | sort -r -n`
# Gets latest cpu metric
cpunow=`echo $cpuf | awk '{print $1}'`
# Turns cpu metric from float to int
cpu=`printf "%.0f\n" "$cpunow"`
# Stressing
stress --cpu 60 --timeout 3600 & >/dev/null 2>&1

# checking the cpu every 30 seconds while updating the cpu variables
while [ $cpu -le 80 ]
        do
        echo "cpu is good"
        sleep 30
        cpuf=`aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization  --period 60 --statistics Maximum --dimensions Name=InstanceId,Value=i-04a105334ba18dd80 --start-time $hrago --end-time $now | awk '{print $2}' | sort -r -n`
        cpunow=`echo $cpuf | awk '{print $1}'`
        cpu=`printf "%.0f\n" "$cpunow"`

        done

echo "CPU was too high at $cpu%"

Create_and_Balance

pkill -f stress
