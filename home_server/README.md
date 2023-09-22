## Installing gitlab and gitlab runner on local home server.

## Gitlab community edition install 
```
apt-get install -y curl openssh-server ca-certificates tzdata perl
curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
chmod +x script.deb.sh
./script.deb.sh
apt install gitlab-ce
```

## Openssl keys for local domain gitlab.local
- gitlab will be accessible under local domain gitlab.local through https protocol
- generate root certificate and key file
```
openssl genrsa -aes256 -out rootCA.key 4096
openssl req -x509 -new -nodes -key your_rootCA.key -sha256 -days 3650 -out your_rootCA.crt -subj '/CN=Your Root CA/C=RU/ST=YourState/L=RU/O=Your Organization'
```
- generate certificate for domain gitlab.local
```
openssl req -new -nodes -out ubuntu-home.csr -newkey rsa:4096 -keyout ubuntu-home.key -subj '/CN=Gitlab Server/C=RU/ST=YourState/L=YourCity/O=Your Organization'
```
- sign certificate. Should be signed using SAN extention in file gitlab.v3.ext, otherwise runner won't connect to gitlab instance. 
```
openssl x509 -req -in ubuntu-home.csr -CA your_rootCA.crt -CAkey your_rootCA.key -CAcreateserial -out ubuntu-home.crt -days 825 -sha256 -extfile gitlab.v3.ext
```
gitlab.v3.ext
```
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = gitlab.local
DNS.2 = localhost
IP.1 = 192.168.0.52
```

- copy certificate to gitlab folder and reconfigure it.
```
cp ubuntu-home.crt /etc/gitlab/ssl/gitlab.local.crt
cp ubuntu-home.key /etc/gitlab/ssl/gitlab.local.key
gitlab-ctl reconfigure
```
- copy certificate to gitlab runner folder, which later will be mounted into container
```
cp ubuntu-home.crt /srv/gitlab-runner/certs/ca.crt
```
## Gitlab


## Gitlab runner
- runner is started in docker container:
```
docker run -d --name gitlab-runner --restart always --network host \
-v /srv/gitlab-runner:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```

