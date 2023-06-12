#1. cpu_mem_usage.sh        ##### to collect the cpu, mem, gpu metrics collection - request, limit and usage 
#2. ns_cpu_mem_sum.sh       #####    
#3. namespace_cpu_mem_val_sum.py ##### Python script to sum the values at namespace level [CPU_R  CPU_U  Mem_R(GB)  Mem_U(GB)  CPU_lim  Mem_lim(GB)  GPU_lim]
#4. ns_pvc_util.sh          #### pvc utilization at the namespace level  
#5. ns_pvc_binded.py        #### Python script to sum the values of ns binded pvc values  [ns_size(GB)]
#6. pvc_util_py.py          #### Python script to sum the values in pod binded pvc utilization  [POD_bind_size(GB)  POD_used(GB)]
#7. merge_ns_pvc_util.sh    #### Merging the [ns_size(GB)] &  [POD_bind_size(GB)  POD_used(GB)] in to one single table
#8. final_report_ns_cpu_mem_storage.sh #### Merging step-3 and step-7 values in to single table

================================================
#!/bin/bash
#!/bin/python3

NODESAPI=/api/v1/nodes
file="/opt/k8health/automate/pvcbinded.csv"
/usr/local/bin/kubectl get pvc --all-namespaces|awk '{print $1,$2,$5}'> /opt/k8health/automate/pvcbinded.csv
/usr/local/bin/kubectl get po -o json --all-namespaces | jq -j '.items[] | "\(.metadata.namespace), \(.metadata.name), \(.spec.volumes[].persistentVolumeClaim.claimName)\n"' | grep -v null | cut -d, --output-delimiter ' ' -f 1,2,3 > /opt/k8health/automate/podbinded.csv

ns_pvc_binded()
{
echo "Namespace,PVC,Allocated_Size(GB)"
sed 1d $file|while read line
  do
     ns=$(echo $line | cut -d ' ' -f1)
     pvc=$(echo $line | cut -d ' ' -f2)
         size=$(echo $line | cut -d ' ' -f3)
         size1=${size: -2}
     if [[ "$size1" == "Ti" ]]
     then
         size1=${size::-2}
         size2=$(echo $size1 |awk '{print $1 * 1024}')
         echo $ns,$pvc,$size2
     elif [[ "$size1" == "Gi" ]]
     then
         size2=${size::-2}
         echo $ns,$pvc,$size2
     elif [[ "$size1" == "Ki" ]]
	 then
         size2=$(echo $size |awk '{printf "%.2f",$1 / 1024 / 1024}')
         echo $ns,$pvc,$size2
     else 
	     size2=$(echo $size |awk '{printf "%.2f",$1 / 1024 / 1024 / 1024}')
         echo $ns,$pvc,$size2
     
     fi
 done
}

ns_pvc_binded  >  /opt/k8health/automate/ns_pvc_binded.csv

python3 /opt/k8health/automate/ns_pvc_binded.py > /opt/k8health/automate/ns_pvc_sum.csv

pvc_util()
{
echo "Namespace PVC POD_Binded_Size(GB) Used(GB) Available(GB) Use%"
for i in `/usr/local/bin/kubectl get --raw $NODESAPI | jq -r '.items[].metadata.name'`
do 
/usr/local/bin/kubectl get --raw $NODESAPI/$i/proxy/stats/summary|jq -s '[flatten | .[].pods[].volume[]? | select(has("pvcRef")) | ''{namespace: .pvcRef.namespace, name: .pvcRef.name, capacityBytes, usedBytes, availableBytes, ''percentageUsed: (.usedBytes / .capacityBytes * 100)}] | sort_by(.namespace)'|jq -r '.[] | "\(.namespace) \(.name) \(.capacityBytes) \(.usedBytes) \(.availableBytes) \(.percentageUsed)"'|awk  '{$3 = sprintf("%.2f",$3/(1024*1024*1024)); $4 = sprintf("%.3f",$4/(1024*1024*1024)); $5=sprintf("%.2f",$5/(1024*1024*1024)); $6 = sprintf("%.0f%%",$6); print $0}'
done
}

pvc_util| awk '{print $1,$2,$3,$4}'|(sed -u 1q; sort -u -t " " -k 2,2) > /opt/k8health/automate/pvc_util.csv


python3 /opt/k8health/automate/pvc_util_py.py > /opt/k8health/automate/pvc_util_sum.csv


#######Step-4=>>>>>>>>>merge_ns_pvc_util.sh########
###################################################

file1="/opt/k8health/automate/ns_pvc_sum.csv"
file2="/opt/k8health/automate/pvc_util_sum.csv"
touch x

merge_ns_pvc_util()
{
echo "Namespace,Allocated_Size(GB),POD_Binded_Size(GB),Used(MB)"
sed 1,2d $file1 | while read line1
do
     ns1=$(echo $line1 | awk '{print $1}')
     size1=$(echo $line1 | awk '{print $2}')

     sed 1,2d $file2 | while read line2
         do
              ns2=$(echo $line2 | awk '{print $1}')
                  size2=$(echo $line2 | awk '{printf "%.2f", $2}')
                  used=$(echo $line2 | awk '{printf "%.2f",$3}')
                  if [ "$ns1" == "$ns2" ]
                  then
                       echo $ns1,$size1,$size2,$used
                           rm x
                           break
              else
                       touch x
              fi
         done
  if [ -e x ]
  then
           size3=0
           used=0
           echo $ns1,$size1,$size3,$used
  fi
done
}

merge_ns_pvc_util > /opt/k8health/automate/final_storage_report.csv

###########Step-5=>>>>>final_report_ns_cpu_mem_storage.sh###########
####################################################################
file1="/opt/k8health/automate/final_cpu_mem_report.csv"
file2="/opt/k8health/automate/final_storage_report.csv"
touch x

final_report_ns_cpu_mem_storage()
{
echo "Namespace,CPU_R,CPU_U,Mem_R(GB),Mem_U(GB),CPU_lim,Mem_lim(GB),GPU_lim,ns_size(GB),POD_bind_size(GB),POD_used(GB)"
sed 1,2d $file1 | while read line1
do
    ns1=$(echo $line1 | awk '{print $1}')
    cpu_req=$(echo $line1 | awk '{print $2}')
        cpu_use=$(echo $line1 | awk '{print $3}')
        mem_req=$(echo $line1 | awk '{print $4}')
        mem_use=$(echo $line1 | awk '{print $5}')
        cpu_lim=$(echo $line1 | awk '{print $6}')
        mem_lim=$(echo $line1 | awk '{print $7}')
    gpu_lim=$(echo $line1 | awk '{print $8}')

        sed 1d $file2 | while read line2
        do
              ns2=$(echo $line2 | cut -d , -f1)
                  t_size=$(echo $line2 | cut -d , -f2)
          pod_bind_size=$(echo $line2 | cut -d , -f3)
                  used=$(echo $line2 | cut -d , -f4)

                  if [ "$ns1" == "$ns2" ]
                  then
                       echo $ns1,$cpu_req,$cpu_use,$mem_req,$mem_use,$cpu_lim,$mem_lim,$gpu_lim,$t_size,$pod_bind_size,$used
                           rm x
                           break
              else
                       touch x
              fi
        done

         if [ -e x ]
  then
           t_size=0
           pod_bind_size=0
           used=0
           echo $ns1,$cpu_req,$cpu_use,$mem_req,$mem_use,$cpu_lim,$mem_lim,$gpu_lim,$t_size,$pod_bind_size,$used
  fi

done
}

final_report_ns_cpu_mem_storage > /opt/k8health/automate/ns_cpu_mem_pvc_report.csv
rm /opt/k8health/automate/x

