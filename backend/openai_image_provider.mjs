const OPENAI_IMAGE_URL = 'https://api.openai.com/v1/images/generations';

export class OpenAiImageProvider {
  constructor({ apiKey = process.env.OPENAI_API_KEY, fetchImpl = fetch, model = process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2' } = {}) {
    this.apiKey = apiKey || '';
    this.fetchImpl = fetchImpl;
    this.model = model;
  }

  async generate(prompt) {
    if (!this.apiKey) throw new Error('OPENAI_API_KEY is not configured');
    const response = await this.fetchImpl(OPENAI_IMAGE_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: this.model,
        prompt,
        size: '1024x1024',
        output_format: 'png'
      }),
      signal: AbortSignal.timeout(120000)
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = body?.error?.message || `OpenAI image request failed with HTTP ${response.status}`;
      throw new Error(message);
    }
    const encoded = body?.data?.[0]?.b64_json;
    if (!encoded || typeof encoded !== 'string') throw new Error('OpenAI image response did not contain b64_json');
    return Buffer.from(encoded, 'base64');
  }
}
