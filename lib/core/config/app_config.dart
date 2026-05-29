/// App-wide configuration constants.
/// Replace kClaudeApiKey with your actual Anthropic API key at runtime,
/// or inject via environment variable / Firestore Secret.
/// When set to 'REPLACE_WITH_KEY', the Dialog module runs in offline mode.
library app_config;

const String kClaudeApiKey = 'REPLACE_WITH_KEY';

/// Claude model to use for NPC dialog
const String kClaudeModel = 'claude-3-haiku-20240307';

/// Maximum tokens per NPC response (A1 English stays short)
const int kClaudeMaxTokens = 150;
