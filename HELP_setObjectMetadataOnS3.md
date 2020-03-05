Execute with --apply to execute final command and set HTTP header. View logs in success.out and error.out.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition" "attachment; filename=\"example.jpeg\"" --apply
$ ./setObjectMetadataOnS3.sh "Content-Disposition" "attachment; filename=\"example.jpeg\"" -a
```

Execute without --apply to generate final command to set HTTP header. View result in script.out.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition" "attachment; filename=\"example.jpeg\""
```

Execute to only one bucket.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition"="attachment; filename=\"example.jpeg\"" -b="bucket.aws.com"
```

Execute to many headers.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition"="attachment; filename=\"example.jpeg\"" "Header2"="Value2" "Header3"="Value3"
```

Execute with max-items per bucket filter.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition"="attachment; filename=\"example.jpeg\"" -b="bucket.aws.com" -m=100
$ ./setObjectMetadataOnS3.sh "Content-Disposition"="attachment; filename=\"example.jpeg\"" -b="bucket.aws.com" --max-items=100
```