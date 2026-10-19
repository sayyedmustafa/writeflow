import React, { useState } from 'react';
import {
  StyleSheet,
  Text,
  View,
  Modal,
  TouchableOpacity,
  TextInput,
  Switch,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { UserSettings } from '../types';
import { analyzeWriting } from '../services/ai';

interface SettingsModalProps {
  visible: boolean;
  settings: UserSettings;
  onSaveSettings: (settings: UserSettings) => void;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  visible,
  settings,
  onSaveSettings,
  onClose,
}) => {
  const [apiKey, setApiKey] = useState(settings.apiKey);
  const [autoCheck, setAutoCheck] = useState(settings.autoCheck);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<string | null>(null);

  const handleTestKey = async () => {
    if (!apiKey.trim()) {
      Alert.alert('Empty Key', 'Please enter a Gemini API key first.');
      return;
    }
    setTesting(true);
    setTestResult(null);
    try {
      const res = await analyzeWriting('Test sentence for grammar check.', apiKey.trim(), 'professional');
      if (res && res.toneAnalysis) {
        setTestResult('success');
      } else {
        setTestResult('error');
      }
    } catch {
      setTestResult('error');
    } finally {
      setTesting(false);
    }
  };

  const handleSave = () => {
    onSaveSettings({
      ...settings,
      apiKey: apiKey.trim(),
      autoCheck,
    });
    onClose();
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.overlay}>
        <View style={styles.sheet}>
          <View style={styles.header}>
            <View>
              <Text style={styles.title}>Assistant Settings</Text>
              <Text style={styles.subtitle}>Configure your AI key and behavior</Text>
            </View>
            <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
              <Ionicons name="close" size={22} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          {/* API Key Section */}
          <View style={styles.section}>
            <View style={styles.labelRow}>
              <Text style={styles.sectionLabel}>Google Gemini API Key (₹0 Free Tier)</Text>
            </View>
            <Text style={styles.helperText}>
              Get your free key from Google AI Studio (aistudio.google.com). Without a key, the app uses built-in offline rules.
            </Text>

            <View style={styles.inputContainer}>
              <TextInput
                style={styles.input}
                value={apiKey}
                onChangeText={setApiKey}
                placeholder="AIzaSy..."
                placeholderTextColor="#64748B"
                secureTextEntry
                autoCapitalize="none"
              />
              {apiKey.length > 0 && (
                <TouchableOpacity onPress={() => setApiKey('')} style={{ padding: 6 }}>
                  <Ionicons name="close-circle" size={18} color="#64748B" />
                </TouchableOpacity>
              )}
            </View>

            <View style={styles.testRow}>
              <TouchableOpacity
                style={styles.testBtn}
                onPress={handleTestKey}
                disabled={testing || !apiKey}
              >
                {testing ? (
                  <ActivityIndicator size="small" color="#38BDF8" />
                ) : (
                  <>
                    <Ionicons name="flask-outline" size={15} color="#38BDF8" />
                    <Text style={styles.testBtnText}>Test Key Connection</Text>
                  </>
                )}
              </TouchableOpacity>

              {testResult === 'success' && (
                <Text style={styles.successText}>✓ Key Verified!</Text>
              )}
              {testResult === 'error' && (
                <Text style={styles.errorText}>✕ Invalid Key</Text>
              )}
            </View>
          </View>

          {/* Auto Check Setting */}
          <View style={styles.rowSetting}>
            <View style={{ flex: 1 }}>
              <Text style={styles.settingTitle}>Real-time Auto Check</Text>
              <Text style={styles.settingDesc}>Analyze writing automatically while you pause typing</Text>
            </View>
            <Switch
              value={autoCheck}
              onValueChange={setAutoCheck}
              trackColor={{ false: '#334155', true: '#0284C7' }}
              thumbColor={autoCheck ? '#38BDF8' : '#94A3B8'}
            />
          </View>

          {/* Save Button */}
          <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
            <Text style={styles.saveBtnText}>Save Settings</Text>
          </TouchableOpacity>
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
    marginBottom: 20,
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
  section: {
    marginBottom: 20,
  },
  labelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  sectionLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: '#E2E8F0',
  },
  helperText: {
    fontSize: 12,
    color: '#94A3B8',
    marginBottom: 10,
    lineHeight: 16,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1E293B',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#334155',
    paddingHorizontal: 12,
  },
  input: {
    flex: 1,
    height: 44,
    color: '#F8FAFC',
    fontSize: 14,
  },
  testRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 10,
    gap: 10,
  },
  testBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#0C2844',
    borderWidth: 1,
    borderColor: '#0284C7',
  },
  testBtnText: {
    color: '#38BDF8',
    fontSize: 12,
    fontWeight: '600',
  },
  successText: {
    color: '#10B981',
    fontSize: 12,
    fontWeight: '700',
  },
  errorText: {
    color: '#EF4444',
    fontSize: 12,
    fontWeight: '700',
  },
  rowSetting: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: '#1E293B',
    marginBottom: 24,
  },
  settingTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#E2E8F0',
  },
  settingDesc: {
    fontSize: 12,
    color: '#94A3B8',
    marginTop: 2,
  },
  saveBtn: {
    backgroundColor: '#0284C7',
    borderRadius: 12,
    paddingVertical: 13,
    alignItems: 'center',
  },
  saveBtnText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontWeight: '700',
  },
});
