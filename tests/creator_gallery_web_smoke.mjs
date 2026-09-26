import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir } from 'node:fs/promises';
import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

function canonicalJson(value) {
  if (Array.isArray(value)) return '[' + value.map(canonicalJson).join(',') + ']';
  if (value && typeof value === 'object') {
    return '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonicalJson(value[key])).join(',') + '}';
  }
  return JSON.stringify(value);
}

const publicationId = 'pub_' + '1'.repeat(32);
const apiPrefix = '/v1/sharing/publications';
const browser = await chromium.launch(launchOptions);
const pageErrors = [];
let mode = 'unavailable';
let downloadedJson = '';
let manifest = null;
let count = { browse: 0, detail: 0, revision: 0, download: 0, unexpected: 0 };
let tamperPackage = false;

try {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, acceptDownloads: true });
  const page = await context.newPage();
  const visualCaptureDir = (process.env.CREATOR_GALLERY_CAPTURE_DIR ?? '').trim();
  const visualCaptures = [];
  async function captureGallery(name) {
    if (!visualCaptureDir) return;
    await mkdir(visualCaptureDir, { recursive: true });
    await page.screenshot({ path: `${visualCaptureDir}/${name}.png`, animations: 'disabled' });
    visualCaptures.push(name);
  }
  page.on('pageerror', error => pageErrors.push(error.message));

  await page.route('**/v1/sharing/publications**', async route => {
    const request = route.request();
    const url = new URL(request.url());
    const headers = { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' };
    if (request.method() !== 'GET' || !url.pathname.startsWith(apiPrefix)) {
      count.unexpected += 1;
      return route.fulfill({ status: 405, headers, body: JSON.stringify({ ok: false, code: 'METHOD_NOT_ALLOWED' }) });
    }
    if (mode === 'unavailable') {
      return route.fulfill({ status: 503, headers, body: JSON.stringify({ ok: false, code: 'REPOSITORY_UNAVAILABLE' }) });
    }
    const pathname = url.pathname;
    if (pathname === apiPrefix) {
      count.browse += 1;
      const cursor = url.searchParams.get('cursor');
      if (mode === 'oversized') {
        return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, items: Array.from({ length: 21 }, () => manifest), next_cursor: null }) });
      }
      if (mode === 'stalled') {
        return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, items: [], next_cursor: 'bzox' }) });
      }
      if (mode === 'repeat') {
        return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, items: [manifest], next_cursor: 'bzox' }) });
      }
      if (mode === 'bounded') {
        const pageIndex = cursor === null ? 0 : Number(cursor.slice(1));
        assert.ok(Number.isInteger(pageIndex) && pageIndex >= 0 && pageIndex < 5 && (cursor === null || cursor === 'p' + pageIndex));
        const items = Array.from({ length: 20 }, (_, i) => ({
          ...manifest,
          publication_id: 'pub_' + String(pageIndex * 20 + i + 1).padStart(32, '0')
        }));
        return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, items, next_cursor: 'p' + (pageIndex + 1) }) });
      }
      return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, items: [manifest], next_cursor: null }) });
    }
    if (pathname === apiPrefix + '/' + publicationId) {
      count.detail += 1;
      return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, manifest, revisions: [1] }) });
    }
    if (pathname === apiPrefix + '/' + publicationId + '/revisions/1') {
      count.revision += 1;
      return route.fulfill({ status: 200, headers, body: JSON.stringify({ ok: true, manifest }) });
    }
    if (pathname === apiPrefix + '/' + publicationId + '/revisions/1/package') {
      count.download += 1;
      const response = tamperPackage
        ? downloadedJson.replace('"package_version":1', '"package_version":2')
        : downloadedJson;
      return route.fulfill({ status: 200, headers, body: response });
    }
    count.unexpected += 1;
    return route.fulfill({ status: 404, headers, body: JSON.stringify({ ok: false, code: 'NOT_FOUND' }) });
  });

  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  assert.equal(response?.ok(), true, 'Creator Web page must load');
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorGalleryReady === 'true' &&
      document.documentElement.dataset.creatorPackageReady === 'true' &&
      document.documentElement.dataset.creatorPackageCanExport === 'true' &&
      typeof window.customFighterCreatorOpenGallery === 'function' &&
      typeof window.customFighterCreatorGalleryRefresh === 'function' &&
      typeof window.customFighterCreatorGalleryNext === 'function' &&
      typeof window.customFighterCreatorGallerySelect === 'function' &&
      typeof window.customFighterCreatorGalleryConfirmImport === 'function',
    null, { timeout: 60_000 }
  );

  await page.evaluate(() => window.customFighterCreatorExportPackage());
  await page.waitForFunction(() => Number(document.documentElement.dataset.creatorPackageExportCount || '0') >= 1 &&
    typeof window.customFighterLastPackageJson === 'string', null, { timeout: 15_000 });
  const initialName = await page.evaluate(() => document.documentElement.dataset.creatorDraftName);
  const pkg = JSON.parse(await page.evaluate(() => window.customFighterLastPackageJson));
  assert.ok([1, 2].includes(pkg.schema_version), 'Creator export must use supported package schema');
  downloadedJson = canonicalJson(pkg);
  const bytes = Buffer.byteLength(downloadedJson, 'utf8');
  manifest = {
    manifest_schema_version: 1,
    publication_id: publicationId,
    package_id: pkg.package_id,
    package_version: pkg.package_version,
    package_schema_version: pkg.schema_version,
    revision: 1,
    content_sha256: createHash('sha256').update(downloadedJson, 'utf8').digest('hex'),
    byte_size: bytes,
    title: 'Gallery Safe Demo',
    description: 'Immutable test publication',
    tags: ['starter'],
    publisher_id: '123e4567-e89b-42d3-a456-426614174000',
    created_at: '2026-09-26T00:00:00Z',
    updated_at: '2026-09-26T00:00:00Z'
  };

  // A missing durable production provider must show a non-destructive unavailable state.
  await page.evaluate(() => window.customFighterCreatorOpenGallery());
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryOpen === 'true' &&
    document.documentElement.dataset.creatorGalleryStatus === 'unavailable', null, { timeout: 15_000 });
  await captureGallery('01-provider-unavailable');
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorGalleryImportStatus), 'idle');

  // Malformed pages fail closed without adding rows or changing the Creator draft.
  for (const malformedMode of ['oversized', 'stalled']) {
    mode = malformedMode;
    await page.evaluate(() => window.customFighterCreatorOpenGallery());
    await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryStatus === 'blocked' &&
      document.documentElement.dataset.creatorGalleryItems === '0', null, { timeout: 15_000 });
    assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);
  }

  // Repeated cursor must never append a duplicate page.
  mode = 'repeat';
  await page.evaluate(() => window.customFighterCreatorOpenGallery());
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryStatus === 'ready' &&
    document.documentElement.dataset.creatorGalleryItems === '1', null, { timeout: 15_000 });
  await page.evaluate(() => window.customFighterCreatorGalleryNext());
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryStatus === 'blocked' &&
    document.documentElement.dataset.creatorGalleryItems === '1', null, { timeout: 15_000 });
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);

  // A real-looking multi-page catalog stops at the explicit 100-item view limit.
  mode = 'bounded';
  await page.evaluate(() => window.customFighterCreatorGalleryRefresh());
  for (let pageNumber = 1; pageNumber <= 5; pageNumber += 1) {
    await page.waitForFunction(expected => document.documentElement.dataset.creatorGalleryStatus === 'ready' &&
      document.documentElement.dataset.creatorGalleryItems === String(expected), pageNumber * 20, { timeout: 15_000 });
    if (pageNumber < 5) await page.evaluate(() => window.customFighterCreatorGalleryNext());
  }
  const browsesAtLimit = count.browse;
  await page.evaluate(() => window.customFighterCreatorGalleryNext());
  assert.equal(count.browse, browsesAtLimit, 'Next must be disabled after 100 visible records');
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);

  mode = 'ready';
  await page.evaluate(() => window.customFighterCreatorGalleryRefresh());
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryStatus === 'ready' &&
    document.documentElement.dataset.creatorGalleryItems === '1', null, { timeout: 15_000 });
  await captureGallery('02-catalog-list');
  await page.evaluate(() => window.customFighterCreatorGallerySelect(0));
  await page.waitForFunction(id => document.documentElement.dataset.creatorGalleryStatus === 'ready' &&
    document.documentElement.dataset.creatorGallerySelectedPublication === id, publicationId, { timeout: 15_000 })
    .catch(async error => {
      console.error('CREATOR_GALLERY_SELECTION_DIAGNOSTIC=' + JSON.stringify({
        state: await page.evaluate(() => ({ ...document.documentElement.dataset })),
        requests: count,
        pageErrors
      }));
      throw error;
    });

  await captureGallery('03-publication-details');
  // Diagnostic bridge must show the *same* cancellable dialog as the real UI.
  // Opening it and cancelling must not request any immutable content or mutate draft.
  async function openImportDialog() {
    await page.evaluate(() => window.customFighterCreatorGalleryConfirmImport());
    await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryConfirmationVisible === 'true', null, { timeout: 10_000 });
  }
  await openImportDialog();
  await captureGallery('03-confirmation-dialog');
  assert.equal(count.revision, 0, 'Opening confirmation must not request a revision');
  assert.equal(count.download, 0, 'Opening confirmation must not download a package');
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryConfirmationVisible === 'false', null, { timeout: 10_000 });
  assert.equal(count.revision, 0, 'Cancelling must not request a revision');
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);

  // Only a real UI acceptance event is allowed to start package download/import.
  await openImportDialog();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryImportStatus === 'valid' &&
    document.documentElement.dataset.creatorGalleryStatus === 'imported' &&
    Number(document.documentElement.dataset.creatorPackageImportCount || '0') >= 1, null, { timeout: 20_000 });
  await captureGallery('04-imported');
  const importCount = await page.evaluate(() => Number(document.documentElement.dataset.creatorPackageImportCount));
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);

  tamperPackage = true;
  await openImportDialog();
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.documentElement.dataset.creatorGalleryImportStatus === 'blocked' &&
    document.documentElement.dataset.creatorGalleryStatus === 'blocked', null, { timeout: 20_000 });
  await captureGallery('05-tampered-blocked');
  assert.equal(await page.evaluate(() => Number(document.documentElement.dataset.creatorPackageImportCount)), importCount);
  assert.equal(await page.evaluate(() => document.documentElement.dataset.creatorDraftName), initialName);
  assert.ok(count.browse >= 1 && count.detail >= 1 && count.revision >= 2 && count.download >= 2);
  assert.equal(count.unexpected, 0, 'Only bounded GET sharing routes may be called');
  assert.deepEqual(pageErrors, [], 'No uncaught browser JS error expected');
  if (visualCaptureDir) {
    assert.deepEqual(visualCaptures, [
      '01-provider-unavailable', '02-catalog-list', '03-publication-details',
      '03-confirmation-dialog', '04-imported', '05-tampered-blocked'
    ]);
    console.log('CREATOR_GALLERY_VISUAL_CAPTURED count=6 source=mock-catalog no-live-provider=true');
  }
  console.log('CREATOR_GALLERY_BROWSER_SMOKE_PASSED unavailable=true metadataOnly=true exactRevision=true digestVerified=true tamperedRejected=true existingCreatorImport=true paginationBounded=true');
} finally {
  await browser.close();
}
