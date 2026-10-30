import { describe, expect, it } from 'vitest'
import type { APIGatewayProxyEventV2 } from 'aws-lambda'
import { handler } from './handler.ts'

function request(method: string, path: string, query?: Record<string, string>) {
  return {
    rawPath: path,
    queryStringParameters: query,
    requestContext: { http: { method, path } },
  } as unknown as APIGatewayProxyEventV2
}

describe('handler', () => {
  it('reports health', async () => {
    const response = await handler(request('GET', '/health'))

    expect(response.statusCode).toBe(200)
    expect(response.headers?.['content-type']).toBe('application/json')
    expect(JSON.parse(response.body ?? '')).toEqual({ status: 'ok' })
  })

  it('greets by name', async () => {
    const response = await handler(request('GET', '/hello', { name: 'Ada' }))

    expect(JSON.parse(response.body ?? '')).toEqual({ message: 'Hello, Ada!' })
  })

  it('greets the world by default', async () => {
    const response = await handler(request('GET', '/hello'))

    expect(JSON.parse(response.body ?? '')).toEqual({ message: 'Hello, world!' })
  })

  it('answers unknown routes with 404', async () => {
    const response = await handler(request('POST', '/health'))

    expect(response.statusCode).toBe(404)
  })
})
