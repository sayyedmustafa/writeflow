import { AnalysisResponse, Suggestion, TonePreset } from '../types';

const PRIMARY_MODEL = 'gemini-3.5-flash';
const FALLBACK_MODEL = 'gemini-3.1-flash-lite';

export async function analyzeWriting(
  text: string,
  apiKey: string,
  targetTone: TonePreset = 'professional'
): Promise<AnalysisResponse> {
  const trimmed = text.trim();
  if (!trimmed) {
    return {
      suggestions: [],
      toneAnalysis: {
        detectedTone: 'Neutral',
        clarityScore: 100,
        overallImpression: 'Clean and clear.',
      },
      rewrites: [],
    };
  }

  // If no API key is set yet, run the built-in local heuristic engine
  if (!apiKey || apiKey.trim() === '') {
    return runLocalHeuristicAnalysis(text, targetTone);
  }

  const prompt = `You are an elite writing assistant like Grammarly.
Analyze the user's text thoroughly for:
1. Grammar and syntax errors.
2. Spelling mistakes.
3. Clarity, conciseness, and eliminating redundant/wordy phrases.
4. Tone adjustments aligned with the target tone: "${targetTone}".
5. Generate 2-3 full-text rewrites tailored for "${targetTone}" (e.g. Concise, Confident, Elegant).

STRICT OUTPUT REQUIREMENT:
Respond with ONLY valid JSON (no markdown fences, no explanatory text outside JSON) matching this exact format:
{
  "suggestions": [
    {
      "id": "1",
      "originalText": "exact word or phrase in text",
      "replacementText": "recommended replacement",
      "explanation": "brief reason for this correction",
      "type": "grammar"
    }
  ],
  "toneAnalysis": {
    "detectedTone": "Casual / Direct / Tentative",
    "clarityScore": 88,
    "overallImpression": "One sentence summary of the writing style and quality"
  },
  "rewrites": [
    {
      "preset": "${targetTone}",
      "text": "Rewritten version of the full text in the specified tone",
      "tagline": "More direct & professional"
    }
  ]
}

Valid values for suggestion "type" are: "grammar", "spelling", "clarity", "tone".
User text to analyze:
"""${trimmed}"""`;

  async function callGemini(model: string) {
    return fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey.trim()}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            response_mime_type: 'application/json',
            temperature: 0.2,
          },
        }),
      }
    );
  }

  try {
    let response = await callGemini(PRIMARY_MODEL);
    if (!response.ok) {
      response = await callGemini(FALLBACK_MODEL);
    }

    if (!response.ok) {
      const errorMsg = await response.text();
      console.warn('Gemini API call failed, falling back to local analysis:', errorMsg);
      return runLocalHeuristicAnalysis(text, targetTone);
    }

    const data = await response.json();
    const rawContent = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawContent) {
      return runLocalHeuristicAnalysis(text, targetTone);
    }

    const parsed: AnalysisResponse = JSON.parse(rawContent);
    return parsed;
  } catch (err) {
    console.warn('Analysis error:', err);
    return runLocalHeuristicAnalysis(text, targetTone);
  }
}

// Built-in offline fallback engine so the app works immediately before API key setup
function runLocalHeuristicAnalysis(text: string, tone: TonePreset): AnalysisResponse {
  const suggestions: Suggestion[] = [];
  let id = 1;

  const dictionaryRules: [RegExp, string, string, 'grammar' | 'spelling' | 'clarity' | 'tone'][] = [
    [/\bthier\b/gi, 'their', 'Spelling mistake', 'spelling'],
    [/\bteh\b/gi, 'the', 'Spelling typo', 'spelling'],
    [/\bgrammer\b/gi, 'grammar', 'Common spelling error', 'spelling'],
    [/\brecieve\b/gi, 'receive', 'Spelling mistake: "i" before "e" except after "c"', 'spelling'],
    [/\bseperate\b/gi, 'separate', 'Spelling error', 'spelling'],
    [/\bdont\b/gi, "don't", 'Missing apostrophe in contraction', 'grammar'],
    [/\bcant\b/gi, "can't", 'Missing apostrophe in contraction', 'grammar'],
    [/\bwont\b/gi, "won't", 'Missing apostrophe in contraction', 'grammar'],
    [/\bin order to\b/gi, 'to', 'Wordy phrase: simplify to "to"', 'clarity'],
    [/\bat this point in time\b/gi, 'now', 'Wordy phrase: replace with "now" or "currently"', 'clarity'],
    [/\bdue to the fact that\b/gi, 'because', 'Simplify to "because"', 'clarity'],
    [/\bvery unique\b/gi, 'unique', '"Unique" is absolute and does not need "very"', 'clarity'],
    [/\bi think that\b/gi, '', 'Consider removing filler phrase for more confidence', 'tone'],
    [/\bjust\b/gi, '', 'Removing "just" makes your tone more authoritative', 'tone'],
  ];

  for (const [regex, replacement, explanation, type] of dictionaryRules) {
    const matches = text.match(regex);
    if (matches) {
      for (const match of matches) {
        if (!suggestions.some((s) => s.originalText.toLowerCase() === match.toLowerCase())) {
          suggestions.push({
            id: String(id++),
            originalText: match,
            replacementText: replacement,
            explanation,
            type,
          });
        }
      }
    }
  }

  const wordCount = text.trim().split(/\s+/).filter(Boolean).length;
  const clarityScore = Math.max(50, 100 - suggestions.length * 10);

  return {
    suggestions,
    toneAnalysis: {
      detectedTone: wordCount > 0 ? (suggestions.length === 0 ? 'Polished & Direct' : 'Draft / Needs Review') : 'Neutral',
      clarityScore,
      overallImpression:
        suggestions.length === 0
          ? 'Great work! No obvious grammatical or spelling issues detected.'
          : `Found ${suggestions.length} potential improvement${suggestions.length > 1 ? 's' : ''}. Enter a Gemini API key in Settings for deep AI reasoning.`,
    },
    rewrites: [
      {
        preset: tone,
        text: text.replace(/\bthier\b/gi, 'their').replace(/\bdont\b/gi, "don't").replace(/\bin order to\b/gi, 'to'),
        tagline: 'Standard polish with active corrections',
      },
    ],
  };
}
