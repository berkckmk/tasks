import React, { useEffect, useRef, useState, type PropsWithChildren } from 'react';
import { Modal, StyleSheet, View } from 'react-native';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { colors, modalMotion, radius, spacing } from '@/theme';
import { AppBackdrop } from './app-backdrop';
import { useKeyboardViewport } from './use-keyboard-viewport';

export type AppDialogProps = PropsWithChildren<{
  presented: boolean;
  onDismiss: () => void;
  testID?: string;
}>;

export function AppDialog({ presented, onDismiss, children, testID }: AppDialogProps) {
  const [isRendered, setIsRendered] = useState(presented);
  const isClosingRef = useRef(false);

  const backdropOpacity = useSharedValue(0);
  const scale = useSharedValue<number>(modalMotion.dialogScale);
  const translateY = useSharedValue<number>(modalMotion.dialogTranslateY);
  const opacity = useSharedValue(0);

  const { keyboardHeight, isKeyboardVisible } = useKeyboardViewport();

  function triggerOpen() {
    isClosingRef.current = false;
    setIsRendered(true);

    backdropOpacity.value = withTiming(1, {
      duration: modalMotion.backdropOpenDuration,
    });

    scale.value = withTiming(1, {
      duration: modalMotion.dialogOpenDuration,
    });
    translateY.value = withTiming(0, {
      duration: modalMotion.dialogOpenDuration,
    });
    opacity.value = withTiming(1, {
      duration: modalMotion.dialogOpenDuration,
    });
  }

  function triggerClose() {
    if (isClosingRef.current) return;
    isClosingRef.current = true;

    backdropOpacity.value = withTiming(0, {
      duration: modalMotion.backdropCloseDuration,
    });
    scale.value = withTiming(modalMotion.dialogScale, {
      duration: modalMotion.dialogCloseDuration,
    });
    translateY.value = withTiming(modalMotion.dialogTranslateY, {
      duration: modalMotion.dialogCloseDuration,
    });
    opacity.value = withTiming(0, { duration: modalMotion.dialogCloseDuration }, (finished) => {
      if (finished) {
        runOnJS(setIsRendered)(false);
        runOnJS(onDismiss)();
      }
    });
  }

  useEffect(() => {
    if (presented && !isRendered) {
      triggerOpen();
    } else if (!presented && isRendered) {
      triggerClose();
    }
  }, [presented]);

  const animatedDialogStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ scale: scale.value }, { translateY: translateY.value }],
  }));

  if (!isRendered) {
    return null;
  }

  return (
    <Modal
      visible={isRendered}
      transparent
      animationType="none"
      onRequestClose={triggerClose}
      statusBarTranslucent
      testID={testID}
    >
      <View style={styles.modalRoot}>
        <AppBackdrop opacity={backdropOpacity} onPress={triggerClose} />

        <Animated.View
          style={[
            styles.dialogContainer,
            {
              marginBottom: isKeyboardVisible ? keyboardHeight / 2 : 0,
            },
            animatedDialogStyle,
          ]}
        >
          {children}
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalRoot: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
  },
  dialogContainer: {
    backgroundColor: colors.surfaceElevated,
    borderRadius: radius.card,
    width: '100%',
    maxWidth: 400,
    overflow: 'hidden',
    padding: spacing.lg,
    borderWidth: 1,
    borderColor: colors.border,
  },
});
