FROM ubuntu:16.04

# Reconstituted from ops/packer/iris.yaml

RUN apt-get update && apt-get -y install sudo

RUN sudo apt-get -y install curl python-pip uwsgi unzip virtualenv sudo python-dev libyaml-dev libsasl2-dev libldap2-dev nginx uwsgi-plugin-python uwsgi-plugin-gevent-python mysql-client \
    && sudo rm -rf /var/cache/apt/archives/*
RUN sudo useradd -m -u 10001 -s /bin/bash iris
RUN sudo chown -R iris:iris /home/iris /var/log/nginx /var/lib/nginx
RUN sudo -Hu iris mkdir -p /home/iris/var/log/uwsgi /home/iris/var/log/nginx /home/iris/var/run

ADD ./src /home/iris/source/src
ADD ./setup.py /home/iris/source/setup.py
ADD ./db /home/iris/source/db
ADD ./ops /home/iris/source/ops
ADD ./configs /home/iris/source/configs
ADD ./uid_entrypoint.sh /usr/bin

RUN sudo chown -R iris:iris /home/iris/source
RUN sudo mv /home/iris/source/ops/config/systemd/uwsgi-iris.service /etc/systemd/system/uwsgi-iris.service
RUN sudo mv /home/iris/source/ops/config/systemd/nginx-iris.service /etc/systemd/system/nginx-iris.service
RUN sudo mv /home/iris/source/ops/config/systemd/nginx-iris.socket /etc/systemd/system/nginx-iris.socket

RUN sudo -Hu iris ln -s /home/iris/source/ops/daemons /home/iris/daemons
RUN sudo -Hu iris ln -s /home/iris/source/ops/entrypoint.py /home/iris/entrypoint.py
RUN sudo -Hu iris ln -s /home/iris/source/db /home/iris/db

RUN sudo -Hu iris mkdir /home/iris/config
RUN sudo -Hu iris cp /home/iris/source/configs/config.dev.yaml /home/iris/config/config.yaml

RUN sudo -Hu iris virtualenv /home/iris/env
RUN sudo -Hu iris /bin/bash -c 'source /home/iris/env/bin/activate && cd /home/iris/source && pip install ".[prometheus,kazoo]"'

RUN sudo -Hu iris mv -f /home/iris/daemons/uwsgi-docker.yaml /home/iris/daemons/uwsgi.yaml

EXPOSE 16649
CMD ["bash", "-c", "source /home/iris/env/bin/activate && python /home/iris/entrypoint.py"]
### user name recognition at runtime w/ an arbitrary uid - for OpenShift deployments
RUN chgrp -R root /home/iris /var/log/nginx /var/lib/nginx
RUN chmod -R g=u /etc/passwd /home/iris /var/log/nginx /var/lib/nginx
ENTRYPOINT [ "uid_entrypoint.sh" ]
USER 10001
