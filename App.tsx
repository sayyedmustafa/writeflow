import React, { useState, useEffect, useRef } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  ScrollView,
  TouchableOpacity,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Alert,
} from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import { Ionicons } from '@expo/vector-icons';

import { Header } from './src/components/Header';
import { SuggestionCard } from './src/components/SuggestionCard';
import { ToneModal } from './src/components/ToneModal';
import { RewritesModal } from './src/components/RewritesModal';
import { SettingsModal } from './src/components/SettingsModal';
import { GrammarVisualizer } from './src/components/GrammarVisualizer';

import { analyzeWriting } from './src/services/ai';
import { loadSettings, saveSettings, saveDraft, loadDraft } from './src/services/storage';
import { Suggestion, UserSettings, TonePreset, AnalysisResponse } from './src/types';

export default function App() {
  const [text, setText] = useState('');
  const [activeTab, setActiveTab] = useState<'editor' | 'visualizer'>('editor');
  const [settings, setSettings] = useState<UserSettings>({
    apiKey: '',
    defaultTone: 'professional',
    autoCheck: true,
    customDictionary: [],
  });
  const [currentTone, setCurrentTone] = useState<TonePreset>('professional');
  const [analysis, setAnalysis] = useState<AnalysisResponse>({
    suggestions: [],
    toneAnalysis: { detectedTone: 'Neutral', clarityScore: 100, overallImpression: 'Ready to write.' },
    rewrites: [],
  });
  const [loading, setLoading] = useState(false);

  // Modals state
  const [toneModalVisible, setToneModalVisible] = useState(false);
  const [rewritesModalVisible, setRewritesModalVisible] = useState(false);
  const [settingsModalVisible, setSettingsModalVisible] = useState(false);

  const debounceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Load saved settings & draft on mount
  useEffect(() => {
    (async () => {
      const saved = await loadSettings();
      setSettings(saved);
      setCurrentTone(saved.defaultTone);
      const draft = await loadDraft();
      if (draft) setText(draft);
    })();
  }, []);

  // Trigger analysis on text or tone change
  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current);

    // Save draft
    if (text) saveDraft(text);

    if (!settings.autoCheck) return;

    if (text.trim().length >= 3) {
      setLoading(true);
      debounceTimer.current = setTimeout(async () => {
        try {
          const res = await analyzeWriting(text, settings.apiKey, currentTone);
          setAnalysis(res);
        } catch (err) {
          console.error(err);
        } finally {
          setLoading(false);
        }
      }, 900);
    } else {
      setLoading(false);
      setAnalysis({
        suggestions: [],
        toneAnalysis: { detectedTone: 'Neutral', clarityScore: 100, overallImpression: 'Ready.' },
        rewrites: [],
      });
    }

    return () => {
      if (debounceTimer.current) clearTimeout(debounceTimer.current);
    };
  }, [text, currentTone, settings.apiKey, settings.autoCheck]);

  // Apply single suggestion
  const handleApplySuggestion = (s: Suggestion) => {
    setText((prev) => prev.replace(s.originalText, s.replacementText));
    setAnalysis((prev) => ({
      ...prev,
      suggestions: prev.suggestions.filter((item) => item.id !== s.id),
    }));
  };

  // Dismiss suggestion
  const handleDismissSuggestion = (s: Suggestion) => {
    setAnalysis((prev) => ({
      ...prev,
      suggestions: prev.suggestions.filter((item) => item.id !== s.id),
    }));
  };

  // Accept all suggestions at once
  const handleAcceptAll = () => {
    let updatedText = text;
    for (const s of analysis.suggestions) {
      updatedText = updatedText.replace(s.originalText, s.replacementText);
    }
    setText(updatedText);
    setAnalysis((prev) => ({ ...prev, suggestions: [] }));
  };

  // Apply a full rewrite
  const handleApplyRewrite = (newText: string) => {
    setText(newText);
  };

  // Clear text
  const handleClearText = () => {
    Alert.alert('Clear Text', 'Are you sure you want to delete everything in the editor?', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Clear',
        style: 'destructive',
        onPress: () => {
          setText('');
          saveDraft('');
        },
      },
    ]);
  };

  // Word and character count metrics
  const wordCount = text.trim() ? text.trim().split(/\s+/).length : 0;
  const charCount = text.length;

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
        <StatusBar style="light" />

        <Header
          clarityScore={text.trim().length > 3 ? analysis.toneAnalysis.clarityScore : null}
          currentTone={currentTone}
          onOpenTone={() => setToneModalVisible(true)}
          onOpenRewrites={() => setRewritesModalVisible(true)}
          onOpenSettings={() => setSettingsModalVisible(true)}
          onClearText={handleClearText}
          hasText={text.length > 0}
        />

        {/* View Switcher Tabs */}
        <View style={styles.tabBar}>
          <TouchableOpacity
            style={[styles.tabButton, activeTab === 'editor' && styles.activeTabButton]}
            onPress={() => setActiveTab('editor')}
          >
            <Ionicons name="create-outline" size={15} color={activeTab === 'editor' ? '#38BDF8' : '#64748B'} />
            <Text style={[styles.tabText, activeTab === 'editor' && styles.activeTabText]}>Editor</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.tabButton, activeTab === 'visualizer' && styles.activeTabButton]}
            onPress={() => setActiveTab('visualizer')}
          >
            <Ionicons name="checkmark-done-circle-outline" size={16} color={activeTab === 'visualizer' ? '#34D399' : '#64748B'} />
            <Text style={[styles.tabText, activeTab === 'visualizer' && styles.activeTabGreenText]}>
              Sentence Visualizer
            </Text>
            {analysis.suggestions.length > 0 && (
              <View style={styles.badgeCount}>
                <Text style={styles.badgeCountText}>{analysis.suggestions.length}</Text>
              </View>
            )}
          </TouchableOpacity>
        </View>

        {activeTab === 'visualizer' ? (
          <GrammarVisualizer
            text={text}
            suggestions={analysis.suggestions}
            onApplySuggestion={handleApplySuggestion}
            onOpenRewrites={() => setRewritesModalVisible(true)}
          />
        ) : (
          <KeyboardAvoidingView
            style={styles.keyboardContainer}
            behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          >
            {/* Main Editor */}
            <View style={styles.editorWrapper}>
              <TextInput
                style={styles.textInput}
                value={text}
                onChangeText={setText}
                placeholder="Paste or start typing your document here... The assistant will automatically highlight grammar, tone, and clarity fixes."
                placeholderTextColor="#475569"
                multiline
                textAlignVertical="top"
                autoCorrect={false}
                spellCheck={false}
              />

              {/* Editor Stats Footer */}
              <View style={styles.metricsBar}>
                <Text style={styles.metricsText}>
                  {wordCount} words · {charCount} chars
                </Text>
                {text.trim().length > 0 && (
                  <Text style={styles.detectedToneText}>
                    Detected: {analysis.toneAnalysis.detectedTone}
                  </Text>
                )}
              </View>
            </View>

            {/* Bottom Suggestion Drawer */}
            <View style={styles.bottomDrawer}>
              <View style={styles.drawerHeader}>
                <View style={styles.drawerTitleRow}>
                  <Ionicons name="sparkles" size={15} color="#38BDF8" />
                  <Text style={styles.drawerTitle}>
                    Suggestions ({analysis.suggestions.length})
                  </Text>
                  {loading && <ActivityIndicator size="small" color="#38BDF8" style={{ marginLeft: 6 }} />}
                </View>

                {analysis.suggestions.length > 1 && (
                  <TouchableOpacity onPress={handleAcceptAll} style={styles.acceptAllBtn}>
                    <Text style={styles.acceptAllText}>Accept All</Text>
                  </TouchableOpacity>
                )}
              </View>

              {/* Suggestions Carousel */}
              {analysis.suggestions.length > 0 ? (
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.suggestionList}
                >
                  {analysis.suggestions.map((item) => (
                    <SuggestionCard
                      key={item.id}
                      suggestion={item}
                      onApply={handleApplySuggestion}
                      onDismiss={handleDismissSuggestion}
                    />
                  ))}
                </ScrollView>
              ) : (
                <View style={styles.allClearContainer}>
                  {loading ? (
                    <Text style={styles.allClearText}>Analyzing sentence structure and style...</Text>
                  ) : text.trim().length > 10 ? (
                    <View style={styles.allClearBadge}>
                      <Ionicons name="checkmark-circle" size={17} color="#10B981" />
                      <Text style={styles.allClearSuccessText}>
                        No issues found · {analysis.toneAnalysis.overallImpression}
                      </Text>
                    </View>
                  ) : (
                    <Text style={styles.allClearText}>
                      Write a few words to start checking grammar and tone.
                    </Text>
                  )}
                </View>
              )}
            </View>
          </KeyboardAvoidingView>
        )}

        {/* Modals */}
        <ToneModal
          visible={toneModalVisible}
          currentTone={currentTone}
          onSelectTone={(t) => setCurrentTone(t)}
          onClose={() => setToneModalVisible(false)}
        />

        <RewritesModal
          visible={rewritesModalVisible}
          rewrites={analysis.rewrites}
          onApplyRewrite={handleApplyRewrite}
          onClose={() => setRewritesModalVisible(false)}
        />

        <SettingsModal
          visible={settingsModalVisible}
          settings={settings}
          onSaveSettings={(s) => {
            setSettings(s);
            saveSettings(s);
          }}
          onClose={() => setSettingsModalVisible(false)}
        />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#0F172A',
  },
  keyboardContainer: {
    flex: 1,
  },
  editorWrapper: {
    flex: 1,
    paddingHorizontal: 18,
    paddingTop: 12,
  },
  textInput: {
    flex: 1,
    color: '#F8FAFC',
    fontSize: 17,
    lineHeight: 27,
    letterSpacing: 0.2,
  },
  metricsBar: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: '#1E293B',
  },
  metricsText: {
    color: '#64748B',
    fontSize: 12,
    fontWeight: '500',
  },
  detectedToneText: {
    color: '#94A3B8',
    fontSize: 12,
    fontWeight: '600',
  },
  bottomDrawer: {
    backgroundColor: '#090D16',
    borderTopWidth: 1,
    borderTopColor: '#1E293B',
    paddingTop: 12,
    paddingBottom: 16,
  },
  drawerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    marginBottom: 10,
  },
  drawerTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  drawerTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#E2E8F0',
  },
  acceptAllBtn: {
    backgroundColor: '#1E293B',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#334155',
  },
  acceptAllText: {
    color: '#38BDF8',
    fontSize: 12,
    fontWeight: '700',
  },
  suggestionList: {
    paddingHorizontal: 16,
    paddingBottom: 4,
  },
  allClearContainer: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    justifyContent: 'center',
  },
  allClearBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  allClearText: {
    color: '#64748B',
    fontSize: 13,
  },
  allClearSuccessText: {
    color: '#10B981',
    fontSize: 13,
    fontWeight: '600',
  },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#0F172A',
    paddingHorizontal: 16,
    paddingVertical: 8,
    gap: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#1E293B',
  },
  tabButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    backgroundColor: '#1E293B',
    borderWidth: 1,
    borderColor: '#334155',
  },
  activeTabButton: {
    backgroundColor: '#0F2642',
    borderColor: '#0284C7',
  },
  tabText: {
    color: '#94A3B8',
    fontSize: 13,
    fontWeight: '600',
  },
  activeTabText: {
    color: '#38BDF8',
  },
  activeTabGreenText: {
    color: '#34D399',
    fontWeight: '700',
  },
  badgeCount: {
    backgroundColor: '#EF4444',
    paddingHorizontal: 6,
    paddingVertical: 1,
    borderRadius: 10,
    marginLeft: 2,
  },
  badgeCountText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '800',
  },
});
