FROM postgres:13.4
RUN apt install curl ca-certificates gnupg && \
	curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null  && \
	echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
	apt update  && \
	apt-get -y install postgresql-13-cron