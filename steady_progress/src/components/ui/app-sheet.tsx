import type { PropsWithChildren } from 'react';
import { AppBottomSheet, type AppBottomSheetProps } from '@/components/modal';

export type AppSheetProps = AppBottomSheetProps;

/**
 * Standardized application sheet component.
 * Features controlled spring entrance motion, subtle backdrop fade,
 * safe-area handling, and responsive keyboard-aware viewport resizing.
 */
export function AppSheet({
  presented,
  onDismiss,
  showDragIndicator = true,
  children,
  testID,
}: AppSheetProps) {
  return (
    <AppBottomSheet
      presented={presented}
      onDismiss={onDismiss}
      showDragIndicator={showDragIndicator}
      testID={testID}
    >
      {children}
    </AppBottomSheet>
  );
}
