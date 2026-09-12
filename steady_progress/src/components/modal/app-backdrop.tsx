import React from 'react';
import { Pressable, StyleSheet } from 'react-native';
import Animated, { type SharedValue, useAnimatedStyle } from 'react-native-reanimated';
import { modalMotion } from '@/theme';

type AppBackdropProps = {
  opacity: SharedValue<number>;
  onPress: () => void;
  testID?: string;
};

export function AppBackdrop({ opacity, onPress, testID }: AppBackdropProps) {
  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        StyleSheet.absoluteFill,
        { backgroundColor: modalMotion.backdropColor },
        animatedStyle,
      ]}
      pointerEvents="auto"
      testID={testID}
    >
      <Pressable
        style={StyleSheet.absoluteFill}
        onPress={onPress}
        accessibilityRole="button"
        accessibilityLabel="Modalı kapat"
        accessibilityHint="Geri dönmek veya kapatmak için dokunun"
      />
    </Animated.View>
  );
}
