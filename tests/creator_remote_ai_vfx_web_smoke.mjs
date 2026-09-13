import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({ headless: true });

async function openVfx(page, endpoint) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'vfx');
  url.searchParams.set('ai_vfx_provider', 'remote_ai_vfx');
  url.searchParams.set('ai_vfx_endpoint', endpoint);
  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`VFX URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxReady === 'true',
    null,
    { timeout: 60_000 },
  );
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await openVfx(page, 'https://ai.example.com/v1/vfx/generate');
  const provider = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxProvider ?? '');
  if (provider !== 'remote_ai_vfx') throw new Error(`Expected remote provider, got ${provider}`);

  await openVfx(page, 'http://ai.example.com/v1/vfx/generate');
  const rejectedProvider = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxProvider ?? '');
  const status = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxLastStatus ?? '');
  const error = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxError ?? '');
  if (rejectedProvider !== 'mock_ai_vfx') throw new Error(`Unsafe endpoint must fall back to mock, got ${rejectedProvider}`);
  if (status !== 'error' || !error.includes('https URL')) throw new Error(`Unsafe endpoint was not reported: ${status} ${error}`);
  console.log('WEB_CREATOR_REMOTE_AI_VFX_SMOKE_PASSED');
} finally {
  await browser.close();
}
