FROM node:20
WORKDIR /usr/src/app
COPY package*.json pnpm-lock.yaml ./
RUN npm i -g pnpm && pnpm i
COPY . .
RUN chmod +x tests/banc_test.sh
RUN pnpm run test && pnpm run start
