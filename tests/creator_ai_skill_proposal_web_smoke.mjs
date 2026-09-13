import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({ headless: true });

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

const proposal = {
  proposal_id: 'proposal_nova_001',
  source_request_id: 'req_nova_001',
  skill_id: 'nova_bolt_001',
  skill_name: 'Nova Bolt',
  skill_type: 'projectile',
  damage: 44,
  mp_cost: 31,
  cooldown: 2.6,
  startup: 0.2,
  active: 0.08,
  recovery: 0.35,
  speed: 760,
  range: 1180,
  hitstun: 0.3,
  knockback: 330,
  hitbox_half_width: 30,
  hitbox_half_depth: 0.08,
  visual: 'prototype_fireball',
  impact_visual: 'prototype_impact',
  rationale: 'Fast ranged pressure with a moderate resource cost.'
};

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'creator');
  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(() =>
    document.documentElement.dataset.creatorAiSkillProposalReady === 'true' &&
    typeof window.customFighterCreatorStageAiSkillProposal === 'function' &&
    typeof window.customFighterCreatorConfirmAiSkillProposal === 'function' &&
    typeof window.customFighterCreatorDiscardAiSkillProposal === 'function',
    null,
    { timeout: 60_000 },
  );

  const beforeDamage = Number(await dataset(page, 'creatorSkillDraftDamage'));
  await page.evaluate((json) => window.customFighterCreatorStageAiSkillProposal(json), JSON.stringify(proposal));
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiSkillProposalValid === 'true', null, { timeout: 5_000 });
  if ((await dataset(page, 'creatorAiSkillProposalConfirmed')) !== 'false') throw new Error('Proposal must require explicit confirmation');
  if (Number(await dataset(page, 'creatorSkillDraftDamage')) !== beforeDamage) throw new Error('Staging proposal mutated SkillDraft before confirmation');

  await page.evaluate(() => window.customFighterCreatorConfirmAiSkillProposal());
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiSkillProposalApplied === 'true', null, { timeout: 5_000 });
  if (Number(await dataset(page, 'creatorSkillDraftDamage')) !== 44) throw new Error('Confirmed proposal did not update damage');
  if (Number(await dataset(page, 'creatorSkillDraftMpCost')) !== 31) throw new Error('Confirmed proposal did not update MP cost');
  if ((await dataset(page, 'creatorSkillDraftName')) !== 'Nova Bolt') throw new Error('Confirmed proposal did not update skill name');

  await page.evaluate((json) => window.customFighterCreatorStageAiSkillProposal(json), JSON.stringify({ ...proposal, proposal_id: 'proposal_discard_001', damage: 99 }));
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiSkillProposalConfirmed === 'false', null, { timeout: 5_000 });
  await page.evaluate(() => window.customFighterCreatorDiscardAiSkillProposal());
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiSkillProposalValid === 'false', null, { timeout: 5_000 });
  if (Number(await dataset(page, 'creatorSkillDraftDamage')) !== 44) throw new Error('Discarded proposal mutated SkillDraft');

  console.log('WEB_CREATOR_AI_SKILL_PROPOSAL_SMOKE_PASSED reviewRequired=true confirmApplies=true discardSafe=true');
} finally {
  await browser.close();
}
