// Serves the handler on localhost for `yarn dev`, shaping each request like API Gateway's
// HTTP API (payload format 2.0) does. Never deployed.
import { createServer } from 'node:http'
import type { APIGatewayProxyEventV2 } from 'aws-lambda'
import { handler } from './handler.ts'

const port = Number(process.env.PORT ?? 3000)

createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host}`)
  const chunks: Buffer[] = []
  for await (const chunk of req) chunks.push(chunk)
  const body = Buffer.concat(chunks).toString()

  const event = {
    version: '2.0',
    routeKey: '$default',
    rawPath: url.pathname,
    rawQueryString: url.search.slice(1),
    headers: Object.fromEntries(
      Object.entries(req.headers).map(([name, value]) => [name, String(value)]),
    ),
    queryStringParameters: url.search ? Object.fromEntries(url.searchParams) : undefined,
    requestContext: {
      http: {
        method: req.method ?? 'GET',
        path: url.pathname,
        protocol: `HTTP/${req.httpVersion}`,
        sourceIp: req.socket.remoteAddress ?? '',
        userAgent: req.headers['user-agent'] ?? '',
      },
      requestId: crypto.randomUUID(),
      timeEpoch: Date.now(),
    },
    body: body || undefined,
    isBase64Encoded: false,
  } as unknown as APIGatewayProxyEventV2

  const result = await handler(event)
  res.writeHead(result.statusCode ?? 200, result.headers as Record<string, string>)
  res.end(result.body)
}).listen(port, () => {
  console.log(`http://localhost:${port}`)
})
