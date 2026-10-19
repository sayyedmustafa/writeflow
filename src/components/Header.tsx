import React from 'react';
import { StyleSheet, Text, View, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { TonePreset } from '../types';

interface HeaderProps {
  clarityScore: number | null;
  currentTone: TonePreset;
  onOpenTone: () => void;
  onOpenRewrites: () => void;
  onOpenSettings: () => void;
  onClearText: () => void;
  hasText: boolean;
}

export const Header: React.FC<HeaderProps> = ({
  clarityScore,
  currentTone,
  onOpenTone,
  onOpenRewrites,
  onOpenSettings,
  onClearText,
  hasText,
}) => {
  const getScoreColor = (score: number) => {
    if (score >= 90) return '#10B981'; // Mint Green
    if (score >= 70) return '#3B82F6'; // Blue
    if (score >= 50) return '#F59E0B'; // Amber
    return '#EF4444'; // Red
  };

  return (
    <View style={styles.container}>
      <View style={styles.titleRow}>
        <View style={styles.brandGroup}>
          <View style={styles.logoBadge}>
            <Ionicons name="sparkles" size={16} color="#60A5FA" />
          </View>
          <Text style={styles.brandTitle}>WriteAI</Text>
        </View>

        <View style={styles.actionsRow}>
          {hasText && (
            <TouchableOpacity style={styles.iconBtn} onPress={onClearText} accessibilityLabel="Clear text">
              <Ionicons name="trash-outline" size={19} color="#94A3B8" />
            </TouchableOpacity>
          )}

          <TouchableOpacity style={styles.iconBtn} onPress={onOpenRewrites} accessibilityLabel="Rewrites">
            <Ionicons name="color-wand-outline" size={20} color="#C084FC" />
          </TouchableOpacity>

          <TouchableOpacity style={styles.iconBtn} onPress={onOpenSettings} accessibilityLabel="Settings">
            <Ionicons name="settings-outline" size={20} color="#94A3B8" />
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.subBar}>
        <TouchableOpacity style={styles.toneButton} onPress={onOpenTone}>
          <Ionicons name="options-outline" size={14} color="#60A5FA" />
          <Text style={styles.toneButtonText}>Tone: {capitalize(currentTone)}</Text>
          <Ionicons name="chevron-down" size={13} color="#64748B" />
        </TouchableOpacity>

        {clarityScore !== null && (
          <View style={styles.clarityGroup}>
            <View style={[styles.statusDot, { backgroundColor: getScoreColor(clarityScore) }]} />
            <Text style={styles.clarityLabel}>Clarity:</Text>
            <Text style={[styles.clarityValue, { color: getScoreColor(clarityScore) }]}>
              {clarityScore}%
            </Text>
          </View>
        )}
      </View>
    </View>
  );
};

function capitalize(str: string) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#1E293B',
    backgroundColor: '#0F172A',
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  brandGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  logoBadge: {
    width: 28,
    height: 28,
    borderRadius: 8,
    backgroundColor: '#1E293B',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#334155',
  },
  brandTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: '#F8FAFC',
    letterSpacing: -0.5,
  },
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: '#1E293B',
    alignItems: 'center',
    justifyContent: 'center',
  },
  subBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 10,
  },
  toneButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#1E293B',
    paddingVertical: 5,
    paddingHorizontal: 10,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#334155',
  },
  toneButtonText: {
    color: '#E2E8F0',
    fontSize: 12,
    fontWeight: '600',
  },
  clarityGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#1E293B',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 14,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  clarityLabel: {
    color: '#94A3B8',
    fontSize: 12,
    fontWeight: '500',
  },
  clarityValue: {
    fontSize: 12,
    fontWeight: '700',
  },
});
