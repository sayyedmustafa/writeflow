import React from 'react';
import { StyleSheet, Text, View, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Suggestion } from '../types';

interface GrammarVisualizerProps {
  text: string;
  suggestions: Suggestion[];
  onApplySuggestion: (suggestion: Suggestion) => void;
  onOpenRewrites: () => void;
}

interface SentenceSegment {
  text: string;
  isError: boolean;
  suggestion?: Suggestion;
}

interface AnalyzedSentence {
  originalSentence: string;
  isEntirelyCorrect: boolean;
  segments: SentenceSegment[];
  suggestions: Suggestion[];
}

export const GrammarVisualizer: React.FC<GrammarVisualizerProps> = ({
  text,
  suggestions,
  onApplySuggestion,
  onOpenRewrites,
}) => {
  if (!text.trim()) {
    return (
      <View style={styles.emptyContainer}>
        <Ionicons name="sparkles-outline" size={36} color="#475569" />
        <Text style={styles.emptyTitle}>Grammar Visualizer Ready</Text>
        <Text style={styles.emptySubtitle}>
          Start typing or paste your writing to see real-time sentence-by-sentence grammar verification.
        </Text>
      </View>
    );
  }

  // 1. Break text into sentences by punctuation (. ? ! \n)
  const sentenceRegex = /([^\.!\?\n]+[\.!\?\n]*)/g;
  const rawSentences = text.match(sentenceRegex) || [text];

  const analyzedSentences: AnalyzedSentence[] = rawSentences.map((sentence) => {
    const trimmed = sentence.trim();
    if (!trimmed) {
      return {
        originalSentence: sentence,
        isEntirelyCorrect: true,
        segments: [{ text: sentence, isError: false }],
        suggestions: [],
      };
    }

    // Find suggestions belonging to this sentence
    const matchingSuggestions = suggestions.filter((s) => {
      const lowerSentence = sentence.toLowerCase();
      const lowerOriginal = s.originalText.toLowerCase();
      return lowerSentence.includes(lowerOriginal);
    });

    if (matchingSuggestions.length === 0) {
      return {
        originalSentence: sentence,
        isEntirelyCorrect: true,
        segments: [{ text: sentence, isError: false }],
        suggestions: [],
      };
    }

    // Break sentence into segments (green up to error, red on error)
    const segments: SentenceSegment[] = [];
    let remaining = sentence;

    // Process each suggestion in sentence
    for (const s of matchingSuggestions) {
      const idx = remaining.toLowerCase().indexOf(s.originalText.toLowerCase());
      if (idx !== -1) {
        // Correct text before the error (Green)
        if (idx > 0) {
          segments.push({
            text: remaining.substring(0, idx),
            isError: false,
          });
        }
        // Incorrect text (Red)
        segments.push({
          text: remaining.substring(idx, idx + s.originalText.length),
          isError: true,
          suggestion: s,
        });
        remaining = remaining.substring(idx + s.originalText.length);
      }
    }

    // Remaining trailing text
    if (remaining.length > 0) {
      segments.push({
        text: remaining,
        isError: false,
      });
    }

    return {
      originalSentence: sentence,
      isEntirelyCorrect: false,
      segments,
      suggestions: matchingSuggestions,
    };
  });

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Legend Header */}
      <View style={styles.legendCard}>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#10B981' }]} />
          <Text style={styles.legendText}>Green = Correct Grammar</Text>
        </View>
        <View style={styles.legendItem}>
          <View style={[styles.legendDot, { backgroundColor: '#EF4444' }]} />
          <Text style={styles.legendText}>Red = Grammatical Error</Text>
        </View>
      </View>

      {/* Sentence Cards */}
      {analyzedSentences.map((item, idx) => (
        <View
          key={idx}
          style={[
            styles.sentenceCard,
            item.isEntirelyCorrect ? styles.correctCard : styles.errorCard,
          ]}
        >
          <View style={styles.cardHeader}>
            <View style={styles.sentenceStatus}>
              {item.isEntirelyCorrect ? (
                <>
                  <Ionicons name="checkmark-circle" size={16} color="#10B981" />
                  <Text style={styles.statusCorrect}>Sentence {idx + 1}: Valid & Correct</Text>
                </>
              ) : (
                <>
                  <Ionicons name="alert-circle" size={16} color="#EF4444" />
                  <Text style={styles.statusError}>
                    Sentence {idx + 1}: {item.suggestions.length} Issue{item.suggestions.length > 1 ? 's' : ''} Found
                  </Text>
                </>
              )}
            </View>
          </View>

          {/* Visual Highlighted Text */}
          <Text style={styles.sentenceParagraph}>
            {item.segments.map((seg, sIdx) => (
              <Text
                key={sIdx}
                style={[
                  seg.isError ? styles.textRed : styles.textGreen,
                  seg.isError && styles.textErrorUnderline,
                ]}
              >
                {seg.text}
              </Text>
            ))}
          </Text>

          {/* If there are errors, show direct one-tap fix pills */}
          {!item.isEntirelyCorrect && item.suggestions.length > 0 && (
            <View style={styles.actionRow}>
              {item.suggestions.map((s) => (
                <TouchableOpacity
                  key={s.id}
                  style={styles.fixButton}
                  onPress={() => onApplySuggestion(s)}
                  activeOpacity={0.8}
                >
                  <Ionicons name="sparkles" size={13} color="#38BDF8" />
                  <Text style={styles.fixButtonText}>
                    Change <Text style={{ textDecorationLine: 'line-through', color: '#F87171' }}>{s.originalText}</Text> to <Text style={{ fontWeight: '800', color: '#4ADE80' }}>{s.replacementText || '(omit)'}</Text>
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          )}

          {/* Better Alternatives Button */}
          <TouchableOpacity style={styles.alternativesBtn} onPress={onOpenRewrites} activeOpacity={0.7}>
            <Ionicons name="color-wand-outline" size={14} color="#C084FC" />
            <Text style={styles.alternativesText}>View AI Rewrites & Alternatives</Text>
          </TouchableOpacity>
        </View>
      ))}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0F172A',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
  },
  legendCard: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    backgroundColor: '#1E293B',
    paddingVertical: 10,
    paddingHorizontal: 14,
    borderRadius: 12,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#334155',
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  legendDot: {
    width: 9,
    height: 9,
    borderRadius: 4.5,
  },
  legendText: {
    color: '#E2E8F0',
    fontSize: 12,
    fontWeight: '600',
  },
  sentenceCard: {
    backgroundColor: '#1E293B',
    borderRadius: 14,
    padding: 16,
    marginBottom: 14,
    borderWidth: 1.5,
  },
  correctCard: {
    borderColor: 'rgba(16, 185, 129, 0.4)',
    backgroundColor: '#0A251E',
  },
  errorCard: {
    borderColor: 'rgba(239, 68, 68, 0.4)',
    backgroundColor: '#20151E',
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  sentenceStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  statusCorrect: {
    color: '#10B981',
    fontSize: 13,
    fontWeight: '700',
  },
  statusError: {
    color: '#EF4444',
    fontSize: 13,
    fontWeight: '700',
  },
  sentenceParagraph: {
    fontSize: 16,
    lineHeight: 25,
    marginBottom: 14,
  },
  textGreen: {
    color: '#34D399', // Bright emerald green
    fontWeight: '500',
  },
  textRed: {
    color: '#F87171', // Bright vivid red
    backgroundColor: 'rgba(239, 68, 68, 0.25)',
    fontWeight: '700',
  },
  textErrorUnderline: {
    textDecorationLine: 'underline',
    textDecorationColor: '#EF4444',
  },
  actionRow: {
    marginTop: 4,
    marginBottom: 10,
    gap: 8,
  },
  fixButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#0F172A',
    paddingVertical: 9,
    paddingHorizontal: 12,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#38BDF8',
  },
  fixButtonText: {
    color: '#F1F5F9',
    fontSize: 13,
  },
  alternativesBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#334155',
  },
  alternativesText: {
    color: '#C084FC',
    fontSize: 12,
    fontWeight: '600',
  },
  emptyContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 30,
    gap: 10,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '700',
    color: '#E2E8F0',
  },
  emptySubtitle: {
    fontSize: 13,
    color: '#64748B',
    textAlign: 'center',
    lineHeight: 18,
    maxWidth: 280,
  },
});
