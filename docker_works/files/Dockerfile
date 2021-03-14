FROM tomcat:7.0.108-jdk8
RUN apt update && apt install maven -y
RUN git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello
WORKDIR boxfuse-sample-java-war-hello
RUN mvn package
WORKDIR target
RUN cp hello-1.0.war $CATALINA_HOME/webapps/