import sharp from 'sharp';

const GEMINI_INTERACTIONS_URL = 'https://generativelanguage.googleapis.com/v1beta/interactions';
export const DEFAULT_FREE_GEMINI_MODEL = 'gemini-2.5-flash';
export const FREE_GEMINI_MODELS = new Set(['gemini-2.5-flash', 'gemini-2.5-flash-lite']);

const VFX_SCHEMA = {
  type: 'object',
  properties: {
    primary: { type: 'string', description: 'Main RGB hex color, #RRGGBB.' },
    secondary: { type: 'string', description: 'Secondary RGB hex color, #RRGGBB.' },
    accent: { type: 'string', description: 'Accent RGB hex color, #RRGGBB.' },
    shape: { type: 'string', enum: ['orb', 'slash', 'burst'] },
    glow: { type: 'number', minimum: 0.2, maximum: 1.0 },
    particles: { type: 'integer', minimum: 0, maximum: 12 }
  },
  required: ['primary', 'secondary', 'accent', 'shape', 'glow', 'particles'],
  additionalProperties: false
};

function extractOutputText(body) {
  if (typeof body?.output_text === 'string' && body.output_text.trim()) return body.output_text;
  for (const step of Array.isArray(body?.steps) ? body.steps : []) {
    if (step?.type !== 'model_output') continue;
    for (const block of Array.isArray(step?.content) ? step.content : []) {
      if (block?.type === 'text' && typeof block.text === 'string' && block.text.trim()) return block.text;
    }
  }
  return '';
}
function normalizeSpec(text) {
  const parsed = JSON.parse(text);
  const hex = value => /^#[0-9a-f]{6}$/i.test(String(value || '')) ? String(value) : null;
  const primary = hex(parsed.primary);
  const secondary = hex(parsed.secondary);
  const accent = hex(parsed.accent);
  if (!primary || !secondary || !accent) throw new Error('Gemini VFX design returned invalid colors');
  if (!['orb', 'slash', 'burst'].includes(parsed.shape)) throw new Error('Gemini VFX design returned invalid shape');
  const glow = Math.min(1, Math.max(0.2, Number(parsed.glow)));
  const particles = Math.min(12, Math.max(0, Math.trunc(Number(parsed.particles))));
  if (!Number.isFinite(glow) || !Number.isFinite(particles)) throw new Error('Gemini VFX design returned invalid numeric values');
  return { primary, secondary, accent, shape: parsed.shape, glow, particles };
}

function shapeMarkup(spec) {
  if (spec.shape === 'slash') {
    return '<path d="M28 182 Q112 38 230 74 Q158 116 56 220 Z" fill="url(#g)"/>';
  }
  if (spec.shape === 'burst') {
    return '<polygon points="128,18 151,83 221,55 176,112 242,134 174,151 216,214 151,176 128,242 105,176 40,214 82,151 14,134 80,112 35,55 105,83" fill="url(#g)"/>';
  }
  return '<circle cx="128" cy="128" r="82" fill="url(#g)"/><circle cx="102" cy="96" r="26" fill="#ffffff" fill-opacity="0.45"/>';
}

function renderSvg(spec) {
  const blur = (3 + spec.glow * 9).toFixed(2);
  const particleMarkup = Array.from({ length: spec.particles }, (_, index) => {
    const angle = (index / Math.max(1, spec.particles)) * Math.PI * 2;
    const x = (128 + Math.cos(angle) * 104).toFixed(1);
    const y = (128 + Math.sin(angle) * 104).toFixed(1);
    return `<circle cx="${x}" cy="${y}" r="5" fill="${spec.accent}" fill-opacity="0.85"/>`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
    <defs>
      <radialGradient id="g"><stop offset="0" stop-color="${spec.accent}"/><stop offset="0.55" stop-color="${spec.primary}"/><stop offset="1" stop-color="${spec.secondary}" stop-opacity="0.15"/></radialGradient>
      <filter id="blur"><feGaussianBlur stdDeviation="${blur}"/></filter>
    </defs>
    <g filter="url(#blur)" opacity="0.55">${shapeMarkup(spec)}</g>
    <g>${shapeMarkup(spec)}</g>
    <g>${particleMarkup}</g>
  </svg>`;
}

export class GeminiImageProvider {
  constructor({ apiKey = process.env.GEMINI_API_KEY, fetchImpl = fetch, model = process.env.GEMINI_MODEL || DEFAULT_FREE_GEMINI_MODEL, freeTierOnly = process.env.GEMINI_FREE_TIER_ONLY } = {}) {
    this.apiKey = apiKey || '';
    this.fetchImpl = fetchImpl;
    this.model = String(model || '').trim();
    this.freeTierOnly = freeTierOnly === true || String(freeTierOnly || '').trim().toLowerCase() === 'true';
    if (!this.freeTierOnly) {
      throw new Error('GEMINI_FREE_TIER_ONLY=true is required for production AI');
    }
    if (!FREE_GEMINI_MODELS.has(this.model)) {
      throw new Error(`GEMINI_MODEL must use an approved free-tier model; got ${this.model || '(empty)'}`);
    }
  }

  async generate(prompt, { referencePng = null } = {}) {
    if (!this.apiKey) throw new Error('GEMINI_API_KEY is not configured');
    const input = [{
      type: 'text',
      text: `Design a safe 2D fighting-game VFX from this request: ${String(prompt).trim()}. Return only the requested structured design fields; do not return code.`
    }];
    if (referencePng && referencePng.length) {
      input.push({ type: 'image', mime_type: 'image/png', data: Buffer.from(referencePng).toString('base64') });
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
          type: 'text',
          mime_type: 'application/json',
          schema: VFX_SCHEMA
        }
      }),
      signal: AbortSignal.timeout(120000)
    });

    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = body?.error?.message || `Gemini free-tier request failed with HTTP ${response.status}`;
      throw new Error(message);
    }
    const text = extractOutputText(body);
    if (!text) throw new Error('Gemini free-tier response did not contain structured text');
    const spec = normalizeSpec(text);
    return sharp(Buffer.from(renderSvg(spec))).png().toBuffer();
  }
}
