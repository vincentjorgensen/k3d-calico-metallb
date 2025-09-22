```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=any domain/CN=*' -keyout root.key -out root.crt
```
