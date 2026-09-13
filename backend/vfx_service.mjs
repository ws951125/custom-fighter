import sharp from 'sharp';
import { createConfiguredImageProvider } from './image_provider_factory.mjs';

const MAX_PROMPT_CHARS = 1000;
const MAX_FRAMES = 8;
const MAX_FRAME_DIMENSION = 128;
const MAX_OUTPUT_BYTES = 5 * 1024 * 1024;
const MAX_REFERENCE_BYTES = 5 * 1024 * 1024;
const MAX_REFERENCE_DIMENSION = 4096;

function reject(message) {
  return { ok: false, error: message };
}

export function validateVfxRequest(input) {
  if (!input || typeof input !== 'object') return 'request body must be an object';
  if (!/^[a-z0-9][a-z0-9_-]{0,79}$/i.test(String(input.request_id || ''))) return 'request_id is invalid';
  const prompt = String(input.prompt || '').trim();
  if (!prompt || prompt.length > MAX_PROMPT_CHARS) return 'prompt must be between 1 and 1000 characters';
  const frameCount = Number(input.frame_count);
  const frameWidth = Number(input.frame_width);
  const frameHeight = Number(input.frame_height);
  const fps = Number(input.fps);
  if (!Number.isInteger(frameCount) || frameCount < 1 || frameCount > MAX_FRAMES) return 'frame_count is out of range';
  if (!Number.isInteger(frameWidth) || frameWidth < 8 || frameWidth > MAX_FRAME_DIMENSION) return 'frame_width is out of range';
  if (!Number.isInteger(frameHeight) || frameHeight < 8 || frameHeight > MAX_FRAME_DIMENSION) return 'frame_height is out of range';
  if (!Number.isFinite(fps) || fps < 1 || fps > 60) return 'fps is out of range';
  if (input.reference_png_base64 && String(input.reference_mime_type || '').toLowerCase() !== 'image/png') return 'reference image must use image/png';
  return '';
}

function buildStarterSkillProposal(input) {
  const requestId = String(input.request_id);
  return {
    proposal_id: `${requestId}_skill`,
    source_request_id: requestId,
    skill_id: `${requestId}_projectile`,
    skill_name: 'AI Generated Projectile',
    skill_type: 'projectile',
    damage: 24,
    mp_cost: 20,
    cooldown: 1.8,
    startup: 0.22,
    active: 0.08,
    recovery: 0.30,
    speed: 620,
    range: 900,
    hitstun: 0.22,
    knockback: 280,
    hitbox_half_width: 28,
    hitbox_half_depth: 0.08,
    visual: 'prototype_fireball',
    impact_visual: 'prototype_impact',
    rationale: 'Starter proposal derived from the generated VFX request; review and confirm before applying.'
  };
}

async function decodeReference(input) {
  if (!input.reference_png_base64) return null;
  const encoded = String(input.reference_png_base64);
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) throw new Error('reference PNG base64 is invalid');
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.length > MAX_REFERENCE_BYTES) throw new Error('reference PNG exceeds 5 MB limit');
  const metadata = await sharp(bytes).metadata();
  if (metadata.format !== 'png') throw new Error('reference image must decode as PNG');
  if (!metadata.width || !metadata.height || metadata.width > MAX_REFERENCE_DIMENSION || metadata.height > MAX_REFERENCE_DIMENSION) throw new Error('reference PNG dimensions must stay within 4096 px');
  if (Number(input.reference_width || 0) !== metadata.width || Number(input.reference_height || 0) !== metadata.height) throw new Error('reference PNG dimensions do not match request metadata');
  return bytes;
}

export async function createVfxResponse(input, { provider = createConfiguredImageProvider() } = {}) {
  const validationError = validateVfxRequest(input);
  if (validationError) return reject(validationError);
  let referencePng = null;
  try {
    referencePng = await decodeReference(input);
  } catch (error) {
    return reject(String(error?.message || 'reference PNG validation failed'));
  }

  const source = await provider.generate(String(input.prompt).trim(), { referencePng });
  const frameWidth = Number(input.frame_width);
  const frameHeight = Number(input.frame_height);
  const frameCount = Number(input.frame_count);

  const frame = await sharp(source)
    .resize(frameWidth, frameHeight, { fit: 'cover' })
    .png()
    .toBuffer();

  const stripWidth = frameWidth * frameCount;
  const composites = Array.from({ length: frameCount }, (_, index) => ({
    input: frame,
    left: index * frameWidth,
    top: 0
  }));
  const spriteStrip = await sharp({
    create: {
      width: stripWidth,
      height: frameHeight,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 }
    }
  }).composite(composites).png().toBuffer();

  if (spriteStrip.length > MAX_OUTPUT_BYTES) return reject('generated PNG exceeds 5 MB output limit');
  return {
    ok: true,
    request_id: String(input.request_id),
    frame_count: frameCount,
    fps: Number(input.fps),
    png_base64: spriteStrip.toString('base64'),
    skill_proposal: buildStarterSkillProposal(input)
  };
}
