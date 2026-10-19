import AsyncStorage from '@react-native-async-storage/async-storage';
import { UserSettings, TonePreset } from '../types';

const SETTINGS_KEY = '@writing_assistant_settings';
const LAST_DRAFT_KEY = '@writing_assistant_last_draft';

const DEFAULT_SETTINGS: UserSettings = {
  apiKey: '',
  defaultTone: 'professional',
  autoCheck: true,
  customDictionary: [],
};

export async function loadSettings(): Promise<UserSettings> {
  try {
    const raw = await AsyncStorage.getItem(SETTINGS_KEY);
    if (!raw) return DEFAULT_SETTINGS;
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch (error) {
    console.error('Failed to load settings:', error);
    return DEFAULT_SETTINGS;
  }
}

export async function saveSettings(settings: UserSettings): Promise<void> {
  try {
    await AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
}

export async function saveDraft(text: string): Promise<void> {
  try {
    await AsyncStorage.setItem(LAST_DRAFT_KEY, text);
  } catch (error) {
    console.error('Failed to save draft:', error);
  }
}

export async function loadDraft(): Promise<string> {
  try {
    const draft = await AsyncStorage.getItem(LAST_DRAFT_KEY);
    return draft || '';
  } catch (error) {
    console.error('Failed to load draft:', error);
    return '';
  }
}
