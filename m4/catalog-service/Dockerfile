FROM registry.access.redhat.com/ubi8/openjdk-11:latest
USER root
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} /tmp/src/app.jar
RUN chown -R 185:0 /tmp/src
USER 185
RUN /usr/local/s2i/assemble
CMD /usr/local/s2i/run