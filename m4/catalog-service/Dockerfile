FROM registry.access.redhat.com/ubi8/openjdk-11:latest
USER root
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} /tmp/src/app.jar
RUN chown -R 185:0 /tmp/src
USER 185
ENTRYPOINT ["java", "-jar", "/tmp/src/app.jar"] 