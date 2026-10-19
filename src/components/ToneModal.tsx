import React from 'react';
import { StyleSheet, Text, View, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { TonePreset } from '../types';

interface ToneModalProps {
  visible: boolean;
  currentTone: TonePreset;
  onSelectTone: (tone: TonePreset) => void;
  onClose: () => void;
}

const TONES: { id: TonePreset; title: string; desc: string; icon: any }[] = [
  { id: 'professional', title: 'Professional', desc: 'Clear, polite, authoritative, and formal.', icon: 'briefcase-outline' },
  { id: 'concise', title: 'Concise', desc: 'Removes fluff and extra words directly to the point.', icon: 'flash-outline' },
  { id: 'confident', title: 'Confident', desc: 'Assertive, eliminates hesitant words like "maybe" and "just".', icon: 'shield-checkmark-outline' },
  { id: 'casual', title: 'Casual', desc: 'Friendly, conversational, relaxed, and approachable.', icon: 'cafe-outline' },
  { id: 'friendly', title: 'Warm & Friendly', desc: 'Empathetic, welcoming, and positive.', icon: 'heart-outline' },
  { id: 'academic', title: 'Academic', desc: 'Rigorous vocabulary, objective, and analytical.', icon: 'school-outline' },
];

export const ToneModal: React.FC<ToneModalProps> = ({
  visible,
  currentTone,
  onSelectTone,
  onClose,
}) => {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <View>
              <Text style={styles.title}>Tone & Audience</Text>
              <Text style={styles.subtitle}>Select the objective style for your writing</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.toneList} showsVerticalScrollIndicator={false}>
            {TONES.map((item) => {
              const isSelected = item.id === currentTone;
              return (
                <TouchableOpacity
                  key={item.id}
                  style={[styles.toneCard, isSelected && styles.selectedToneCard]}
                  onPress={() => {
                    onSelectTone(item.id);
                    onClose();
                  }}
                  activeOpacity={0.7}
                >
                  <View style={[styles.iconCircle, isSelected && styles.selectedIconCircle]}>
                    <Ionicons
                      name={item.icon}
                      size={20}
                      color={isSelected ? '#38BDF8' : '#94A3B8'}
                    />
                  </View>

                  <View style={styles.textContainer}>
                    <Text style={[styles.toneTitle, isSelected && styles.selectedToneTitle]}>
                      {item.title}
                    </Text>
                    <Text style={styles.toneDesc}>{item.desc}</Text>
                  </View>

                  {isSelected && (
                    <Ionicons name="checkmark-circle" size={22} color="#38BDF8" style={{ marginLeft: 8 }} />
                  )}
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.75)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: '#0F172A',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '80%',
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 36,
    borderWidth: 1,
    borderColor: '#1E293B',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '800',
    color: '#F8FAFC',
  },
  subtitle: {
    fontSize: 13,
    color: '#94A3B8',
    marginTop: 2,
  },
  closeBtn: {
    padding: 4,
  },
  toneList: {
    marginBottom: 8,
  },
  toneCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1E293B',
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#334155',
  },
  selectedToneCard: {
    borderColor: '#38BDF8',
    backgroundColor: '#0C2844',
  },
  iconCircle: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#334155',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  selectedIconCircle: {
    backgroundColor: '#0369A1',
  },
  textContainer: {
    flex: 1,
  },
  toneTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#E2E8F0',
    marginBottom: 2,
  },
  selectedToneTitle: {
    color: '#38BDF8',
  },
  toneDesc: {
    fontSize: 12,
    color: '#94A3B8',
    lineHeight: 16,
  },
});
