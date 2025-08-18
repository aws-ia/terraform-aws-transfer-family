FROM public.ecr.aws/lambda/python:3.9-x86_64

# Install zip utility
RUN yum install -y zip

# Install paramiko and dependencies
RUN pip install paramiko -t /opt/python/

# Create the layer zip
RUN cd /opt && zip -r /tmp/paramiko-layer.zip python/

# Copy the zip file to a volume mount point
CMD ["cp", "/tmp/paramiko-layer.zip", "/output/"]
