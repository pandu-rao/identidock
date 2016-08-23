from python:3.4

run groupadd -r uwsgi && useradd -r -g uwsgi uwsgi
run pip install flask==0.10.1 redis==2.10.3 requests==2.5.1 uwsgi==2.0.8

workdir /app
copy app /app
copy cmd.sh /

expose 9090 9191
user uwsgi

cmd ["/cmd.sh"]