import { useEffect, useState } from 'react';
import { Keyboard, Platform, useWindowDimensions, type KeyboardEvent } from 'react-native';
import { useSharedValue, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { spacing } from '@/theme';

export function useKeyboardViewport() {
  const insets = useSafeAreaInsets();
  const { height: windowHeight } = useWindowDimensions();
  const [keyboardHeightState, setKeyboardHeightState] = useState(0);
  const animatedKeyboardHeight = useSharedValue(0);

  useEffect(() => {
    const showEvent = Platform.OS === 'ios' ? 'keyboardWillShow' : 'keyboardDidShow';
    const hideEvent = Platform.OS === 'ios' ? 'keyboardWillHide' : 'keyboardDidHide';

    const onShow = (e: KeyboardEvent) => {
      const height = e.endCoordinates.height;
      setKeyboardHeightState(height);
      const duration = e.duration && e.duration > 0 ? e.duration : 180;
      animatedKeyboardHeight.value = withTiming(height, { duration });
    };

    const onHide = (e: KeyboardEvent) => {
      setKeyboardHeightState(0);
      const duration = e?.duration && e.duration > 0 ? e.duration : 160;
      animatedKeyboardHeight.value = withTiming(0, { duration });
    };

    const showSub = Keyboard.addListener(showEvent, onShow);
    const hideSub = Keyboard.addListener(hideEvent, onHide);

    return () => {
      showSub.remove();
      hideSub.remove();
    };
  }, [animatedKeyboardHeight]);

  const isKeyboardVisible = keyboardHeightState > 0;
  // Maximum safe height when keyboard is closed
  const maxSafeHeight = Math.max(0, windowHeight - insets.top - spacing.sm);
  // Max safe height when keyboard is active (keeps sheet strictly above keyboard)
  const availableHeight = isKeyboardVisible
    ? Math.max(160, windowHeight - insets.top - keyboardHeightState - spacing.xs)
    : maxSafeHeight;

  return {
    windowHeight,
    insets,
    keyboardHeight: keyboardHeightState,
    animatedKeyboardHeight,
    isKeyboardVisible,
    maxSafeHeight,
    availableHeight,
  };
}
