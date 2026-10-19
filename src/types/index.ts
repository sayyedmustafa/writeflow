export type SuggestionType = 'grammar' | 'spelling' | 'clarity' | 'tone';

export interface Suggestion {
  id: string;
  originalText: string;
  replacementText: string;
  explanation: string;
  type: SuggestionType;
  startIndex?: number;
  endIndex?: number;
}

export type TonePreset = 'professional' | 'casual' | 'academic' | 'concise' | 'confident' | 'friendly';

export interface ToneAnalysis {
  detectedTone: string;
  clarityScore: number; // 0 - 100
  overallImpression: string;
}

export interface RewriteOption {
  preset: TonePreset;
  text: string;
  tagline: string;
}

export interface AnalysisResponse {
  suggestions: Suggestion[];
  toneAnalysis: ToneAnalysis;
  rewrites: RewriteOption[];
}

export interface UserSettings {
  apiKey: string;
  defaultTone: TonePreset;
  autoCheck: boolean;
  customDictionary: string[];
}
