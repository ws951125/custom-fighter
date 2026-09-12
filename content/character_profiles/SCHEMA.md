# Visual profile schema boundary

`CharacterDefinition.visual_profile` resolves only safe token ids under `res://content/character_profiles/<id>.profile.json`.

The current schema is version 1 and allows only validated `palette` and `body` data. Arbitrary paths, scripts, executable fields, plugins, and native code are outside this boundary.
