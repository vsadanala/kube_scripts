#!/bin/bash
environment=PROD
dmy=$(date +%d-%m-%Y)
printf "<html><pre>"
echo "<style> table, th, td {border:1px solid black;font-size: 10px;} </style>"
echo " <style>
.k8 {
  background-color: DodgerBlue;
  color: white;
  margin: 1px;
  padding: 1px;
  letter-spacing:35px;
}
</style>"
echo "<div class=\"k8\"> <h1 align=\"center\">THRIVEAI KUBERNETES</h1> </div>"
printf "<h1 align=center><strong><span style="color:navy">Node Utilization - $environment : $dmy</span></strong></h1> <hr/> "
/usr/local/bin/kubectl get nodes|awk '{print $1}'|sed 1,1d>/opt/k8health/hosts
cat /opt/k8health/hosts|grep kube > /opt/k8health/master_nodes
cat /opt/k8health/hosts|grep -v kube > /opt/k8health/worker_nodes
printf "<h2 align=\"center\"><span style=\"color:navy;text-align:center\">K8-MASTER-NODES</span></h2>"

echo "<table style=\"width:100%\"> <tr>"
for n in `cat /opt/k8health/master_nodes`
do
    printf "<td> <pre>"
    printf "<h3><span style=\"color:blue;text-align: center;text-decoration: underline\">"
    printf "$n"
    printf "</span></h3>"
    printf "<h3>Resource Capacity</h3>"
    /usr/local/bin/kubectl describe node $n| grep -A7 "Capacity:"|grep -e memory -e cpu -e pods
    pod=`/usr/local/bin/kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$n|sed 1,1d|wc -l`
    printf "</hr><h3>Resource utilization</h3>"
    /usr/local/bin/kubectl describe node $n|grep -A7 "Resource"|grep -e cpu -e memory -e Resource -e '-'
    pod=`/usr/local/bin/kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$n|sed 1,1d|wc -l`
    echo " "
    printf "  Number of pods assigned to the node $n: "${pod}
    echo " "
    printf "\n</hr><h3>Local Disk utilization</h3>"
    raw=`ssh $n fdisk -l|grep "Disk /dev/"|grep -v "/dev/mapper/"|awk '{sum+=$3} END {print sum}'`
    echo "<h4><b>Raw Capacity(GB):$raw</b></h4>"
    ssh $n df -k|grep /dev|grep -v devtmpfs|grep -v tmpfs| awk 'BEGIN { format = "%11s %18s %20s \n"
             printf format, "Allocated(GB)", "Used(GB)", "Available(GB)"
             printf format, "-------------", "--------", "-------------" }
     {sum2+=$2;sum3+=$3;sum4+=$4}END {printf  format, int(sum2/(1024*1024)),int(sum3/(1024*1024)),int(sum4/(1024*1024))}'
    printf "</td> </pre>"
done
printf "</tr> </table>"
printf "</hr>"

printf "<h2 align=\"center\"><span style=\"color:navy;text-align:center\">K8-WORKER-NODES</span></h2>"

x=1
while (( x ))
do
head -n 3 /opt/k8health/worker_nodes > /opt/k8health/temp_worker_nodes
echo "<table style=\"width:100%\"> <tr>"
for n in `cat /opt/k8health/temp_worker_nodes`
do
    printf "<td> <pre>"
    printf "<h3><span style=\"color:blue;text-align: center;text-decoration: underline\">"
    printf "$n"
    printf "</span></h3>"
    printf "<h3>Resource Capacity</h3>"
    /usr/local/bin/kubectl describe node $n| grep -A7 "Capacity:"|grep -e memory -e cpu -e pods
    pod=`/usr/local/bin/kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$n|sed 1,1d|wc -l`
    printf "</hr><h3>Resource utilization</h3>"
    /usr/local/bin/kubectl describe node $n|grep -A7 "Resource"|grep -e cpu -e memory -e gpu -e Resource -e '-'|grep -v ephemeral|grep -v hugepages
    pod=`/usr/local/bin/kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$n|sed 1,1d|wc -l`
    echo " "
    printf "  Number of pods assigned to the node $n: "${pod}
    echo " "
    printf "\n</hr><h3>Local Disk utilization</h3>"
    raw=`ssh $n fdisk -l|grep "Disk /dev/"|grep -v "/dev/mapper/"|awk '{sum+=$3} END {print sum}'`
    echo "<h4><b>Raw Capacity(GB):$raw</b></h4>"
    ssh $n df -k|grep /dev|grep -v devtmpfs|grep -v tmpfs| awk 'BEGIN { format = "%11s %18s %20s \n"
             printf format, "Allocated(GB)", "Used(GB)", "Available(GB)"
             printf format, "-------------", "--------", "-------------" }
    {sum2+=$2;sum3+=$3;sum4+=$4}END {printf  format, int(sum2/(1024*1024)),int(sum3/(1024*1024)),int(sum4/(1024*1024))}'
    printf "</td> </pre>"
done
printf "</tr> </table>"
ex -s -c '1d3|x' /opt/k8health/worker_nodes
x=$(cat /opt/k8health/worker_nodes|wc -l)
done
printf "<hr/><h1 align=center><strong><span style="color:navy">USE CASE UTILIZATION - $environment : $dmy</span></strong></h1><h4 align=center><strong><span style="color:navy">(cpu,mem,gpu,storage)</span></strong></h4> <hr/>"
cat /opt/k8health/automate/ns_cpu_mem_pvc_report.csv|column -t -s,
printf "<hr/></pre></html>"



-------------------------



#!/usr/bin/ksh
/opt/k8health/prod_html_k8_utilization.sh > /opt/k8health/utilization.html
dmy=$(date +%d-%m-%Y)
export MAILTO="vamsi.x.sadanala@kp.org,farista.p.singh@kp.org,EOTMLPlatform@KaiserPermanente.onmicrosoft.com,Murali.X.Boyapati@kp.org,Satheeskumar.X.S@kp.org,Lakkidi.X.Yoganjaneya@kp.org,Uday.X.Naik@kp.org,Jasbir.Sidhu@kp.org"
export CONTENT="/opt/k8health/utilization.html"
export SUBJECT="K8-PROD: NODE & USE CASE UTILIZATION REPORT - $dmy"
(
 echo "Subject: $SUBJECT"
 echo "MIME-Version: 1.0"
 echo "Content-Type: text/html"
 echo "Content-Disposition: inline"
 cat $CONTENT
) | /usr/sbin/sendmail $MAILTO
