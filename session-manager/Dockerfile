FROM node:18-alpine

WORKDIR /app

# Copy and install dependencies first
COPY package.json .
RUN npm install

# Copy the server file
COPY server.js .

# Create logs directory inside container
RUN mkdir -p /logs /scripts

EXPOSE 3000

CMD ["node", "server.js"]