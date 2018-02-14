FROM feelpp/feelpp-toolboxes

USER root
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN bash -c "echo 'feelpp:feelpp' | chpasswd"
# RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# # SSH login fix. Otherwise user is kicked off after login
# RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# ENV NOTVISIBLE "in users profile"
# RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22
#RUN bash -c "echo 'sudo service ssh start' >> /usr/local/bin/start.sh"
#RUN bash -c "echo 'sudo service ssh start' > /usr/local/bin/start_ssh.sh"

ARG SGE_MASTER_HOSTNAME=feelpp

RUN set -x \
    # Configure the master hostname for Grid Engine
    && echo "gridengine-master       shared/gridenginemaster string  $SGE_MASTER_HOSTNAME" | sudo debconf-set-selections \
    && echo "gridengine-master       shared/gridenginecell   string  default" | sudo debconf-set-selections \
    && echo "gridengine-master       shared/gridengineconfig boolean false" | sudo debconf-set-selections \
    && echo "gridengine-common       shared/gridenginemaster string  $SGE_MASTER_HOSTNAME" | sudo debconf-set-selections \
    && echo "gridengine-common       shared/gridenginecell   string  default" | sudo debconf-set-selections \
    && echo "gridengine-common       shared/gridengineconfig boolean false" | sudo debconf-set-selections \
    && echo "gridengine-client       shared/gridenginemaster string  $SGE_MASTER_HOSTNAME" | sudo debconf-set-selections \
    && echo "gridengine-client       shared/gridenginecell   string  default" | sudo debconf-set-selections \
    && echo "gridengine-client       shared/gridengineconfig boolean false" | sudo debconf-set-selections \
    # Postfix mail server is also installed as a dependency
    && echo "postfix postfix/main_mailer_type        select  No configuration" | sudo debconf-set-selections \
    # Install Grid Engine
    && DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-master gridengine-client gridengine-exec \
    # Set up Grid Engine
    && sudo -u sgeadmin /usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin \
    && service gridengine-master restart \
    # Disable Postfix
    && service postfix stop \
    && update-rc.d postfix disable

COPY scheduler_template /etc/sge-feelpp/scheduler_template
COPY queue_template /etc/sge-feelpp/queue_template
COPY sge-worker-add.sh /etc/sge-feelpp/sge-worker-add.sh
COPY sge-worker-remove.sh /etc/sge-feelpp/sge-worker-remove.sh
COPY start_sge.sh /etc/sge-feelpp/start_sge.sh


RUN sed -i '$ i echo "user:user" | chpasswd' /usr/local/bin/start.sh
RUN sed -i '$ i sudo service ssh start' /usr/local/bin/start.sh
RUN sed -i '$ i /etc/sge-feelpp/start_sge.sh' /usr/local/bin/start.sh
#RUN bash -c "echo 'echo HHHHHHHHHHHHH' >> /usr/local/bin/start.sh"
#RUN bash -c "echo 'sudo service ssh start' >> /usr/local/bin/start.sh"
#RUN bash -c "echo '/etc/sge-feelpp/start_sge.sh' >> /usr/local/bin/start.sh"

##CMD ["/usr/local/bin/start.sh"]
