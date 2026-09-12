import React, { useEffect, useRef, useState, type PropsWithChildren } from 'react';
import {
  Modal,
  PanResponder,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import Animated, {
  runOnJS,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import { colors, modalMotion, radius, spacing } from '@/theme';
import { AppBackdrop } from './app-backdrop';
import { useKeyboardViewport } from './use-keyboard-viewport';

export type AppBottomSheetProps = PropsWithChildren<{
  presented: boolean;
  onDismiss: () => void;
  showDragIndicator?: boolean;
  testID?: string;
}>;

export function AppBottomSheet({
  presented,
  onDismiss,
  showDragIndicator = true,
  children,
  testID,
}: AppBottomSheetProps) {
  const [isRendered, setIsRendered] = useState(presented);
  const isClosingRef = useRef(false);

  const backdropOpacity = useSharedValue(0);
  const sheetTranslateY = useSharedValue<number>(modalMotion.sheetTranslateY);
  const sheetOpacity = useSharedValue(0);
  const dragTranslateY = useSharedValue(0);

  const {
    availableHeight,
    keyboardHeight,
    isKeyboardVisible,
    insets,
  } = useKeyboardViewport();

  function triggerOpen() {
    isClosingRef.current = false;
    setIsRendered(true);
    dragTranslateY.value = 0;

    backdropOpacity.value = withTiming(1, {
      duration: modalMotion.backdropOpenDuration,
    });

    sheetTranslateY.value = modalMotion.sheetTranslateY;
    sheetTranslateY.value = withSpring(0, {
      damping: modalMotion.springDamping,
      stiffness: modalMotion.springStiffness,
    });
    sheetOpacity.value = withTiming(1, { duration: 180 });
  }

  function triggerClose() {
    if (isClosingRef.current) return;
    isClosingRef.current = true;

    backdropOpacity.value = withTiming(0, {
      duration: modalMotion.backdropCloseDuration,
    });
    sheetTranslateY.value = withTiming(modalMotion.sheetTranslateY, {
      duration: 160,
    });
    sheetOpacity.value = withTiming(0, { duration: 160 }, (finished) => {
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

  // Swipe-down pan gesture for natural drag-to-dismiss
  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: (_, gestureState) => gestureState.dy > 5,
      onPanResponderMove: (_, gestureState) => {
        if (gestureState.dy > 0) {
          dragTranslateY.value = gestureState.dy;
        }
      },
      onPanResponderRelease: (_, gestureState) => {
        if (gestureState.dy > 70 || gestureState.vy > 0.5) {
          triggerClose();
        } else {
          dragTranslateY.value = withSpring(0, {
            damping: modalMotion.springDamping,
            stiffness: modalMotion.springStiffness,
          });
        }
      },
    }),
  ).current;

  const animatedSheetStyle = useAnimatedStyle(() => ({
    opacity: sheetOpacity.value,
    transform: [
      { translateY: sheetTranslateY.value + dragTranslateY.value },
    ],
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
            styles.sheetContainer,
            {
              maxHeight: availableHeight,
              marginBottom: isKeyboardVisible ? keyboardHeight : 0,
              paddingBottom: isKeyboardVisible
                ? spacing.xs
                : Math.max(insets.bottom, 16),
            },
            animatedSheetStyle,
          ]}
        >
          {showDragIndicator ? (
            <View {...panResponder.panHandlers} style={styles.dragIndicatorWrapper}>
              <View style={styles.dragIndicator} />
            </View>
          ) : null}

          <ScrollView
            keyboardDismissMode="interactive"
            keyboardShouldPersistTaps="handled"
            nestedScrollEnabled
            contentContainerStyle={styles.scrollContent}
          >
            {children}
          </ScrollView>
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalRoot: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  sheetContainer: {
    backgroundColor: colors.surfaceElevated,
    borderTopLeftRadius: radius.sheet,
    borderTopRightRadius: radius.sheet,
    width: '100%',
    overflow: 'hidden',
  },
  dragIndicatorWrapper: {
    alignItems: 'center',
    paddingVertical: spacing.sm,
    width: '100%',
  },
  dragIndicator: {
    width: 36,
    height: 4,
    borderRadius: radius.pill,
    backgroundColor: colors.divider,
  },
  scrollContent: {
    paddingHorizontal: spacing.screenH,
    paddingBottom: spacing.xxl + 24,
  },
});
