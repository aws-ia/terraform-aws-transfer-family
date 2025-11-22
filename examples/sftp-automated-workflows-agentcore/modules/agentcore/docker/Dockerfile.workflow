FROM public.ecr.aws/docker/library/python:3.12-slim
WORKDIR /app

COPY . .

RUN python -m pip install --no-cache-dir -r requirements.txt

ENV AWS_REGION=us-east-1
ENV AWS_DEFAULT_REGION=us-east-1

RUN useradd -m -u 1000 bedrock_agentcore
USER bedrock_agentcore

EXPOSE 8080

CMD ["python", "-m", "agents.orchestrator.claims_workflow"]
