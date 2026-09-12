import { View } from 'react-native';
import { spacing } from '@/theme';
import { AppText } from './app-text';

/** Empty list copy only. The surrounding ListScreenShell already owns '+'. */
export function EmptyState({ title, message }: { title: string; message: string }) {
  return (
    <View style={{ alignItems: 'center', paddingVertical: spacing.xxl, gap: spacing.sm }}>
      <AppText variant="h5" style={{ textAlign: 'center' }}>{title}</AppText>
      <AppText tone="muted" style={{ textAlign: 'center' }}>{message}</AppText>
    </View>
  );
}
