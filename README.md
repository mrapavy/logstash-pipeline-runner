# logstash-pipeline-runner
Dockerized logstash with custom Cassandra event-store input and output plugins

# Open ports (inhereted from the base image)
* 9600
* 5044

# In derived images:
* `FROM mrapavy/logstash-pipeline-runner:8.4.3`
* Mount-bind the pipeline definition file to /usr/share/logstash/pipeline/logstash.conf
* Configure logstash using environment variables (`ENV`): https://github.com/elastic/logstash-docker/blob/master/build/logstash/env2yaml/env2yaml.go#L50-L108
