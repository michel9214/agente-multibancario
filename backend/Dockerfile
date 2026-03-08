FROM node:20-alpine AS builder

RUN apk add --no-cache openssl

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY prisma ./prisma/
RUN npx prisma generate

COPY . .
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

RUN apk add --no-cache dumb-init openssl

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma

RUN mkdir -p uploads

ENV NODE_ENV=production
EXPOSE 3000

CMD ["dumb-init", "sh", "-c", "npx prisma migrate deploy && node dist/main"]
