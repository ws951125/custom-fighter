const PACKAGES = Object.freeze({
  creator_blaze_001: Object.freeze({
    schema_version: 1,
    ruleset_id: 'competitive_standard',
    ruleset_version: 1,
    power_budget_id: 'competitive_standard_v1',
    character: Object.freeze({
      id: 'creator_blaze_001',
      stats: Object.freeze({
        max_hp: 100,
        max_mp: 90,
        move_speed: 220,
        depth_speed: 1,
        run_multiplier: 1.5,
        guard_move_multiplier: 0.5
      }),
      skill_slots: Object.freeze({ skill_1: 'creator_blaze_bolt_001' })
    }),
    skills: Object.freeze([
      Object.freeze({
        id: 'creator_blaze_bolt_001',
        type: 'projectile',
        damage: 18,
        mp_cost: 20,
        cooldown: 1.8
      })
    ])
  }),
  creator_frost_001: Object.freeze({
    schema_version: 1,
    ruleset_id: 'competitive_standard',
    ruleset_version: 1,
    power_budget_id: 'competitive_standard_v1',
    character: Object.freeze({
      id: 'creator_frost_001',
      stats: Object.freeze({
        max_hp: 90,
        max_mp: 110,
        move_speed: 230,
        depth_speed: 1,
        run_multiplier: 1.4,
        guard_move_multiplier: 0.55
      }),
      skill_slots: Object.freeze({ skill_1: 'creator_frost_strike_001' })
    }),
    skills: Object.freeze([
      Object.freeze({
        id: 'creator_frost_strike_001',
        type: 'melee',
        damage: 16,
        mp_cost: 15,
        cooldown: 1.5
      })
    ])
  })
});

export const TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS = Object.freeze({
  creator_blaze_001: 'ef1756f3c1a50e3adc36658735cd160a9664f10aef81174fc1eef288a1cfd318',
  creator_frost_001: 'df6fc187ded8159b40abbf9e58a453f5400bcd766b5d5c9cc25087e4bc213d83'
});

export async function resolveTrustedCompetitivePackage(characterId) {
  const pkg = PACKAGES[String(characterId ?? '').trim()];
  return pkg ? structuredClone(pkg) : null;
}

export function listTrustedCompetitivePackages() {
  return Object.keys(PACKAGES).sort().map(character_id => ({
    character_id,
    content_fingerprint: TRUSTED_COMPETITIVE_CUSTOM_FINGERPRINTS[character_id],
    package_schema_version: 1
  }));
}

export const _test = Object.freeze({ PACKAGES });
