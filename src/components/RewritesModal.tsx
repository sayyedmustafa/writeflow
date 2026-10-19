import React from 'react';
import { StyleSheet, Text, View, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { RewriteOption } from '../types';

interface RewritesModalProps {
  visible: boolean;
  rewrites: RewriteOption[];
  onApplyRewrite: (text: string) => void;
  onClose: () => void;
}

export const RewritesModal: React.FC<RewritesModalProps> = ({
  visible,
  rewrites,
  onApplyRewrite,
  onClose,
}) => {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <View>
              <Text style={styles.title}>AI Rewrites</Text>
              <Text style={styles.subtitle}>Full message rewrites tailored to your audience</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          {rewrites.length === 0 ? (
            <View style={styles.emptyContainer}>
              <Ionicons name="color-wand-outline" size={40} color="#64748B" />
              <Text style={styles.emptyTitle}>No Rewrites Yet</Text>
              <Text style={styles.emptyDesc}>
                Type some text in the editor, and the assistant will generate smart rewrites here.
              </Text>
            </View>
          ) : (
            <ScrollView style={styles.list} showsVerticalScrollIndicator={false}>
              {rewrites.map((item, idx) => (
                <View key={idx} style={styles.card}>
                  <View style={styles.cardTop}>
                    <View style={styles.badge}>
                      <Ionicons name="sparkles" size={13} color="#C084FC" />
                      <Text style={styles.badgeText}>{item.tagline || item.preset}</Text>
                    </View>
                  </View>

                  <Text style={styles.rewriteText}>{item.text}</Text>

                  <TouchableOpacity
                    style={styles.replaceButton}
                    onPress={() => {
                      onApplyRewrite(item.text);
                      onClose();
                    }}
                    activeOpacity={0.8}
                  >
                    <Ionicons name="swap-horizontal" size={15} color="#FFFFFF" />
                    <Text style={styles.replaceButtonText}>Use this rewrite</Text>
                  </TouchableOpacity>
                </View>
              ))}
            </ScrollView>
          )}
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
  list: {
    marginBottom: 8,
  },
  card: {
    backgroundColor: '#1E293B',
    borderRadius: 14,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#334155',
  },
  cardTop: {
    flexDirection: 'row',
    marginBottom: 10,
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#3B0764',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  badgeText: {
    color: '#D8B4FE',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'capitalize',
  },
  rewriteText: {
    color: '#F1F5F9',
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 14,
  },
  replaceButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#8B5CF6',
    borderRadius: 10,
    paddingVertical: 9,
  },
  replaceButtonText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontWeight: '700',
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 40,
    gap: 8,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#E2E8F0',
  },
  emptyDesc: {
    fontSize: 13,
    color: '#94A3B8',
    textAlign: 'center',
    maxWidth: 260,
  },
});
