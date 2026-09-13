const OPENAI_IMAGE_GENERATION_URL = 'https://api.openai.com/v1/images/generations';
const OPENAI_IMAGE_EDIT_URL = 'https://api.openai.com/v1/images/edits';

export class OpenAiImageProvider {
  constructor({ apiKey = process.env.OPENAI_API_KEY, fetchImpl = fetch, model = process.env.OPENAI_IMAGE_MODEL || 'gpt-image-2' } = {}) {
    this.apiKey = apiKey || '';
    this.fetchImpl = fetchImpl;
    this.model = model;
  }

  async generate(prompt, { referencePng = null } = {}) {
    if (!this.apiKey) throw new Error('OPENAI_API_KEY is not configured');
    if (referencePng && referencePng.length) {
      const form = new FormData();
      form.append('model', this.model);
      form.append('prompt', prompt);
      form.append('size', '1024x1024');
      form.append('output_format', 'png');
      form.append('image', new Blob([referencePng], { type: 'image/png' }), 'reference.png');
      return this.#request(OPENAI_IMAGE_EDIT_URL, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${this.apiKey}` },
        body: form,
        signal: AbortSignal.timeout(120000)
      });
    }
    return this.#request(OPENAI_IMAGE_GENERATION_URL, {
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
  }

  async #request(url, options) {
    const response = await this.fetchImpl(url, options);
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
