import React from 'react';
import { StyleSheet, Text, View, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Suggestion, SuggestionType } from '../types';

interface SuggestionCardProps {
  suggestion: Suggestion;
  onApply: (suggestion: Suggestion) => void;
  onDismiss: (suggestion: Suggestion) => void;
}

export const SuggestionCard: React.FC<SuggestionCardProps> = ({
  suggestion,
  onApply,
  onDismiss,
}) => {
  const getTypeConfig = (type: SuggestionType) => {
    switch (type) {
      case 'grammar':
        return { label: 'Grammar', bg: '#450A0A', text: '#FCA5A5', icon: 'alert-circle' as const };
      case 'spelling':
        return { label: 'Spelling', bg: '#431407', text: '#FDBA74', icon: 'text' as const };
      case 'clarity':
        return { label: 'Clarity', bg: '#082F49', text: '#7DD3FC', icon: 'bulb' as const };
      case 'tone':
        return { label: 'Tone', bg: '#2E1065', text: '#D8B4FE', icon: 'chatbubbles' as const };
    }
  };

  const config = getTypeConfig(suggestion.type);

  return (
    <View style={styles.card}>
      <View style={styles.topRow}>
        <View style={[styles.typeBadge, { backgroundColor: config.bg }]}>
          <Ionicons name={config.icon} size={12} color={config.text} />
          <Text style={[styles.typeLabel, { color: config.text }]}>{config.label}</Text>
        </View>

        <TouchableOpacity onPress={() => onDismiss(suggestion)} style={styles.dismissBtn}>
          <Ionicons name="close" size={16} color="#64748B" />
        </TouchableOpacity>
      </View>

      <View style={styles.diffRow}>
        <Text style={styles.originalText}>{suggestion.originalText}</Text>
        <Ionicons name="arrow-forward" size={13} color="#64748B" style={{ marginHorizontal: 6 }} />
        <Text style={styles.replacementText}>
          {suggestion.replacementText ? suggestion.replacementText : '(omit)'}
        </Text>
      </View>

      {suggestion.explanation ? (
        <Text style={styles.explanationText} numberOfLines={2}>
          {suggestion.explanation}
        </Text>
      ) : null}

      <TouchableOpacity
        style={styles.applyButton}
        onPress={() => onApply(suggestion)}
        activeOpacity={0.8}
      >
        <Ionicons name="checkmark-sharp" size={14} color="#FFFFFF" />
        <Text style={styles.applyButtonText}>Accept</Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#1E293B',
    borderRadius: 14,
    padding: 12,
    marginRight: 10,
    width: 250,
    borderWidth: 1,
    borderColor: '#334155',
    justifyContent: 'space-between',
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  typeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 3,
    paddingHorizontal: 7,
    borderRadius: 8,
  },
  typeLabel: {
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  dismissBtn: {
    padding: 2,
  },
  diffRow: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    marginBottom: 6,
  },
  originalText: {
    color: '#EF4444',
    fontSize: 14,
    fontWeight: '600',
    textDecorationLine: 'line-through',
  },
  replacementText: {
    color: '#10B981',
    fontSize: 14,
    fontWeight: '700',
  },
  explanationText: {
    color: '#94A3B8',
    fontSize: 12,
    lineHeight: 16,
    marginBottom: 10,
  },
  applyButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    backgroundColor: '#0EA5E9',
    borderRadius: 8,
    paddingVertical: 7,
  },
  applyButtonText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '700',
  },
});
