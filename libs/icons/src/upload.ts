/** Uploads a PNG as an Image asset through Open Cloud and returns its asset id. */

export const ASSETS = 'https://apis.roblox.com/assets/v1'

export interface Creator {
  userId?: string
  groupId?: string
}

export type Uploader = (png: Buffer, displayName: string) => Promise<string>

type Fetch = typeof fetch

interface Operation {
  path?: string
  operationId?: string
  done?: boolean
  error?: { code?: number | string; message?: string }
  response?: { assetId?: string | number }
}

export function openCloud(
  apiKey: string,
  creator: Creator,
  options: { fetch?: Fetch; wait?: (ms: number) => Promise<void>; timeoutMs?: number } = {},
): Uploader {
  const fetcher = options.fetch ?? fetch
  const wait = options.wait ?? ((ms: number) => new Promise<void>(done => setTimeout(done, ms)))
  const timeout = options.timeoutMs ?? 120_000

  const read = async (response: Response, what: string): Promise<Operation> => {
    const text = await response.text()
    if (!response.ok) throw new Error(`${what} failed (${response.status}): ${text}`)
    return JSON.parse(text) as Operation
  }

  return async (png, displayName) => {
    const form = new FormData()
    form.append(
      'request',
      JSON.stringify({
        assetType: 'Image',
        displayName,
        description: 'Icon sheet made by lucy-icons',
        creationContext: { creator },
      }),
    )
    form.append('fileContent', new Blob([new Uint8Array(png)], { type: 'image/png' }), `${displayName}.png`)
    let operation = await read(
      await fetcher(`${ASSETS}/assets`, { method: 'POST', headers: { 'x-api-key': apiKey }, body: form }),
      'upload',
    )
    const path = operation.path ?? (operation.operationId ? `operations/${operation.operationId}` : undefined)
    const started = Date.now()
    let delay = 500
    while (!operation.done) {
      if (path === undefined) throw new Error('upload returned no operation to wait on')
      if (Date.now() - started > timeout) throw new Error(`upload did not finish within ${timeout / 1000} s`)
      await wait(delay)
      delay = Math.min(delay * 2, 4000)
      operation = await read(await fetcher(`${ASSETS}/${path}`, { headers: { 'x-api-key': apiKey } }), 'upload status')
    }
    if (operation.error) throw new Error(`upload failed: ${operation.error.message ?? JSON.stringify(operation.error)}`)
    const id = operation.response?.assetId
    if (id === undefined) throw new Error('upload finished without an asset id')
    return String(id)
  }
}
