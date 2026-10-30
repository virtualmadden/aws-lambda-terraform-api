import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
} from 'aws-lambda'

type Result = APIGatewayProxyStructuredResultV2
type Route = (event: APIGatewayProxyEventV2) => Result | Promise<Result>

// API Gateway sends every request here (its $default route), so routing lives in code:
// add a "METHOD /path" key to add an endpoint.
const routes: Record<string, Route> = {
  'GET /health': () => json(200, { status: 'ok' }),
  'GET /hello': (event) =>
    json(200, { message: `Hello, ${event.queryStringParameters?.name ?? 'world'}!` }),
}

export async function handler(event: APIGatewayProxyEventV2): Promise<Result> {
  const { method, path } = event.requestContext.http
  const route = routes[`${method} ${path}`]
  if (!route) {
    return json(404, { message: 'Not found' })
  }

  try {
    return await route(event)
  } catch (error) {
    // Logged to CloudWatch with the request ID; the caller only sees a generic error.
    console.error(error)
    return json(500, { message: 'Internal server error' })
  }
}

function json(statusCode: number, body: unknown): Result {
  return {
    statusCode,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
    body: JSON.stringify(body),
  }
}
