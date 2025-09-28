# Start from the same n8n image you are using
FROM docker.n8n.io/n8nio/n8n:next

# Switch to the root user to get permissions to install
USER root

# Install the package globally so n8n can find it
# RUN npm install -g chrono-node
# RUN npm install -g luxon

# Switch back to the low-privilege node user for security
USER node