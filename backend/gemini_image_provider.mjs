const GEMINI_INTERACTIONS_URL = 'https://generativelanguage.googleapis.com/v1beta/interactions';

function extractImageBase64(body) {
  if (body?.output_image?.data && typeof body.output_image.data === 'string') {
    return body.output_image.data;
  }
  for (const step of Array.isArray(body?.steps) ? body.steps : []) {
    if (step?.type !== 'model_output') continue;
    for (const block of Array.isArray(step?.content) ? step.content : []) {
      if (block?.type === 'image' && typeof block.data === 'string' && block.data) {
        return block.data;
      }
    }
  }
  return '';
}

export class GeminiImageProvider {
  constructor({ apiKey = process.env.GEMINI_API_KEY, fetchImpl = fetch, model = process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image' } = {}) {
    this.apiKey = apiKey || '';
    this.fetchImpl = fetchImpl;
    this.model = model;
  }

  async generate(prompt, { referencePng = null } = {}) {
    if (!this.apiKey) throw new Error('GEMINI_API_KEY is not configured');
    const input = [{ type: 'text', text: prompt }];
    if (referencePng && referencePng.length) {
      input.push({
        type: 'image',
        mime_type: 'image/png',
        data: Buffer.from(referencePng).toString('base64')
      });
    }

    const response = await this.fetchImpl(GEMINI_INTERACTIONS_URL, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: this.model,
        input,
        response_format: {
          type: 'image',
          aspect_ratio: '1:1'
        }
      }),
      signal: AbortSignal.timeout(120000)
    });

    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = body?.error?.message || `Gemini image request failed with HTTP ${response.status}`;
      throw new Error(message);
    }
    const encoded = extractImageBase64(body);
    if (!encoded) throw new Error('Gemini image response did not contain image data');
    return Buffer.from(encoded, 'base64');
  }
}
