import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PACKAGE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_PACKAGE_BASE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
try {
  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, acceptDownloads: true });
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator package URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      document.documentElement.dataset.creatorPackageReady === 'true' &&
      typeof window.customFighterCreatorExportPackage === 'function' &&
      typeof window.customFighterCreatorImportPackageJson === 'function' &&
      typeof window.customFighterCreatorSetAnimationMap === 'function' &&
      typeof window.customFighterCreatorSetAnimationSemantic === 'function' &&
      typeof window.customFighterCreatorPreview === 'function' &&
      typeof window.customFighterCreatorTimelineApplyComposition === 'function' &&
      typeof window.customFighterCreatorTimelineClear === 'function' &&
      document.documentElement.dataset.creatorTimelineCompositionReady === 'true',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Package Nova');
    window.customFighterCreatorSetAnimationMap('storm_duelist');
    window.customFighterCreatorSetAnimationSemantic('ready', 'package_ready_custom');
    window.customFighterCreatorSetMaxHp(222);
    window.customFighterCreatorSetSkillName('Package Bolt');
    window.customFighterCreatorSetSkillDamage(41);
    window.customFighterCreatorSetSkillMpCost(19);
    window.customFighterCreatorSetSkillCooldown(2.25);
    window.customFighterCreatorTimelineClear();
    window.customFighterCreatorTimelineApplyComposition('guarded_impact', 0);
  });

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageCanExport === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Package Nova' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftMapId === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorDraftMaxHp === '222' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Package Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '41' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '19' &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true',
    null,
    { timeout: 5_000 },
  );

  // Exercise the production Godot Web bridge directly. Package correctness is
  // proven by app-owned telemetry plus the serialized package itself. Browser
  // download/user-activation policy is intentionally not used as this core gate:
  // Blob downloads initiated through JavaScriptBridge are not exposed
  // deterministically as Playwright download/anchor events in headless engines.
  await page.evaluate(() => window.customFighterCreatorExportPackage());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageExportCount === '1' &&
      Number(document.documentElement.dataset.creatorPackageLastExportBytes) > 100 &&
      typeof window.customFighterLastPackageJson === 'string' &&
      window.customFighterLastPackageJson.length > 100,
    null,
    { timeout: 10_000 },
  );

  const exportedJson = await page.evaluate(() => window.customFighterLastPackageJson);
  const exported = JSON.parse(exportedJson);
  if (exported.schema_version !== 2) throw new Error('Exported package schema_version mismatch');
  if ('vfx_asset' in exported) throw new Error('Package without authored VFX must not emit a vfx_asset');
  if (exported.package_id !== 'my_fighter_001') throw new Error(`Unexpected package_id ${exported.package_id}`);
  if (exported.character?.name !== 'Package Nova') throw new Error('Exported character name mismatch');
  if (exported.character?.animation_map !== 'storm_duelist') throw new Error('Exported animation map mismatch');
  if (exported.animation_map?.id !== 'storm_duelist') throw new Error('Packaged animation map id mismatch');
  if (exported.animation_map?.schema_version !== 1) throw new Error('Packaged animation map schema mismatch');
  if (exported.animation_map?.animations?.ready !== 'package_ready_custom') {
    throw new Error('Custom semantic animation mapping did not serialize');
  }
  if ('script' in exported.animation_map || 'path' in exported.animation_map || 'url' in exported.animation_map) {
    throw new Error('Packaged animation map must remain declarative safe-token data only');
  }
  if (exported.character?.stats?.max_hp !== 222) throw new Error('Exported HP mismatch');
  if (exported.character?.skill_slots?.skill_1 !== 'my_projectile_001') throw new Error('Exported Skill 1 binding mismatch');
  if (!Array.isArray(exported.skills) || exported.skills.length !== 6) throw new Error('Export must contain six referenced skills');
  const exportedSkill1 = exported.skills.find((skill) => skill.id === 'my_projectile_001');
  if (!exportedSkill1 || exportedSkill1.damage !== 41 || exportedSkill1.mp_cost !== 19) {
    throw new Error('Exported authored projectile data mismatch');
  }
  if (!exportedSkill1.timeline || exportedSkill1.timeline.schema_version !== 1 || !Array.isArray(exportedSkill1.timeline.events) || exportedSkill1.timeline.events.length !== 5) {
    throw new Error(`Exported authored timeline mismatch: ${JSON.stringify(exportedSkill1?.timeline)}`);
  }
  if (exportedSkill1.timeline.events.map((event) => event.type).join(',') !== 'animation,vfx,hitbox,audio,hurtbox') {
    throw new Error(`Exported composition vocabulary mismatch: ${JSON.stringify(exportedSkill1.timeline.events)}`);
  }
  if ('composition' in exportedSkill1 || 'composition_recipe' in exportedSkill1 || 'script' in exportedSkill1) {
    throw new Error('Package must persist only expanded declarative timeline events, not executable composition metadata');
  }
  for (const skill of exported.skills) {
    if (skill.id !== 'my_projectile_001' && 'timeline' in skill) {
      throw new Error(`Legacy non-timeline skill shape changed: ${skill.id}`);
    }
  }

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('ready', '../unsafe.gd'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorPackageCanExport === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('safe lowercase token'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Mutated Draft');
    window.customFighterCreatorSetAnimationMap('ember_vanguard');
    window.customFighterCreatorSetAnimationSemantic('ready', 'transient_ready_custom');
    window.customFighterCreatorSetSkillDamage(7);
    window.customFighterCreatorSetSkillMpCost(3);
    window.customFighterCreatorTimelineClear();
  });
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorPackageCanExport === 'true' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3' &&
      document.documentElement.dataset.creatorTimelineCount === '0',
    null,
    { timeout: 5_000 },
  );

  const invalidPackage = JSON.stringify({ ...exported, schema_version: 999 });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), invalidPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('unsupported package schema_version') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3',
    null,
    { timeout: 5_000 },
  );

  const { animation_map: _omittedAnimationMap, ...exportedWithoutAnimationPayload } = exported;
  const missingAnimationPackage = JSON.stringify({
    ...exportedWithoutAnimationPayload,
    character: { ...exported.character, animation_map: 'missing_animation_map' },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), missingAnimationPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('animation map file is empty or missing') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3',
    null,
    { timeout: 5_000 },
  );

  const unsafeAnimationPackage = JSON.stringify({
    ...exported,
    animation_map: {
      ...exported.animation_map,
      animations: { ...exported.animation_map.animations, ready: '../payload.gd' },
    },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), unsafeAnimationPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('safe lowercase token') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), exportedJson);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'valid' &&
      document.documentElement.dataset.creatorPackageImportCount === '1' &&
      document.documentElement.dataset.creatorDraftName === 'Package Nova' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorDraftMaxHp === '222' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Package Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '41' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '19' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.25) < 0.001 &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterName === 'Package Nova' &&
      document.documentElement.dataset.playerAnimationMapLoaded === 'true' &&
      document.documentElement.dataset.playerAnimationMapId === 'storm_duelist' &&
      document.documentElement.dataset.playerAnimationSemantic === 'ready' &&
      document.documentElement.dataset.playerAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationOverrideActive === 'true' &&
      document.documentElement.dataset.playerMaxHp === '222' &&
      document.documentElement.dataset.playerRuntimeSkill1 === 'my_projectile_001' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillDamage === '41' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost === '19',
    null,
    { timeout: 60_000 },
  );

  await page.keyboard.down('u');
  await page.waitForFunction(() => Number(document.documentElement.dataset.playerMp) === 81, null, { timeout: 3_000 });
  await page.keyboard.up('u');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 59 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 5_000 },
  );

  console.log('WEB_CREATOR_PACKAGE_SMOKE_PASSED export=true schema=2 noVfxFallback=true animationMapRoundTrip=true animationPreview=true semanticInvalidExportBlocked=true semanticPackageRoundTrip=true semanticTransientReset=true unsafePackagedAnimationBlocked=true missingAnimationMapBlocked=true timelineRoundTrip=true compositionExpanded=true invalidPreserved=true import=true authoredHp=222 authoredDamage=41 authoredMpCost=19 previewCast=true');
  await page.close();
} finally {
  await browser.close();
}
