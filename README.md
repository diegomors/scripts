# Scripts

### setObjectMetadataOnS3.sh

* You can set only one HTTP header for each execution.

Execute with --apply to execute final command and set HTTP header. View logs in success.out and error.out.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition" "attachment" --apply
```

Execute without --apply to generate final command to set HTTP header. View result in script.out.
```shell
$ ./setObjectMetadataOnS3.sh "Content-Disposition" "attachment"
```
