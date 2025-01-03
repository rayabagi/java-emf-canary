FROM openjdk:21-jdk-slim
RUN mkdir /app
COPY app/build/libs/*.jar /app/agent.jar
ENV JAVA_OPTS=""
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS -Djava.security.egd=file:/dev/./urandom -jar /app/agent.jar" ]