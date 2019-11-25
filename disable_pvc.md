Disabling the PersistentVolumeClaim in Consul server StatefulSet. An example with the changes below are shown in this file: [server-statefulset-nopvc.yaml](server-statefulset-nopvc.yaml).

1. In the generated `server-statefulset.yaml` file, add a new Data volume under volumes.
```
volumes:
  - name: data
    emptyDir: {}
```

2. Under volumeMounts, rename the /consul/data mount from data-default to data:
```
volumeMounts:
  - name: data
    mountPath: /consul/data
```

3. Comment out the volumeClaimTemplates section from the bottom of server-statefulset.yaml
```
  # volumeClaimTemplates:
  #   - metadata:
  #       name: data-default
  #     spec:
  #       accessModes:
  #         - ReadWriteOnce
  #       resources:
  #         requests:
  #           storage: 10Gi
```
4. Save the changes
